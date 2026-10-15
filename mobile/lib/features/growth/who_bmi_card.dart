import '../../services/demo_store.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_colors.dart';
import '../../services/who_bmi_reference.dart';

class WhoBmiCard extends StatefulWidget {
  const WhoBmiCard({
    this.childId,
    this.compact = false,
    this.onProfileChanged,
    required this.childName,
    required this.preview,
    required this.measured,
    required this.bmi,
    super.key,
  });
  final String childName;
  final String? childId;
  final bool compact;
  final VoidCallback? onProfileChanged;
  final bool preview;
  final DateTime? measured;
  final double? bmi;
  @override
  State<WhoBmiCard> createState() => _WhoBmiCardState();
}

class _WhoBmiCardState extends State<WhoBmiCard> {
  WhoBmiReference? _reference;
  String? _sex;
  DateTime? _birth;
  bool _failed = false;
  String get _key => 'who_profile_${widget.childName}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reference = await WhoBmiReference.load();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _reference = reference;
        _sex = prefs.getString('${_key}_sex');
        _birth = DateTime.tryParse(prefs.getString('${_key}_birth') ?? '');
        final child = widget.childId == null
            ? null
            : DemoStore.instance.childById(widget.childId!);
        if (child != null) {
          _sex = child['gender'] == 'male' ? 'boys' : 'girls';
          _birth = DateTime.tryParse(child['date_of_birth'] as String);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _edit() async {
    String? sex = _sex;
    DateTime? birth = _birth;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Thông tin đối chiếu WHO'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Chọn giới tính và ngày sinh để tra tuổi tại ngày đo.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: sex,
                decoration: const InputDecoration(labelText: 'Giới tính'),
                items: const [
                  DropdownMenuItem(value: 'boys', child: Text('Bé trai')),
                  DropdownMenuItem(value: 'girls', child: Text('Bé gái')),
                ],
                onChanged: (value) => update(() => sex = value),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  birth == null
                      ? 'Chọn ngày sinh'
                      : '${birth!.day}/${birth!.month}/${birth!.year}',
                ),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: birth ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null && context.mounted) {
                    update(() => birth = date);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: sex != null && birth != null
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
      if (widget.childId != null) {
        await DemoStore.instance.saveChild(widget.childId!, {
          'gender': sex == 'boys' ? 'male' : 'female',
          'date_of_birth': birth!.toIso8601String(),
        });
        if (!mounted) return;
        setState(() {
          _sex = sex;
          _birth = birth;
        });
        widget.onProfileChanged?.call();
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final sexSaved = await prefs.setString('${_key}_sex', sex!);
      final birthSaved = await prefs.setString(
        '${_key}_birth',
        birth!.toIso8601String(),
      );
      if (!sexSaved || !birthSaved) throw StateError('save failed');
      if (mounted) {
        setState(() {
          _sex = sex;
          _birth = birth;
        });
        widget.onProfileChanged?.call();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa lưu được thông tin đối chiếu.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Preview always uses a separate, explicit example rather than real metadata.
    final sex = widget.preview ? 'boys' : _sex;
    final months = widget.preview
        ? 8
        : _birth == null || widget.measured == null
        ? null
        : WhoBmiReference.ageMonths(_birth!, widget.measured!);
    final row = sex == null || months == null
        ? null
        : _reference?.row(sex, months);
    if (widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.preview
                ? 'Đối chiếu mẫu · Bé trai, 8 tháng ở lần đo mới nhất'
                : sex == null || months == null
                ? 'Chọn ngày sinh và giới tính để hiển thị đường WHO.'
                : '${sex == 'boys' ? 'Bé trai' : 'Bé gái'} · $months tháng ở lần đo mới nhất',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (!widget.preview)
            TextButton.icon(
              onPressed: _edit,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Thông tin đối chiếu WHO'),
            ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BMI chuẩn theo tuổi · WHO',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          if (_failed)
            const Text('Chưa tải được bảng chuẩn WHO. Hãy mở lại màn hình.')
          else if (_reference == null)
            const LinearProgressIndicator()
          else if (row == null)
            Text(
              months == null || sex == null
                  ? 'Chưa có khoảng tham chiếu'
                  : 'Tuổi tại ngày đo nằm ngoài bảng 0–60 tháng.',
            )
          else ...[
            Text(
              '${widget.preview ? 'Ví dụ mẫu · ' : ''}${sex == 'boys' ? 'Bé trai' : 'Bé gái'} · $months tháng tại ngày đo',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Trung vị tham chiếu',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            Text(
              '${row[7].toStringAsFixed(1)} kg/m²',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mốc −2 SD: ${row[5].toStringAsFixed(1)}  ·  +1 SD: ${row[8].toStringAsFixed(1)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            for (final i in [4, 5, 6, 7, 8, 9, 10])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        i == 7
                            ? 'Trung vị'
                            : '${i - 7 > 0 ? '+' : ''}${i - 7} SD',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (row[i] / row[10]).clamp(0.0, 1.0),
                          minHeight: 7,
                          backgroundColor: AppColors.background,
                          color: i == 7
                              ? AppColors.primary
                              : AppColors.primarySoft,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        row[i].toStringAsFixed(1),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.bmi != null)
              Text(
                'BMI từ số đo: ${widget.bmi!.toStringAsFixed(1)} kg/m²',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 12),
            const Text(
              'Dưới 2 tuổi dùng chiều dài đo nằm; từ 2 tuổi dùng chiều cao đo đứng. Nếu đo khác tư thế, cần quy đổi trước khi so sánh.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          if (!widget.preview)
            TextButton.icon(
              onPressed: _edit,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Text(
                _birth == null || _sex == null
                    ? 'Chọn thông tin đối chiếu'
                    : 'Sửa thông tin đối chiếu',
              ),
            ),
          const Divider(height: 24),
          const Text(
            'Nguồn: WHO Child Growth Standards · BMI-for-age, 0–5 tuổi. Các mốc thay đổi theo tuổi và giới tính; kết quả tham khảo không thay thế đánh giá của nhân viên y tế.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
