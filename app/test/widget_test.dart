import 'package:creativebackground/core/widgets/pro_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ProBadge renders the PRO label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: ProBadge()))),
    );
    expect(find.text('PRO'), findsOneWidget);
  });
}
