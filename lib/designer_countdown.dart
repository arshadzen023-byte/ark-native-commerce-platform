import 'dart:async';
import 'package:flutter/material.dart';

/// Shared countdown used by the Designer preview and published Home renderer.
/// All visual properties are explicit so the editor preview matches the app.
class DesignerCountdownCard extends StatefulWidget {
  const DesignerCountdownCard({
    super.key,
    required this.target,
    this.titleFontSize = 18,
    this.size,
    this.backgroundColor = const Color(0xFF51408F),
    this.textColor = Colors.white,
    this.labelColor = const Color(0xFFEDE7F8),
    this.alignment = Alignment.centerLeft,
  });

  final DateTime target;

  /// Kept for compatibility with older callers and tests.
  final double titleFontSize;
  final double? size;
  final Color backgroundColor;
  final Color textColor;
  final Color labelColor;
  final AlignmentGeometry alignment;

  @override
  State<DesignerCountdownCard> createState() => _DesignerCountdownCardState();
}

class _DesignerCountdownCardState extends State<DesignerCountdownCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant DesignerCountdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.target.difference(DateTime.now());
    final total = remaining.isNegative ? 0 : remaining.inSeconds;
    final baseSize = (widget.size ?? widget.titleFontSize).clamp(10, 40).toDouble();
    final scale = (baseSize / 18).clamp(.58, 2.0).toDouble();
    final values = <(String, String)>[
      ((total ~/ 86400).toString().padLeft(2, '0'), 'DAYS'),
      (((total % 86400) ~/ 3600).toString().padLeft(2, '0'), 'HRS'),
      (((total % 3600) ~/ 60).toString().padLeft(2, '0'), 'MIN'),
      ((total % 60).toString().padLeft(2, '0'), 'SEC'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;
        final compact = available < 250;
        final numberSize = (compact ? 13.0 : 16.0) * scale;
        final labelSize = (compact ? 7.5 : 9.0) * scale;
        final gap = compact ? 4.0 : 6.0;
        final horizontalPadding = compact ? 5.0 : 8.0;
        final verticalPadding = compact ? 5.0 : 7.0;

        return Align(
          alignment: widget.alignment,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: widget.backgroundColor.withValues(alpha: .16),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < values.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Container(
                    constraints: BoxConstraints(
                      minWidth: compact ? 35 : 43,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 4 : 6,
                      vertical: compact ? 4 : 5,
                    ),
                    decoration: BoxDecoration(
                      color: widget.textColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          values[i].$1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: widget.textColor,
                            fontSize: numberSize,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          values[i].$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: widget.labelColor,
                            fontSize: labelSize,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .45,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
