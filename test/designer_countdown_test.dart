import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowhit_shopping/designer_countdown.dart';

void main() {
  testWidgets('countdown card shows all four live time units', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: DesignerCountdownCard(
            target: DateTime.now().add(const Duration(days: 2, hours: 3, minutes: 4, seconds: 8)),
          ),
        ),
      ),
    ));

    expect(find.text('DAYS'), findsOneWidget);
    expect(find.text('HRS'), findsOneWidget);
    expect(find.text('MIN'), findsOneWidget);
    expect(find.text('SEC'), findsOneWidget);
  });

  testWidgets('countdown card scales down with smaller title text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(220, 120));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: DesignerCountdownCard(
            target: DateTime.now().add(const Duration(days: 1)),
            titleFontSize: 11,
          ),
        ),
      ),
    ));

    expect(find.text('DAYS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
  testWidgets('countdown supports custom size, colours and right alignment', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: DesignerCountdownCard(
            target: DateTime.now().add(const Duration(hours: 2)),
            size: 26,
            backgroundColor: Colors.teal,
            textColor: Colors.yellow,
            labelColor: Colors.white,
            alignment: Alignment.centerRight,
          ),
        ),
      ),
    ));

    expect(find.byWidgetPredicate(
      (widget) => widget is Align && widget.alignment == Alignment.centerRight,
    ), findsOneWidget);
    expect(tester.widget<Text>(find.text('DAYS')).style?.color, Colors.white);
    expect(tester.takeException(), isNull);
  });

}
