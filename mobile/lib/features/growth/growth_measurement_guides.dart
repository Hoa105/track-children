import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'growth_models.dart';
import 'growth_tracking_flow.dart';

class GrowthMeasurementGuide {
  const GrowthMeasurementGuide({
    required this.id,
    required this.indicator,
    required this.title,
    required this.ageHint,
    required this.imageAsset,
    required this.imageCaption,
    required this.imageAnnotations,
    required this.shortHint,
    required this.preparation,
    required this.steps,
    required this.tip,
    this.fallback,
    required this.sourceIds,
  });

  final String id;
  final String indicator;
  final String title;
  final String ageHint;
  final String imageAsset;
  final String imageCaption;
  final List<String> imageAnnotations;
  final String shortHint;
  final String preparation;
  final List<String> steps;
  final String tip;
  final String? fallback;
  final List<String> sourceIds;
}

class GrowthGuideSource {
  const GrowthGuideSource({
    required this.id,
    required this.organization,
    required this.title,
    required this.url,
    this.licenseNote,
  });

  final String id;
  final String organization;
  final String title;
  final String url;
  final String? licenseNote;
}

/// Canonical parent measurement guides sourced from
/// `docs/be_lon_khon_measurement_guides/measurement_guides.vi.json`
/// and `docs/be_lon_khon_measurement_guides/image_captions_and_sources.md`.
abstract final class GrowthMeasurementGuides {
  static const schemaVersion = '1.0.0';
  static const locale = 'vi-VN';
  static const globalNote =
      'Số đo tại nhà có thể sai lệch. Nếu kết quả thay đổi bất thường hoặc bạn lo lắng về sự phát triển của bé, hãy trao đổi với nhân viên y tế.';

  static const Map<String, GrowthGuideSource> sources = {
    'WHO_2008': GrowthGuideSource(
      id: 'WHO_2008',
      organization: 'World Health Organization',
      title:
          'WHO Child Growth Standards: Training Course on Child Growth Assessment (Module B; Photo Booklet)',
      url: 'https://www.who.int/publications/i/item/9789241595070/',
      licenseNote:
          'Trang khóa học ghi CC BY-NC-SA 3.0 IGO; kiểm tra giấy phép riêng cho ảnh/tệp trước khi tái sử dụng.',
    ),
    'AAP_2026': GrowthGuideSource(
      id: 'AAP_2026',
      organization: 'American Academy of Pediatrics',
      title: 'Anthropometric Measurements',
      url:
          'https://www.aap.org/en/patient-care/newborn-infant-and-early-childhood-nutrition/newborn-and-infant-nutrition-assessment-tools/anthropometric-measurements/',
    ),
    'CDC_2024': GrowthGuideSource(
      id: 'CDC_2024',
      organization: 'Centers for Disease Control and Prevention',
      title: "Measuring Children's Height and Weight",
      url:
          'https://www.cdc.gov/bmi/child-teen-calculator/measure-child-height-weight.html',
    ),
    'SICKKIDS_2021': GrowthGuideSource(
      id: 'SICKKIDS_2021',
      organization: 'The Hospital for Sick Children (SickKids)',
      title:
          "Virtual care: How to accurately measure your child's height and weight at home",
      url:
          'https://assets.aboutkidshealth.ca/healthaz/na/virtual-care-how-to-accurately-measure-your-childs-height-and-weight-at-home/',
    ),
  };

