import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Reads both touch pointers even if a page drag won the first pointer's arena.
class GrowthChartGestures extends StatefulWidget {
  const GrowthChartGestures({
    super.key,
    required this.onStart,
    required this.onUpdate,
    required this.onTap,
    required this.child,
    this.panEnabled = true,
    this.onPinchingChanged,
    this.onReset,
  });
  final GestureScaleStartCallback onStart;
  final GestureScaleUpdateCallback onUpdate;
  final GestureTapUpCallback onTap;
  final Widget child;
  final bool panEnabled;
  final ValueChanged<bool>? onPinchingChanged;
  final VoidCallback? onReset;

  @override
  State<GrowthChartGestures> createState() => _GrowthChartGesturesState();
}

class _GrowthChartGesturesState extends State<GrowthChartGestures> {
  final _pointers = <int, Offset>{};
  bool _hadPinch = false;
  bool _listening = false;
  double _initialDistance = 1;
  Duration? _lastTapDown;
  Duration _currentTapDown = Duration.zero;
  Offset? _lastTapPosition;

  Offset _local(Offset global) =>
      (context.findRenderObject()! as RenderBox).globalToLocal(global);
  List<Offset> get _pair => _pointers.values.take(2).map(_local).toList();
  Offset get _focal => (_pair[0] + _pair[1]) / 2;

  void _down(PointerDownEvent event) {
    if (_pointers.containsKey(event.pointer)) return;
    if (_pointers.isEmpty) {
      _hadPinch = false;
      _currentTapDown = event.timeStamp;
      if (!_listening) {
        _listening = true;
        GestureBinding.instance.pointerRouter.addGlobalRoute(_globalPointer);
      }
    }
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      _hadPinch = true;
      _lastTapDown = null;
      // A PageView drag ignores new child hits. End that drag before pinching.
      context.visitAncestorElements((element) {
        if (element is StatefulElement && element.state is ScrollableState) {
          final position = (element.state as ScrollableState).position;
          if (position.hasPixels) {
            final horizontal =
                axisDirectionToAxis(position.axisDirection) == Axis.horizontal;
            final target = horizontal && position.viewportDimension > 0
                ? (position.pixels / position.viewportDimension).round() *
                      position.viewportDimension
                : position.pixels;
            position.jumpTo(
              target.clamp(position.minScrollExtent, position.maxScrollExtent),
            );
          }
        }
        return true;
      });
      _initialDistance = (_pair[0] - _pair[1]).distance.clamp(
        1.0,
        double.infinity,
      );
      widget.onPinchingChanged?.call(true);
      widget.onStart(
        ScaleStartDetails(localFocalPoint: _focal, pointerCount: 2),
      );
    }
  }

  void _move(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    if (_pointers.length >= 2) {
      widget.onUpdate(
        ScaleUpdateDetails(
          localFocalPoint: _focal,
          pointerCount: 2,
          scale: (_pair[0] - _pair[1]).distance / _initialDistance,
        ),
      );
    }
  }

  void _up(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.isEmpty) {
      if (_hadPinch) widget.onPinchingChanged?.call(false);
      _stopListening();
    }
  }

  void _globalPointer(PointerEvent event) {
    if (!mounted) return;
    if (event is PointerDownEvent) {
      final box = context.findRenderObject() as RenderBox;
      if ((Offset.zero & box.size).contains(_local(event.position))) {
        _down(event);
      }
    } else if (event is PointerMoveEvent) {
      _move(event);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_pointers.containsKey(event.pointer)) _up(event);
    }
  }

  void _stopListening() {
    if (_listening) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_globalPointer);
      _listening = false;
    }
  }

  @override
  void dispose() {
    _stopListening();
    if (_hadPinch && _pointers.isNotEmpty) {
      final callback = widget.onPinchingChanged;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => callback?.call(false),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _down,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        if (_hadPinch) return;
        final doubleTap =
            _lastTapDown != null &&
            _currentTapDown - _lastTapDown! <= kDoubleTapTimeout &&
            (details.localPosition - _lastTapPosition!).distance < 24;
        if (doubleTap) {
          _lastTapDown = null;
          widget.onReset?.call();
        } else {
          _lastTapDown = _currentTapDown;
          _lastTapPosition = details.localPosition;
          widget.onTap(details);
        }
      },
      onHorizontalDragStart: widget.panEnabled
          ? (details) {
              if (!_hadPinch) {
                widget.onStart(
                  ScaleStartDetails(
                    localFocalPoint: details.localPosition,
                    pointerCount: 1,
                  ),
                );
              }
            }
          : null,
      onHorizontalDragUpdate: widget.panEnabled
          ? (details) {
              if (!_hadPinch) {
                widget.onUpdate(
                  ScaleUpdateDetails(
                    localFocalPoint: details.localPosition,
                    pointerCount: 1,
                  ),
                );
              }
            }
          : null,
      child: widget.child,
    ),
  );
}
