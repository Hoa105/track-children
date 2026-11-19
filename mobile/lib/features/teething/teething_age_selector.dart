import 'package:flutter/material.dart';

import '../../app_colors.dart';

class TeethingAgeChoice {
  const TeethingAgeChoice({
    required this.month,
    required this.label,
    required this.id,
  });
  final int month;
  final String label, id;
}

/// A shared age selection for reference and parent-recorded teeth.
class TeethingAgeSelector extends StatefulWidget {
  const TeethingAgeSelector({
    super.key,
    required this.month,
    required this.currentMonth,
    required this.maxMonth,
    required this.onChanged,
    this.choices,
  });

  final int month;
  final int currentMonth;
  final int maxMonth;
  final ValueChanged<int> onChanged;
  final List<TeethingAgeChoice>? choices;

  @override
  State<TeethingAgeSelector> createState() => _TeethingAgeSelectorState();
}

class _TeethingAgeSelectorState extends State<TeethingAgeSelector> {
  final _scroll = ScrollController();
  int? _centeredMonth;
  double? _viewportWidth;
  double? _itemExtent;
  bool _positioned = false;
  bool _userScrolling = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final extent = (widget.choices == null ? 80.0 : 100.0) * scale;
    final selectedIndex = widget.choices == null
        ? widget.month
        : widget.choices!.indexWhere((choice) => choice.month == widget.month);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _userScrolling = true;
        } else if (notification is ScrollEndNotification) {
          _userScrolling = false;
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_centeredMonth != widget.month ||
              _viewportWidth != constraints.maxWidth ||
              _itemExtent != extent) {
            _centeredMonth = widget.month;
            _viewportWidth = constraints.maxWidth;
            _itemExtent = extent;
            final month = widget.month;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_scroll.hasClients || widget.month != month) {
                return;
              }
              // Do not interrupt a drag/fling or move a fully visible selection.
              final left = selectedIndex * extent + 16;
              final right = left + extent;
              if (_positioned &&
                  (_userScrolling ||
                      (left >= _scroll.offset &&
                          right <= _scroll.offset + constraints.maxWidth))) {
                return;
              }
              final target =
                  (selectedIndex * extent -
                          (constraints.maxWidth - extent) / 2 +
                          16)
                      .clamp(0.0, _scroll.position.maxScrollExtent);
              if ((_scroll.offset - target).abs() > 1) {
                if (!_positioned || MediaQuery.disableAnimationsOf(context)) {
                  _scroll.jumpTo(target);
                } else {
                  _scroll.animateTo(
                    target,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                  );
                }
              }
              _positioned = true;
            });
          }
          return SizedBox(
            height: 48 * scale + (widget.choices == null ? 8 : 0),
            child: ListView.builder(
              key: ValueKey(
                widget.choices == null
                    ? 'teething-age-selector'
                    : 'teething-stage-selector',
              ),
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: widget.choices == null ? 4 : 0,
              ),
              itemExtent: extent,
              itemCount: widget.choices?.length ?? 61,
              itemBuilder: (context, index) {
                final choice = widget.choices?[index];
                final age = choice?.month ?? index;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Semantics(
                    selected: widget.month == age,
                    child: FilledButton(
                      key: Key(choice?.id ?? 'reference-age-$age'),
                      onPressed: age <= widget.maxMonth
                          ? () => widget.onChanged(age)
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: Size(0, widget.choices == null ? 36 : 32),
                        tapTargetSize: MaterialTapTargetSize.padded,
                        textStyle: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        backgroundColor: widget.month == age
                            ? TeethingColors.accent
                            : TeethingColors.surface,
                        foregroundColor: TeethingColors.textPrimary,
                      ),
                      child: Text(choice?.label ?? '$age tháng'),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