  static const List<GrowthMeasurementGuide> all = [
    GrowthMeasurementGuide(
      id: 'weight_infant',
      indicator: 'weight_kg',
      title: 'Cân bé khi chưa đứng vững',
      ageHint: 'Dành cho bé chưa đứng vững',
      imageAsset: 'measure_weight_infant.webp',
      imageCaption: 'Đặt bé nằm giữa cân em bé và chờ số ổn định.',
      imageAnnotations: ['Cân về 0', 'Bé nằm giữa cân', 'Luôn ở cạnh bé'],
      shortHint: 'Nếu cân nằm, hãy cho bé nằm giữa cân.',
      preparation: 'Cân em bé đặt chắc chắn, khăn mỏng nếu cần.',
      steps: [
        'Đặt cân ở chỗ chắc chắn và chờ cân hiện số 0.',
        'Cởi bớt quần áo dày của bé. Nếu dùng khăn, hãy trừ trọng lượng khăn trước khi cân.',
        'Nhẹ nhàng đặt bé nằm giữa cân, luôn ở bên cạnh bé.',
        'Chờ số cân ổn định rồi ghi kết quả (kg).',
      ],
      tip:
          'Không để bé nằm một mình trên cân. Nếu bé quẫy nhiều, hãy thử lại khi bé bình tĩnh.',
      fallback:
          'Nếu không có cân em bé, bạn có thể cân mình rồi cân khi bế bé, lấy số sau trừ số trước. Cách này chỉ cho kết quả ước tính, đặc biệt khi bé còn rất nhỏ.',
      sourceIds: ['AAP_2026', 'SICKKIDS_2021'],
    ),
    GrowthMeasurementGuide(
      id: 'weight_standing',
      indicator: 'weight_kg',
      title: 'Cân bé khi đã đứng vững',
      ageHint: 'Dành cho bé có thể tự đứng yên',
      imageAsset: 'measure_weight_standing.webp',
      imageCaption: 'Bé đứng yên giữa cân, không mang giày dép.',
      imageAnnotations: ['Nền cứng', 'Bỏ giày', 'Đứng giữa cân'],
      shortHint: 'Cho bé đứng yên giữa cân, không mang giày.',
      preparation: 'Cân điện tử và nền nhà phẳng, cứng.',
      steps: [
        'Đặt cân trên nền cứng, không đặt trên thảm. Chờ cân hiện số 0.',
        'Cho bé bỏ giày dép và áo khoác dày.',
        'Cho bé đứng giữa cân, hai chân đặt vững và giữ yên.',
        'Khi số cân ổn định, ghi kết quả (kg).',
      ],
      tip:
          'Nên cân lại một lần. Nếu hai lần khác nhau rõ rệt, kiểm tra cân rồi thử lại.',
      sourceIds: ['CDC_2024', 'SICKKIDS_2021', 'AAP_2026'],
    ),
    GrowthMeasurementGuide(
      id: 'length_lying',
      indicator: 'length_cm',
      title: 'Đo chiều dài khi bé nằm',
      ageHint: 'Ưu tiên cho bé dưới 24 tháng',
      imageAsset: 'measure_length_lying.webp',
      imageCaption: 'Một người giữ đầu, một người nhẹ nhàng giữ chân bé.',
      imageAnnotations: [
        'Đầu chạm chặn',
        'Chân duỗi nhẹ',
        'Bàn chân hướng lên',
      ],
      shortHint: 'Bé dưới 2 tuổi nên đo khi nằm, có hai người hỗ trợ.',
      preparation:
          'Tốt nhất là thước đo chiều dài cho trẻ có chặn đầu và chặn chân; cần hai người hỗ trợ.',
      steps: [
        'Đặt bé nằm ngửa, bỏ mũ, giày và tất.',
        'Một người giữ nhẹ đầu bé thẳng, áp sát đầu thước.',
        'Người còn lại nhẹ nhàng duỗi chân bé, giữ bàn chân hướng lên.',
        'Đưa tấm chặn chân chạm vào lòng bàn chân rồi đọc kết quả (cm).',
      ],
      tip:
          'Không kéo mạnh chân bé. Nếu chưa có thước đo chuyên dụng, phép đo tại nhà chỉ mang tính tham khảo; bạn có thể nhờ nhân viên y tế đo lại.',
      sourceIds: ['WHO_2008', 'AAP_2026', 'SICKKIDS_2021'],
    ),
    GrowthMeasurementGuide(
      id: 'height_standing',
      indicator: 'height_cm',
      title: 'Đo chiều cao khi bé đứng',
      ageHint: 'Ưu tiên từ 24 tháng nếu bé đứng vững',
      imageAsset: 'measure_height_standing.webp',
      imageCaption: 'Bé đứng thẳng sát tường, mắt nhìn về phía trước.',
      imageAnnotations: ['Bỏ giày', 'Không nhón chân', 'Sách đặt ngang'],
      shortHint: 'Bé đứng thẳng sát tường, chân đặt phẳng trên sàn.',
      preparation:
          'Tường phẳng, sàn cứng, quyển sách hoặc thước cứng và thước dây.',
      steps: [
        'Cho bé bỏ giày, mũ và phụ kiện tóc.',
        'Cho bé đứng thẳng sát tường trên nền cứng, mắt nhìn trước, không nhón chân.',
        'Đặt một quyển sách phẳng lên đỉnh đầu sao cho vuông góc với tường, rồi đánh dấu mép dưới của sách.',
        'Đo từ sàn đến dấu vừa đánh và ghi kết quả (cm).',
      ],
      tip:
          'Nên đo hai lần để kiểm tra. Nếu bé chưa thể đứng thẳng, hãy nhờ nhân viên y tế hướng dẫn cách đo phù hợp.',
      sourceIds: ['CDC_2024', 'SICKKIDS_2021', 'AAP_2026'],
    ),
    GrowthMeasurementGuide(
      id: 'head_circumference',
      indicator: 'head_circum_cm',
      title: 'Đo vòng đầu cho bé',
      ageHint: 'Đặc biệt quan trọng cho bé dưới 36 tháng',
      imageAsset: 'measure_head_circumference.webp',
      imageCaption:
          'Đặt thước ngang trên lông mày và vòng qua phần sau đầu lớn nhất.',
      imageAnnotations: ['Trên lông mày', 'Qua sau đầu', 'Không siết chặt'],
      shortHint: 'Quấn thước quanh trán và phần nhô nhất phía sau đầu.',
      preparation: 'Thước dây mềm, không co giãn.',
      steps: [
        'Tháo mũ, băng đô và phụ kiện tóc của bé.',
        'Quấn thước quanh đầu, ở phía trước ngay trên lông mày và phía trên tai.',
        'Đưa thước vòng qua phần nhô nhất ở phía sau đầu. Dịch nhẹ để tìm vòng lớn nhất.',
        'Giữ thước ôm sát nhưng không siết chặt, rồi ghi kết quả (cm).',
      ],
      tip:
          'Đo lại hai lần để kiểm tra. Nếu khó giữ thước đúng vị trí, hãy nhờ nhân viên y tế hỗ trợ.',
      sourceIds: ['AAP_2026'],
    ),
  ];

