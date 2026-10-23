import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../services/demo_store.dart';
import '../../services/milk_calculator.dart';

typedef _CalculationOutcome = ({MilkEstimate? estimate, String? reason});

class MilkCalculatorScreen extends StatefulWidget {
  const MilkCalculatorScreen({required this.childId, super.key})
    : _inputMode = false;
  const MilkCalculatorScreen._input({required this.childId})
    : _inputMode = true;
  final String childId;
  final bool _inputMode;

  @override
  State<MilkCalculatorScreen> createState() => _MilkCalculatorScreenState();
}

class _MilkCalculatorScreenState extends State<MilkCalculatorScreen> {
  final _form = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _feeds = TextEditingController(text: '8');
  static const _defaultPerFeedMl = 60;
  bool? _healthy;
  bool? _bottleOnly;
  bool _submitted = false;
  MilkEstimate? _result;
  String? _message;
  String? _measurementDate;

  @override
  void initState() {
    super.initState();
    final records =
        DemoStore.instance
            .records(widget.childId)
            .where((r) => r['v0'] is num && (r['v0'] as num) > 0)
            .toList()
          ..sort(
            (a, b) => a['date'].toString().compareTo(b['date'].toString()),
          );
    if (records.isNotEmpty) {
      _weight.text = records.last['v0'].toString();
      final date = DateTime.tryParse(records.last['date'].toString());
      if (date != null) {
        _measurementDate = '${date.day}/${date.month}/${date.year}';
      }
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _feeds.dispose();
    super.dispose();
  }

  void _invalidate() => setState(() {
    _message = null;
  });

  Future<void> _openCalculator() async {
    final result = await Navigator.of(context).push<_CalculationOutcome>(
      MaterialPageRoute(
        builder: (_) => MilkCalculatorScreen._input(childId: widget.childId),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _result = result.estimate;
      _message = result.reason;
    });
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    final valid = _form.currentState!.validate();
    if (!valid || _healthy == null || _bottleOnly == null) return;
    final child = DemoStore.instance.childById(widget.childId);
    final kg = double.parse(_weight.text.trim().replaceAll(',', '.'));
    final reason = milkEligibility(
      birthDate: DateTime.tryParse(child?['date_of_birth']?.toString() ?? ''),
      today: DateTime.now(),
      weightKg: kg,
      healthyFullTerm: _healthy!,
      exclusivelyBottleFed: _bottleOnly!,
    );
    Navigator.of(context).pop<_CalculationOutcome>((
      estimate: reason == null
          ? estimateMilk(kg, int.parse(_feeds.text.trim()))
          : null,
      reason: reason,
    ));
  }

  Text _heading(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
  );

  Widget _card(List<Widget> children, {Color color = AppColors.surface}) =>
      Material(
        color: color,
        textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 14,
          height: 1.5,
          color: AppColors.textSecondary,
          decoration: TextDecoration.none,
        ),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      );

  InputDecoration _input(String label, String suffix, {String? helper}) =>
      InputDecoration(
        labelText: label,
        suffixText: suffix,
        helperText: helper,
        helperMaxLines: 3,
        labelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );

