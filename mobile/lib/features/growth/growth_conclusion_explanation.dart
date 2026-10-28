import 'package:flutter/material.dart';

import 'growth_visuals.dart';
import 'growth_conclusion_evidence.dart';

class GrowthExplanationSection {
  const GrowthExplanationSection(this.title, this.body);
  final String title, body;
}

class GrowthConclusionExplanationScreen extends StatelessWidget {
  const GrowthConclusionExplanationScreen({
    this.easyRead = false,
    this.evidence = const GrowthConclusionEvidence(),
    this.sections,
    this.introText,
    this.sources,
    super.key,
  });
  final bool easyRead;
  final GrowthConclusionEvidence evidence;
  final List<GrowthExplanationSection>? sections;
  final String? introText;
  final Map<String, String>? sources;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(
          Icons.chevron_left_rounded,
          color: Color(0xFF172A4B),
          size: 30,
        ),
      ),
      title: const Text(
        'Vì sao có kết luận này?',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFF172A4B),
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Transform.rotate(
                    angle: easyRead ? 0 : -.055,
                    child: Text(
                      introText ?? 'Hệ thống so sánh số đo của bé với dữ liệu tăng trưởng chuẩn dành cho trẻ 0–5 tuổi của Tổ chức Y tế Thế giới (WHO).',
                      style: TextStyle(
                        fontFamily: easyRead ? 'Nunito' : 'DancingScript',
                        fontSize: 19,
                        height: 1.4,
                        color: const Color(0xFF24456E),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const GrowthAsset('explanation-child', size: 100),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'Căn cứ đánh giá',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172A4B),
              ),
            ),
            const SizedBox(height: 18),
            if (sections != null) ...[
              for (var i = 0; i < sections!.length; i++) ...[
                _basis(
                  const [
                    'overview-weight',
                    'overview-chart',
                    'overview-trend',
                    'who',
                  ][i % 4],
                  i.isEven ? const Color(0xFFF0F8FF) : const Color(0xFFEBF8E9),
                  sections![i].title,
                  sections![i].body,
                ),
                if (i < sections!.length - 1) const SizedBox(height: 24),
              ],
            ] else ...[
              _basis(
                'overview-height',
                const Color(0xFFF0F8FF),
                '1. D\u1eef li\u1ec7u s\u1eed d\u1ee5ng',
                evidence.inputs,
              ),
              const SizedBox(height: 24),
              _basis(
                'who',
                const Color(0xFFEBF8E9),
                '2. Chu\u1ea9n \u0111\u1ed1i chi\u1ebfu',
                evidence.reference,
              ),
              const SizedBox(height: 24),
              _basis(
                'overview-trend',
                const Color(0xFFF0F8FF),
                '3. K\u1ebft qu\u1ea3 t\u00ednh to\u00e1n',
                evidence.scores,
              ),
              const SizedBox(height: 24),
              _basis(
                'overview-chart',
                const Color(0xFFFFF0EA),
                '4. Ng\u01b0\u1ee1ng ph\u00e2n lo\u1ea1i',
                evidence.thresholds,
              ),
              const SizedBox(height: 24),
              _basis(
                'lightbulb',
                const Color(0xFFEBF8E9),
                '5. Gi\u1ea3i th\u00edch k\u1ebft lu\u1eadn',
                evidence.explanation,
              ),
            ],
            const SizedBox(height: 22),
            const Divider(color: Color(0xFFE6EBED), height: 1),
            const SizedBox(height: 14),
            const Text(
              'Nguồn tham khảo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172A4B),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                showDragHandle: true,
                backgroundColor: Colors.white,
                builder: (context) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'WHO Child Growth Standards',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF172A4B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (sources != null) ...[
                        for (final source in sources!.entries) ...[
                          Text(
                            source.key,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(source.value),
                          const SizedBox(height: 14),
                        ],
                      ] else ...[
                        const Text(
                          'Cân nặng theo tuổi',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SelectableText(
                          'https://www.who.int/tools/child-growth-standards/standards/weight-for-age',
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Cân nặng theo chiều dài/chiều cao',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SelectableText(
                          'https://www.who.int/tools/child-growth-standards/standards/weight-for-length-height',
                        ),
                      ],
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Đóng'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const GrowthAsset('explanation-globe', size: 42),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Tiêu chuẩn tăng trưởng trẻ em của\nTổ chức Y tế Thế giới (WHO)',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF4C6585),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF172A4B),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _basis(String asset, Color color, String title, String body) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 46,
        height: 46,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: GrowthAsset(asset, size: 36),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: easyRead ? 18 : 14,
                fontWeight: FontWeight.w800,
                height: 1.4,
                color: const Color(0xFF172A4B),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              body,
              style: TextStyle(
                fontSize: easyRead ? 18 : 14,
                height: 1.45,
                color: const Color(0xFF4C6585),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