  static GrowthMeasurementGuide byId(String id) =>
      all.firstWhere((g) => g.id == id, orElse: () => all.first);

  /// Tailors illustration height to the distinct framing and orientation
  /// of each measurement method:
  /// - standing height: benchmark full-body portrait (245)
  /// - head circumference: clear close-up of baby head and tape (235)
  /// - standing weight: balanced toddler height synchronized with standing height (230)
  /// - infant weight: compact infant scale presentation (225)
  /// - lying length: wide horizontal layout on length board (225)
  static double imageHeight(String id) => switch (id) {
    'height_standing' => 245.0,
    'head_circumference' => 235.0,
    'weight_standing' => 230.0,
    'weight_infant' => 225.0,
    'length_lying' => 225.0,
    _ => 230.0,
  };

  static bool isStandingAge(DateTime? birth, DateTime measuredAt) {
    if (birth == null) return false;
    final months = growthChartAgeMonths(birth, measuredAt);
    if (months != null) return months >= 24;
    return DateUtils.dateOnly(
          measuredAt,
        ).difference(DateUtils.dateOnly(birth)).inDays >=
        731;
  }

  static String initialGuideId({
    required GrowthMetric metric,
    DateTime? birth,
    DateTime? measuredAt,
    GrowthMeasurementMethod? method,
  }) {
    final day = measuredAt ?? DateTime.now();
    return switch (metric) {
      GrowthMetric.headCircumference => 'head_circumference',
      GrowthMetric.lengthHeight =>
        method == GrowthMeasurementMethod.standing
            ? 'height_standing'
            : method == GrowthMeasurementMethod.recumbent
            ? 'length_lying'
            : isStandingAge(birth, day)
            ? 'height_standing'
            : 'length_lying',
      GrowthMetric.weight =>
        isStandingAge(birth, day) ? 'weight_standing' : 'weight_infant',
    };
  }
}

