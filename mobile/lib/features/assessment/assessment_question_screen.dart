import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_colors.dart';
import '../../services/demo_store.dart';
import '../../services/auth_service.dart';
import 'assessment_models.dart';
import 'assessment_repository.dart';
import 'assessment_widgets.dart';
import 'assessment_video.dart';
import 'assessment_result_screen.dart';

class AssessmentQuestionScreen extends StatefulWidget {
  const AssessmentQuestionScreen({
    super.key,
    required this.childId,
    required this.attempt,
    required this.repository,
  });
  final String childId;
  final AssessmentAttempt attempt;
  final AssessmentRepository repository;
  @override
  State<AssessmentQuestionScreen> createState() =>
      _AssessmentQuestionScreenState();
}

class _AssessmentQuestionScreenState extends State<AssessmentQuestionScreen> {
  late AssessmentAttempt attempt = widget.attempt;
  late Map<String, String> answers = attempt.answers;
  late String? regression = attempt.regression, concern = attempt.concern;
  int index = 0, epoch = 0;
  bool dirty = false,
      saving = false,
      submitting = false,
      canLeave = false,
      localSaved = false,
      restoring = true;
  String? error;
  Timer? timer;
  Future<void>? activeSave;
  final scroll = ScrollController();
  String get cacheKey =>
      'assessment_pending/${AuthService.instance.user?['id'] ?? DemoStore.instance.parent['id']}/${widget.childId}/${attempt.id}';
  @override
  void initState() {
    super.initState();
    index = attempt.questions.indexWhere(
      (q) => !answers.containsKey(q['code']),
    );
    if (index < 0) index = attempt.questions.length;
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(cacheKey);
      final legacyKey = cacheKey.replaceFirst(
        'assessment_pending/',
        'development_pending/',
      );
      if (raw == null) {
        raw = prefs.getString(legacyKey);
        if (raw != null && await prefs.setString(cacheKey, raw)) {
          await prefs.remove(legacyKey);
        }
      }
      if (raw == null || !mounted) return;
      final data = assessmentMap(jsonDecode(raw));
      if (data['version'] != attempt.version) {
        setState(
          () => error = 'Có đáp án chưa đồng bộ nhưng bài trên máy chủ đã thay đổi. Tải lại bài để kiểm tra.',
        );
        return;
      }
      setState(() {
        answers = Map<String, String>.from(data['answers']);
        regression = data['regression'] as String?;
        concern = data['caregiver_concern'] as String?;
        dirty = true;
        localSaved = true;
        epoch++;
      });
      await _save();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Chưa đọc được đáp án lưu trên máy. Hãy tải lại bài.',
        );
      }
    } finally {
      if (mounted) setState(() => restoring = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _cache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ok = await prefs.setString(
        cacheKey,
        jsonEncode({
          'version': attempt.version,
          'answers': answers,
          'regression': regression,
          'caregiver_concern': concern,
        }),
      );
      if (mounted) setState(() => localSaved = ok);
    } catch (_) {
      if (mounted) setState(() => localSaved = false);
    }
  }

  void _changed(VoidCallback change) {
    setState(() {
      change();
      epoch++;
      dirty = true;
      error = null;
      localSaved = false;
    });
    _cache();
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 450), _save);
  }

  Future<void> _save() {
    if (activeSave != null) return activeSave!;
    final operation = _flush();
    activeSave = operation;
    return operation.whenComplete(() => activeSave = null);
  }

  Future<void> _flush() async {
    if (!dirty) return;
    if (mounted) setState(() => saving = true);
    try {
      while (dirty) {
        final revision = epoch;
        final saved = await widget.repository.save(
          widget.childId,
          attempt,
          Map.of(answers),
          regression,
          concern,
        );
        attempt = saved;
        if (revision == epoch) {
          dirty = false;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(cacheKey);
        } else {
          await _cache();
        }
        if (mounted) setState(() => error = null);
      }
    } catch (e) {
      await _cache();
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _exit() async {
    timer?.cancel();
    await _save();
    if (!mounted) return;
    if (dirty) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bài chưa đồng bộ'),
          content: Text(
            localSaved
                ? 'Đáp án đã lưu trên máy này. Bạn có thể tiếp tục và đồng bộ khi mở lại bài.'
                : 'Chưa lưu được đáp án. Hãy thử lại trước khi thoát.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ở lại'),
            ),
            if (localSaved)
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Lưu trên máy và thoát'),
              ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    setState(() => canLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  void _go(int next) {
    setState(() => index = next);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> _navigator() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Các câu trong bài',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            for (var i = 0; i < attempt.questions.length; i++)
              ListTile(
                selected: i == index,
                selectedTileColor: AppColors.primarySoft,
                leading: AssessmentIconBadge(
                  assessmentDomainIcon(
                    attempt.questions[i]['domain'] as String?,
                  ),
                  color: assessmentDomainColor(
                    attempt.questions[i]['domain'] as String?,
                  ),
                ),
                title: Text(
                  'Câu ${i + 1} · ${assessmentDomains[attempt.questions[i]['domain']]}',
                ),
                subtitle: Text(
                  answers.containsKey(attempt.questions[i]['code'])
                      ? 'Đã trả lời'
                      : 'Chưa trả lời',
                ),
                trailing: Icon(
                  answers.containsKey(attempt.questions[i]['code'])
                      ? Icons.check_circle_outline
                      : Icons.radio_button_unchecked,
                  color: AppColors.primary,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _go(i);
                },
              ),
            ListTile(
              selected: index >= attempt.questions.length,
              selectedTileColor: AppColors.primarySoft,
              leading: const AssessmentIconBadge(
                Icons.chat_bubble_outline_rounded,
              ),
              title: const Text('Thông tin bổ sung'),
              onTap: () {
                Navigator.pop(ctx);
                _go(attempt.questions.length);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _complete() async {
    setState(() => submitting = true);
    timer?.cancel();
    await _save();
    if (!mounted) return;
    if (dirty) {
      setState(() => submitting = false);
      return;
    }
    try {
      final completed = await widget.repository.complete(
        widget.childId,
        attempt,
      );
      if (!mounted) return;
      setState(() => canLeave = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => AssessmentResultScreen(
                childId: widget.childId,
                attempt: completed,
                isDemo: widget.repository.isDemo,
              ),
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          submitting = false;
        });
      }
    }
  }

  Future<void> _reload() async {
    timer?.cancel();
    if (saving) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tải lại bài?'),
        content: const Text(
          'Đáp án chưa đồng bộ trên máy này sẽ được thay bằng bản mới nhất từ máy chủ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tải lại'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      final fresh = await widget.repository.load(widget.childId, attempt.id);
      if (!mounted) return;
      if (!fresh.editable) {
        setState(() => canLeave = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => fresh.completed
                    ? AssessmentResultScreen(
                        childId: widget.childId,
                        attempt: fresh,
                        isDemo: widget.repository.isDemo,
                      )
                    : AssessmentAnswersScreen(
                        attempt: fresh,
                        isDemo: widget.repository.isDemo,
                      ),
              ),
            );
          }
        });
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cacheKey);
      if (mounted) {
        setState(() {
          attempt = fresh;
          answers = fresh.answers;
          regression = fresh.regression;
          concern = fresh.concern;
          dirty = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = attempt.questions, follow = index >= questions.length;
    final q = follow ? null : questions[index],
        payload = q == null ? null : assessmentMap(q['payload']);
    final missing = questions
        .where((q) => !answers.containsKey(q['code']))
        .toList();
    return ValueListenableBuilder<bool>(
      valueListenable: AssessmentVideoPlayback.fullscreen,
      builder: (context, videoFullscreen, _) => PopScope(
        canPop: canLeave && !videoFullscreen,
        onPopInvokedWithResult: (popped, _) {
          if (!popped && !submitting && !videoFullscreen) _exit();
        },
        child: AssessmentScaffold(
          backgroundColor: AppColors.background,
          appBar: videoFullscreen
              ? null
              : assessmentAppBar(
                  'Mốc ${attempt.age} tháng',
                  back: submitting ? () {} : _exit,
                ),
          body: restoring
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  top: false,
                  bottom: !videoFullscreen,
                  child: Column(
                    children: [
                      Expanded(
                        child: AssessmentVideoViewport(
                          child: ListView(
                            controller: scroll,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              if (widget.repository.isDemo)
                                const Padding(
                                  padding: EdgeInsets.zero,
                                  child: AssessmentDemoNote(),
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          follow
                                              ? 'Kiểm tra bài'
                                              : 'Câu ${index + 1}/${questions.length}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: submitting
                                              ? null
                                              : _navigator,
                                          child: const Text('Xem các câu'),
                                        ),
                                      ],
                                    ),
                                    AssessmentProgress(
                                      value: answers.length / questions.length,
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Đã trả lời ${answers.length}/${questions.length} · ${saving
                                            ? 'Đang lưu…'
                                            : dirty
                                            ? localSaved
                                                  ? 'Đã lưu trên máy · chưa đồng bộ'
                                                  : 'Chưa lưu'
                                            : 'Đã lưu'}',
                                        style: assessmentMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (error != null) ...[
                                AssessmentError(
                                  message: error!,
                                  retry: () {
                                    _save();
                                  },
                                  extra: TextButton(
                                    onPressed: saving ? null : _reload,
                                    child: const Text('Tải lại bài'),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (!follow)
                                AssessmentReveal(
                                  key: ValueKey('question-$index'),
                                  child: _question(q!, payload!),
                                )
                              else
                                ..._followUp(missing),
                            ],
                          ),
                        ),
                      ),
                      if (!videoFullscreen) _footer(follow, missing.isEmpty),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _question(
    Map<String, dynamic> q,
    Map<String, dynamic> p,
  ) => AssessmentCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AssessmentDomainLabel(q['domain'] as String?),
        const SizedBox(height: 10),
        Text(
          p['question_vi'] ?? p['prompt'] ?? '',
          style: const TextStyle(
            fontSize: 21,
            height: 1.45,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        AssessmentObservation(
          text: p['instruction_vi'] ?? p['observation_guide'] ?? '',
        ),
        if ((p['safety_note'] as String? ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(p['safety_note'] as String, style: assessmentMuted),
        ],
        ...assessmentMedia(p),
        const SizedBox(height: 20),
        ...assessmentAnswers.entries.map(
          (v) => AssessmentChoice(
            label: v.value,
            selected: answers[q['code']] == v.key,
            onTap: submitting
                ? null
                : () => _changed(() => answers[q['code'] as String] = v.key),
          ),
        ),
        const Text(
          'Chưa quan sát: chưa đủ thông tin để biết bé đã làm được hay chưa.',
          style: assessmentMuted,
        ),
      ],
    ),
  );
  List<Widget> _followUp(List<Map<String, dynamic>> missing) => [
    AssessmentCard(
      title: 'Thông tin bổ sung',
      icon: Icons.chat_bubble_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bé có mất kỹ năng từng làm được không?',
            style: TextStyle(
              fontSize: 17,
              height: 1.45,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Trước đây bé làm được, nhưng hiện không còn làm được. Có thể là kỹ năng ngoài bài này.',
            style: assessmentMuted,
          ),
          const SizedBox(height: 12),
          ...{'no': 'Không', 'yes': 'Có', 'unsure': 'Chưa chắc'}.entries.map(
            (v) => AssessmentChoice(
              label: v.value,
              selected: regression == v.key,
              onTap: submitting
                  ? null
                  : () => _changed(() => regression = v.key),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Bạn có lo ngại về sự phát triển của bé không?',
            style: TextStyle(
              fontSize: 17,
              height: 1.45,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ví dụ: vận động, giao tiếp, học hỏi hoặc tương tác với mọi người.',
            style: assessmentMuted,
          ),
          const SizedBox(height: 12),
          ...{'no': 'Không', 'yes': 'Có'}.entries.map(
            (v) => AssessmentChoice(
              label: v.value,
              selected: concern == v.key,
              onTap: submitting ? null : () => _changed(() => concern = v.key),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    AssessmentCard(
      title: 'Kiểm tra trước khi hoàn thành',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${answers.length}/${attempt.questions.length} câu đã có đáp án',
            style: assessmentBody,
          ),
          if (missing.isNotEmpty)
            TextButton(
              onPressed: () => _go(
                attempt.questions.indexWhere(
                  (q) => q['code'] == missing.first['code'],
                ),
              ),
              child: Text('Còn ${missing.length} câu chưa trả lời'),
            ),
          if (regression == null || concern == null)
            const Text(
              'Chọn đủ hai câu hỏi bổ sung phía trên.',
              style: assessmentMuted,
            ),
          const SizedBox(height: 8),
          const Text(
            'Sau khi hoàn thành, bài được lưu trong Lịch sử và chỉ có thể xem lại.',
            style: assessmentMuted,
          ),
        ],
      ),
    ),
  ];
  Widget _footer(bool follow, bool allAnswered) {
    final previous = OutlinedButton(
      onPressed: index == 0 || submitting ? null : () => _go(index - 1),
      child: const Text('Câu trước'),
    );
    final next = FilledButton(
      onPressed: submitting
          ? null
          : follow
          ? allAnswered && regression != null && concern != null
                ? _complete
                : null
          : () => _go(index + 1),
      child: Text(
        submitting
            ? 'Đang xử lý…'
            : follow
            ? 'Xem kết quả'
            : 'Câu tiếp theo',
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: MediaQuery.textScalerOf(context).scale(14) > 22
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [next, const SizedBox(height: 8), previous],
            )
          : Row(
              children: [
                Expanded(child: previous),
                const SizedBox(width: 12),
                Expanded(child: next),
              ],
            ),
    );
  }
}
