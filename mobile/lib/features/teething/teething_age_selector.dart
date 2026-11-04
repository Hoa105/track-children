import 'package:flutter/material.dart';

import '../../app_colors.dart';

/// A shared age selection for reference and parent-recorded teeth.
class TeethingAgeSelector extends StatefulWidget {
  const TeethingAgeSelector({
    super.key,
    required this.month,
    required this.currentMonth,
    required this.maxMonth,
    required this.onChanged,
  });

  final int month;
  final int currentMonth;
  final int maxMonth;
  final ValueChanged<int> onChanged;

  @override
  State<TeethingAgeSelector> createState() => _TeethingAgeSelectorState();
}

class _TeethingAgeSelectorState extends State<TeethingAgeSelector> {
  final _scroll = ScrollController();
  int? _centeredMonth;
  double? _viewportWidth;
  double? _itemExtent;
  bool _positioned = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ages = List<int>.generate(61, (month) => month);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final extent = 100.0 * scale;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_centeredMonth != widget.month ||
            _viewportWidth != constraints.maxWidth ||
            _itemExtent != extent) {
          _centeredMonth = widget.month;
          _viewportWidth = constraints.maxWidth;
          _itemExtent = extent;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scroll.hasClients) return;
            final target =
                (ages.indexOf(widget.month) * extent -
                        (constraints.maxWidth - extent) / 2 +
                        16)
                    .clamp(0.0, _scroll.position.maxScrollExtent);
            if ((_scroll.offset - target).abs() > 1) {
              if (!_positioned || MediaQuery.disableAnimationsOf(context)) {
                _scroll.jumpTo(target);
              } else {
                _scroll.animateTo(
                  target,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                );
              }
            }
            _positioned = true;
          });
        }
        return SizedBox(
          height: 48 * scale + 12,
          child: ListView.builder(
            key: const Key('teething-age-selector'),
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            itemExtent: extent,
            itemCount: ages.length,
            itemBuilder: (context, index) {
              final age = ages[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Semantics(
                  selected: widget.month == age,
                  child: FilledButton(
                    key: Key('reference-age-$age'),
                    onPressed: age <= widget.maxMonth
                        ? () => widget.onChanged(age)
                        : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      backgroundColor: widget.month == age
                          ? AppColors.primary
                          : AppColors.primarySoft,
                      foregroundColor: widget.month == age
                          ? Colors.white
                          : AppColors.primaryDark,
                    ),
                    child: Text('$age tháng'),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