/// Compact "? Cách đo" link button placed next to measurement input fields.
class MeasurementGuideLink extends StatelessWidget {
  const MeasurementGuideLink({
    super.key,
    required this.metric,
    this.birth,
    this.measuredAt,
    this.method,
    this.onMethodChanged,
  });

  final GrowthMetric metric;
  final DateTime? birth;
  final DateTime? measuredAt;
  final GrowthMeasurementMethod? method;
  final ValueChanged<GrowthMeasurementMethod>? onMethodChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Cách đo ${metric.title.toLowerCase()}',
    child: Material(
      color: GrowthColors.primarySoft,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => showMeasurementGuideSheet(
          context,
          metric: metric,
          birth: birth,
          measuredAt: measuredAt,
          method: method,
          onMethodChanged: onMethodChanged,
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: 16,
                color: GrowthColors.primary,
              ),
              SizedBox(width: 4),
              Text(
                'Cách đo',
                style: TextStyle(
                  color: GrowthColors.primaryDark,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showMeasurementGuideSheet(
  BuildContext context, {
  required GrowthMetric metric,
  String? initialGuideId,
  DateTime? birth,
  DateTime? measuredAt,
  GrowthMeasurementMethod? method,
  ValueChanged<GrowthMeasurementMethod>? onMethodChanged,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: GrowthColors.background,
  builder: (sheetContext) => GrowthTheme(
    child: MeasurementGuideSheet(
      metric: metric,
      initialGuideId: initialGuideId,
      birth: birth,
      measuredAt: measuredAt,
      method: method,
      onMethodChanged: onMethodChanged,
    ),
  ),
);

class MeasurementGuideSheet extends StatefulWidget {
  const MeasurementGuideSheet({
    super.key,
    required this.metric,
    this.initialGuideId,
    this.birth,
    this.measuredAt,
    this.method,
    this.onMethodChanged,
  });

  final GrowthMetric metric;
  final String? initialGuideId;
  final DateTime? birth;
  final DateTime? measuredAt;
  final GrowthMeasurementMethod? method;
  final ValueChanged<GrowthMeasurementMethod>? onMethodChanged;

  @override
  State<MeasurementGuideSheet> createState() => _MeasurementGuideSheetState();
}

class _MeasurementGuideSheetState extends State<MeasurementGuideSheet> {
  late String _guideId = widget.initialGuideId ??
      GrowthMeasurementGuides.initialGuideId(
        metric: widget.metric,
        birth: widget.birth,
        measuredAt: widget.measuredAt,
        method: widget.method,
      );

  void _selectGuide(String id) {
    setState(() => _guideId = id);
    if (widget.metric == GrowthMetric.lengthHeight &&
        widget.onMethodChanged != null) {
      widget.onMethodChanged!(
        id == 'height_standing'
            ? GrowthMeasurementMethod.standing
            : GrowthMeasurementMethod.recumbent,
      );
    }
  }

  Widget _postureSwitcher() {
    if (widget.metric == GrowthMetric.headCircumference) {
      return const SizedBox.shrink();
    }
    final options = widget.metric == GrowthMetric.weight
        ? const [
            ('weight_infant', 'Bé chưa đứng vững'),
            ('weight_standing', 'Bé đã đứng vững'),
          ]
        : const [
            ('length_lying', 'Đo nằm (< 24 tháng)'),
            ('height_standing', 'Đo đứng (≥ 24 tháng)'),
          ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: GrowthColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GrowthColors.border),
        ),
        child: Row(
          children: [
            for (final (id, label) in options)
              Expanded(
                child: Material(
                  color: _guideId == id
                      ? GrowthColors.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: ValueKey('guide-switch-$id'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _selectGuide(id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _guideId == id
                              ? GrowthColors.textPrimary
                              : GrowthColors.textSecondary,
                          fontSize: 13,
                          fontWeight: _guideId == id
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
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

  @override
  Widget build(BuildContext context) {
    final guide = GrowthMeasurementGuides.byId(_guideId);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  Text(
                    guide.title,
                    key: const ValueKey('measurement-guide-title'),
                    style: const TextStyle(
                      color: GrowthColors.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: GrowthColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            guide.ageHint,
                            style: const TextStyle(
                              color: GrowthColors.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _postureSwitcher(),
                  _GuideIllustrationCard(guide: guide),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: GrowthColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: GrowthColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: GrowthColors.iconBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.checklist_rounded,
                            size: 18,
                            color: GrowthColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Chuẩn bị',
                                style: TextStyle(
                                  color: GrowthColors.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                guide.preparation,
                                style: const TextStyle(
                                  color: GrowthColors.textSecondary,
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: GrowthColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GrowthColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Các bước thực hiện',
                          style: TextStyle(
                            color: GrowthColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (var i = 0; i < guide.steps.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: GrowthColors.iconBackground,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: GrowthColors.primaryDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  guide.steps[i],
                                  style: const TextStyle(
                                    color: GrowthColors.textPrimary,
                                    fontSize: 14,
                                    height: 1.45,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: GrowthColors.primarySoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: GrowthColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 18,
                              color: GrowthColors.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Lưu ý khi đo',
                              style: TextStyle(
                                color: GrowthColors.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          guide.tip,
                          style: const TextStyle(
                            color: GrowthColors.textPrimary,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                        if (guide.fallback != null) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Text(
                            guide.fallback!,
                            style: const TextStyle(
                              color: GrowthColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    GrowthMeasurementGuides.globalNote,
                    style: const TextStyle(
                      color: GrowthColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('measurement-guide-dismiss'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: GrowthColors.primary,
                foregroundColor: GrowthColors.surface,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideIllustrationCard extends StatelessWidget {
  const _GuideIllustrationCard({required this.guide});

  final GrowthMeasurementGuide guide;

  IconData _postureIcon() => switch (guide.id) {
    'weight_infant' => Icons.baby_changing_station_rounded,
    'weight_standing' => Icons.monitor_weight_outlined,
    'length_lying' => Icons.airline_seat_flat_outlined,
    'height_standing' => Icons.accessibility_new_rounded,
    _ => Icons.face_retouching_natural_outlined,
  };

  double _imageHeight() => GrowthMeasurementGuides.imageHeight(guide.id);

  @override
  Widget build(BuildContext context) {
    final assetPath = 'assets/images/growth/guides/${guide.imageAsset}';
    final pngFallbackPath = assetPath.replaceFirst(
      RegExp(r'\.webp$'),
      '.png',
    );
    final targetHeight = _imageHeight();
    return Semantics(
      image: true,
      label: guide.imageCaption,
      child: Container(
        key: ValueKey('guide-illustration-${guide.id}'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GrowthColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: GrowthColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                minHeight: 160,
                maxHeight: targetHeight,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: GrowthColors.primarySoft.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.asset(
                assetPath,
                width: double.infinity,
                height: targetHeight,
                fit: BoxFit.contain,
                semanticLabel: guide.imageCaption,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  pngFallbackPath,
                  width: double.infinity,
                  height: targetHeight,
                  fit: BoxFit.contain,
                  semanticLabel: guide.imageCaption,
                  errorBuilder: (context, error, stackTrace) => SizedBox(
                    height: 150,
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: GrowthColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _postureIcon(),
                          size: 30,
                          color: GrowthColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in guide.imageAnnotations)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: GrowthColors.primarySoft,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: GrowthColors.border),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: GrowthColors.primaryDark,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              guide.imageCaption,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: GrowthColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
