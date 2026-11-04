import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app_colors.dart';

/// Numeric date wheels restricted to the child's lifetime.
class TeethingDatePicker extends StatelessWidget {
  const TeethingDatePicker({
    super.key,
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
  });

  final DateTime value;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onChanged;

  void _select(int year, int month, int day) {
    final days = DateTime(year, month + 1, 0).day;
    var date = DateTime(year, month, day.clamp(1, days));
    if (date.isBefore(firstDate)) date = firstDate;
    if (date.isAfter(lastDate)) date = lastDate;
    onChanged(date);
  }

  @override
  Widget build(BuildContext context) {
    final minMonth = value.year == firstDate.year ? firstDate.month : 1;
    final maxMonth = value.year == lastDate.year ? lastDate.month : 12;
    final minDay =
        value.year == firstDate.year && value.month == firstDate.month
        ? firstDate.day
        : 1;
    final maxDay = value.year == lastDate.year && value.month == lastDate.month
        ? lastDate.day
        : DateTime(value.year, value.month + 1, 0).day;
    final itemExtent = MediaQuery.textScalerOf(context).scale(26) + 20;
    Widget wheel(
      String label,
      int min,
      int max,
      int selected,
      ValueChanged<int> change,
    ) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: itemExtent * 4.5,
            child: _NumberWheel(
              key: ValueKey('$label-$min-$max'),
              label: label,
              min: min,
              max: max,
              selected: selected,
              itemExtent: itemExtent,
              onChanged: change,
            ),
          ),
        ],
      ),
    );
    return Container(
      key: const Key('teething-date-picker'),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          wheel(
            'Ngày',
            minDay,
            maxDay,
            value.day,
            (day) => _select(value.year, value.month, day),
          ),
          wheel(
            'Tháng',
            minMonth,
            maxMonth,
            value.month,
            (month) => _select(value.year, month, value.day),
          ),
          wheel(
            'Năm',
            firstDate.year,
            lastDate.year,
            value.year,
            (year) => _select(year, value.month, value.day),
          ),
        ],
      ),
    );
  }
}

class _NumberWheel extends StatefulWidget {
  const _NumberWheel({
    super.key,
    required this.label,
    required this.min,
    required this.max,
    required this.selected,
    required this.itemExtent,
    required this.onChanged,
  });
  final String label;
  final int min, max, selected;
  final double itemExtent;
  final ValueChanged<int> onChanged;
  @override
  State<_NumberWheel> createState() => _NumberWheelState();
}

class _NumberWheelState extends State<_NumberWheel> {
  late final _controller = FixedExtentScrollController(
    initialItem: widget.selected - widget.min,
  );
  @override
  void didUpdateWidget(covariant _NumberWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        final index = widget.selected - widget.min;
        if (_controller.selectedItem != index) _controller.jumpToItem(index);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPicker(
    key: Key('teething-date-${widget.label}'),
    scrollController: _controller,
    itemExtent: widget.itemExtent,
    diameterRatio: 1.4,
    squeeze: 1.1,
    selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
      background: AppColors.primarySoft.withValues(alpha: .45),
    ),
    onSelectedItemChanged: (index) => widget.onChanged(widget.min + index),
    children: [
      for (var n = widget.min; n <= widget.max; n++)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$n',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
