import 'dart:async';
import 'package:flutter/material.dart';

/// Compact, responsive four-part countdown shared by Home and Designer preview.
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
    final scale = (widget.titleFontSize / 18).clamp(.65, 1.2).toDouble();
    final numberSize = (13 * scale).clamp(9.0, 15.0).toDouble();
    final labelSize = (6 * scale).clamp(5.0, 7.0).toDouble();
    final minWidth = (29 * scale).clamp(24.0, 34.0).toDouble();
    final gap = (3 * scale).clamp(2.0, 4.0).toDouble();
    final values = <(String, String)>[
      ((total ~/ 86400).toString().padLeft(2, '0'), 'DAYS'),
      (((total % 86400) ~/ 3600).toString().padLeft(2, '0'), 'HRS'),
      (((total % 3600) ~/ 60).toString().padLeft(2, '0'), 'MIN'),
      ((total % 60).toString().padLeft(2, '0'), 'SEC'),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 5 * scale,
        vertical: 4 * scale,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF51408F),
        borderRadius: BorderRadius.circular(9 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Container(
              constraints: BoxConstraints(minWidth: minWidth),
              padding: EdgeInsets.symmetric(
                horizontal: 3 * scale,
                vertical: 3 * scale,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(5 * scale),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    values[i].$1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: numberSize,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 2 * scale),
                  Text(
                    values[i].$2,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: labelSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .2,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
