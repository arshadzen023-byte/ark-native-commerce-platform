import 'dart:async';
import 'package:flutter/material.dart';

/// Shared live countdown used by both the native Designer preview and Home.
/// The layout sizes itself to the available width and follows the title scale.
class DesignerCountdownCard extends StatefulWidget {
  const DesignerCountdownCard({
    super.key,
    required this.target,
    this.titleFontSize = 18,
  });

  final DateTime target;
  final double titleFontSize;

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
    final scale = (widget.titleFontSize / 18).clamp(.75, 1.15).toDouble();
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

        return Center(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF51408F),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF51408F).withValues(alpha: .16),
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
                      color: Colors.white.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          values[i].$1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
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
                            color: Colors.white.withValues(alpha: .82),
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
