import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Owns only home_backgrounds_v1. Never removes a picker/library source file.
class BackgroundFiles {
  const BackgroundFiles({this.rootPath});
  final String? rootPath;
  static const storedPrefix = '@home/';

  Future<Directory> root() async => Directory(
    p.normalize(
      p.absolute(
        rootPath ??
            p.join(
              (await getApplicationDocumentsDirectory()).path,
              'home_backgrounds_v1',
            ),
      ),
    ),
  );

  String _id() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  String _scope(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  Future<String> stagePath({String extension = 'jpg'}) async {
    final directory = Directory(p.join((await root()).path, 'pending'));
    await directory.create(recursive: true);
    return p.join(directory.path, '${_id()}.$extension');
  }

  Future<String> keepInput(String pickedPath) async {
    final destination = await stagePath(extension: 'input');
    try {
      await File(pickedPath).copy(destination);
      return destination;
    } catch (_) {
      await removePending(destination);
      rethrow;
    }
  }

  Future<bool> isPending(String path) async => p.isWithin(
    p.join((await root()).path, 'pending'),
    p.normalize(p.absolute(path)),
  );

  Future<void> removePending(String? path) async {
    if (path == null) return;
    try {
      if (await isPending(path)) await _remove(path);
    } catch (_) {
      /* Cleanup must not turn a successful Apply into a failure. */
    }
  }

  Future<String> publish(
    String stagedPath,
    String accountId,
    String childId,
  ) async {
    if (!await isPending(stagedPath)) {
      throw ArgumentError('Unmanaged draft file');
    }
    final directory = Directory(
      p.join(
        (await root()).path,
        'accounts',
        _scope(accountId),
        _scope(childId),
      ),
    );
    await directory.create(recursive: true);
    final path = p.join(directory.path, '${_id()}.jpg');
    final partial = '$path.part';
    try {
      await File(stagedPath).copy(partial);
      final handle = await File(partial).open(mode: FileMode.append);
      try {
        await handle.flush();
      } finally {
        await handle.close();
      }
      await File(partial).rename(path);
      return path;
    } catch (_) {
      await _remove(partial);
      rethrow;
    }
  }

  Future<String> toStoredPath(String path) async {
    final base = (await root()).path;
    if (!p.isWithin(p.join(base, 'accounts'), p.normalize(p.absolute(path)))) {
      throw ArgumentError('Unmanaged final file');
    }
    return '$storedPrefix${p.relative(path, from: base).split(p.separator).join('/')}';
  }

  Future<String> resolveStoredPath(
    String path, {
    String? accountId,
    String? childId,
  }) async {
    final base = (await root()).path;
    if (!path.startsWith(storedPrefix)) {
      // Preserve legacy sources; managed absolute files still require ownership.
      final absolute = p.normalize(p.absolute(path));
      if (accountId != null &&
          childId != null &&
          p.isWithin(p.join(base, 'accounts'), absolute) &&
          !p.isWithin(
            p.join(base, 'accounts', _scope(accountId), _scope(childId)),
            absolute,
          )) {
        throw const FormatException('Background belongs to another profile');
      }
      return path;
    }
    final resolved = p.normalize(
      p.join(base, p.fromUri(path.substring(storedPrefix.length))),
    );
    if (!p.isWithin(p.join(base, 'accounts'), resolved)) {
      throw const FormatException('Invalid managed background path');
    }
    if (accountId != null &&
        childId != null &&
        !p.isWithin(
          p.join(base, 'accounts', _scope(accountId), _scope(childId)),
          resolved,
        )) {
      throw const FormatException('Background belongs to another profile');
    }
    return resolved;
  }

  Future<void> removeFinal(
    String? path,
    String accountId,
    String childId,
  ) async {
    if (path == null) return;
    final scope = p.join(
      (await root()).path,
      'accounts',
      _scope(accountId),
      _scope(childId),
    );
    if (p.isWithin(scope, p.normalize(p.absolute(path)))) await _remove(path);
  }

  Future<void> _remove(String path) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        await File(path).delete();
        return;
      } on FileSystemException {
        if (!await File(path).exists()) return;
        if (attempt < 4) {
          await Future<void>.delayed(
            Duration(milliseconds: 30 * (attempt + 1)),
          );
        }
      }
    }
    // A temporary OS lock may outlive the route; startup cleanup retries.
  }

  /// Run at startup, before a chooser can own any new pending files.
  Future<void> cleanup({
    required Set<String> referenced,
    Set<String> keepPending = const {},
    bool cleanFinal = true,
  }) async {
    final base = (await root()).path;
    final pending = Directory(p.join(base, 'pending'));
    if (await pending.exists()) {
      await for (final entry in pending.list(followLinks: false)) {
        if (entry is File && !keepPending.contains(entry.path)) {
          await _remove(entry.path);
        }
      }
    }
    final finalFiles = Directory(p.join(base, 'accounts'));
    if (cleanFinal && await finalFiles.exists()) {
      await for (final entry in finalFiles.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entry is File && !referenced.contains(entry.path)) {
          await _remove(entry.path);
        }
      }
    }
  }
}