  Widget _choice(
    String title,
    bool? value,
    void Function(bool) onChanged,
    String yes,
    String no,
    String requiredMessage,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final option in [true, false])
            ChoiceChip(
              label: Text(option ? yes : no),
              selected: value == option,
              selectedColor: AppColors.primarySoft,
              labelStyle: TextStyle(
                color: value == option
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) {
                _invalidate();
                onChanged(option);
              },
            ),
        ],
      ),
      if (_submitted && value == null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            requiredMessage,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
    ],
  );

  Widget _guidanceCard() => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: Color(0xFFDCE8DE)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _heading('Hướng dẫn và nguồn tham khảo')),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Mỗi bé có nhu cầu sữa riêng. Kết quả chỉ để tham khảo, hãy theo dõi dấu hiệu đói và no của bé.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _showGuidance,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            ),
            child: const Text(
              'Tìm hiểu thêm →',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );

  void _showGuidance() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * .8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.close),
              ),
            ),
            const Text(
              'Kiến thức về lượng sữa',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thông tin tham khảo dành cho ba mẹ',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            for (final item in const [
              (
                'Lượng sữa được tính như thế nào?',
                'Lượng tham khảo = cân nặng (kg) × 150 mL/kg/ngày, chia số cữ. Kết quả làm tròn đến mL; lượng uống từng cữ có thể khác nhau. Đây là thể tích sữa sau pha hoặc sữa mẹ vắt ra, không phải lượng nước pha.',
              ),
              (
                'Khi nào có thể dùng công cụ?',
                'Công cụ hỗ trợ bé từ đủ 7 ngày đến dưới 6 tháng, từ 2,5 kg, sinh đủ tháng, khỏe mạnh và hoàn toàn bú bình. Không dùng để tính sữa bổ sung khi bú mẹ trực tiếp. Bé sinh non, nhẹ cân hoặc có bệnh cần hướng dẫn riêng từ nhân viên y tế.',
              ),
              (
                'Cần lưu ý gì khi pha và cho bé uống?',
                'Pha đúng tỷ lệ nước và bột trên nhãn. Công cụ không tính số muỗng và không thay đổi tỷ lệ pha. Không ép bé uống hết theo kết quả; lượng uống mỗi cữ có thể khác nhau.',
              ),
            ])
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(
                    item.$1,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  children: [
                    Text(
                      item.$2,
                      style: const TextStyle(
                        height: 1.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            const Text(
              'Nguồn tham khảo',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'WHO (2021), Infant and young child feeding, trang 51: 150 mL/kg/ngày, chia 8 cữ cho trẻ từ 2,5 kg không thể bú mẹ. Số cữ khác trong công cụ chỉ là phép chia tổng lượng.',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
            const SelectableText(
              'https://iris.who.int/handle/10665/346568',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Giới hạn tuổi 7 ngày đến dưới 6 tháng là phạm vi của công cụ, có tham khảo NHS; không phải mốc tuổi do WHO quy định.',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
            const SelectableText(
              'https://derbyshirefamilyhealthservice.nhs.uk/our-services/0-5-years/infant-feeding-and-nutrition/formula-feeding',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final child = DemoStore.instance.childById(widget.childId);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget._inputMode ? 'Tính theo cân nặng' : 'Lượng sữa',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: child == null
          ? const Center(
              child: Text(
                'Hồ sơ bé không còn khả dụng. Vui lòng quay lại chọn bé.',
              ),
            )
          : DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
                decoration: TextDecoration.none,
              ),
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    if (!widget._inputMode)
                      _card([
                        _heading(
                          _message != null
                              ? 'Chưa thể ước tính'
                              : _result == null
                              ? 'Lượng sữa mặc định'
                              : 'Lượng sữa tham khảo',
                        ),
                        const SizedBox(height: 12),
                        if (_message == null)
                          Text(
                            _result == null
                                ? '$_defaultPerFeedMl mL/cữ'
                                : '${_result!.perFeedMl.toStringAsFixed(0)} mL/cữ',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.purpleText,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          _message ??
                              (_result == null
                                  ? 'Mức đặt sẵn của ứng dụng, không phải khuyến nghị cho mọi bé. Đây là lượng sữa sau pha.'
                                  : '${_result!.dailyMl.toStringAsFixed(0)} mL/ngày · ${_result!.feeds} cữ/ngày. Thể tích sữa sau pha, không phải lượng nước. Không ép bé uống hết.'),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            icon: const Icon(Icons.calculate_outlined),
                            onPressed: _openCalculator,
                            label: const Text('Tính theo cân nặng'),
                          ),
                        ),
                      ], color: AppColors.purpleSurfaceLight),
                    if (!widget._inputMode &&
                        (_result != null || _message != null))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            setState(() {
                              _result = null;
                              _message = null;
                            });
                          },
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Dùng mức mặc định'),
                        ),
                      ),
                    if (widget._inputMode) ...[
                      _card([
                        _heading('Ước tính theo cân nặng'),
                        const SizedBox(height: 4),
                        const Text(
                          'Bé đủ 7 ngày đến dưới 6 tháng · từ 2,5 kg',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _weight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: _input(
                            'Cân nặng',
                            'kg',
                            helper: _measurementDate == null
                                ? 'Nhập cân nặng hiện tại'
                                : 'Số đo ngày $_measurementDate',
                          ),
                          onChanged: (_) => _invalidate(),
                          validator: (text) {
                            final kg = double.tryParse(
                              (text ?? '').trim().replaceAll(',', '.'),
                            );
                            return kg == null || !kg.isFinite || kg <= 0
                                ? 'Nhập cân nặng lớn hơn 0.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _feeds,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: _input('Số cữ mỗi ngày', 'cữ'),
                          onChanged: (_) => _invalidate(),
                          validator: (text) {
                            final n = int.tryParse((text ?? '').trim());
                            return n == null || n < 1 || n > 24
                                ? 'Nhập số nguyên từ 1 đến 24.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _choice(
                          'Bé sinh đủ tháng và hiện khỏe mạnh?',
                          _healthy,
                          (v) => setState(() => _healthy = v),
                          'Có',
                          'Không / chưa rõ',
                          'Vui lòng chọn tình trạng sức khỏe của bé.',
                        ),
                        const SizedBox(height: 16),
                        _choice(
                          'Hình thức bú hiện tại',
                          _bottleOnly,
                          (v) => setState(() => _bottleOnly = v),
                          'Hoàn toàn bằng bình',
                          'Có bú mẹ trực tiếp',
                          'Vui lòng chọn hình thức bú của bé.',
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _calculate,
                            child: const Text(
                              'Tính lượng sữa',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Chỉ tính tham khảo, không lưu vào số đo.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 16),
                    if (!widget._inputMode) _guidanceCard(),
                  ],
                ),
              ),
            ),
    );
  }
}
