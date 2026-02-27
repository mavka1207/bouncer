import 'package:flutter_test/flutter_test.dart';
// import 'package:flutter/material.dart';
import 'package:bouncer/main.dart'; // подкорректируй импорт под свой пакет

void main() {
  testWidgets('Main menu renders with title and Start button', (tester) async {
    await tester.pumpWidget(const BouncerApp());

    expect(find.text('BOUNCER'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });
}
