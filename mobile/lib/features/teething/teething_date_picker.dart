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
    final maxDay = DateTime(value.year, value.month + 1, 0).day;
    final itemExtent = MediaQuery.textScalerOf(context).scale(22) + 18;
    Widget wheel(
      String label,
      int min,
      int max,
      int selected,
      ValueChanged<int> change,
    ) => Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            height: itemExtent * 3,
            child: _NumberWheel(
              key: ValueKey('$label-$min-$max'),
              label: label,
              min: min,
              max: max,
              selected: selected,
              itemExtent: itemExtent,
              onChanged: change,
              looping: label != 'Năm',
            ),
          ),
        ],
      ),
    );
    return Container(
      key: const Key('teething-date-picker'),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
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
            1,
            maxDay,
            value.day,
            (day) => _select(value.year, value.month, day),
          ),
          wheel(
            'Tháng',
            1,
            12,
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
    required this.looping,
  });
  final String label;
  final int min, max, selected;
  final double itemExtent;
  final ValueChanged<int> onChanged;
  final bool looping;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final index = widget.selected - widget.min;
      final count = widget.max - widget.min + 1;
      final current = _controller.selectedItem;
      if (widget.looping) {
        final delta = (index - current) % count;
        if (delta != 0) {
          _controller.jumpToItem(
            current + (delta > count / 2 ? delta - count : delta),
          );
        }
      } else if (current != index) {
        _controller.jumpToItem(index);
      }
    });
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
    looping: widget.looping,
    selectionOverlay: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: .45),
          width: 1.5,
        ),
      ),
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
                style: TextStyle(
                  fontSize: n == widget.selected ? 24 : 20,
                  fontWeight: n == widget.selected
                      ? FontWeight.w800
                      : FontWeight.w400,
                  color: n == widget.selected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
