import 'package:flutter/material.dart';

import 'growth_visuals.dart';

class GrowthChartExplanationDialog extends StatelessWidget {
  const GrowthChartExplanationDialog({
    required this.title,
    required this.content,
    required this.actions,
    super.key,
  });
  final Widget title, content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final body = content is SingleChildScrollView
        ? (content as SingleChildScrollView).child
        : content;
    final paragraphs = body is Text ? (body.data ?? '').split('\n\n') : null;
    const icons = [
      Icons.show_chart_rounded,
      Icons.layers_outlined,
      Icons.tune_rounded,
      Icons.favorite_border_rounded,
    ];
    return Dialog(
      backgroundColor: const Color(0xFFFFFEFA),
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const GrowthAsset('lightbulb', size: 30),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Cùng đọc biểu đồ',
                              style: TextStyle(
                                fontFamily: 'DancingScript',
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                color: growthGreen,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Đóng giải thích',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: growthMuted,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Transform.rotate(
                      angle: -.025,
                      child: CustomPaint(
                        painter: const GrowthNotePaperPainter(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: DefaultTextStyle(
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                              color: Color(0xFF20365D),
                            ),
                            child: title,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (paragraphs == null)
                      content
                    else
                      for (var i = 0; i < paragraphs.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: i.isEven
                                      ? const Color(0xFFE3F3E8)
                                      : const Color(0xFFE4EFF6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  icons[i % icons.length],
                                  size: 19,
                                  color: i.isEven
                                      ? growthGreen
                                      : const Color(0xFF316884),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  paragraphs[i],
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 14,
                                    height: 1.55,
                                    color: Color(0xFF20365D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: growthGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
