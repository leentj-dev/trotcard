import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trotcard/models/song.dart';
import 'package:trotcard/widgets/greeting_card.dart';

void main() {
  testWidgets('EditShareScreen builds without throwing', (tester) async {
    const card = GreetingCard(
      text: '안녕하세요\n좋은 하루 되세요',
      emoji: '😊',
      gradient: 'warm',
      category: '인사',
    );
    await tester.pumpWidget(
      const MaterialApp(home: EditShareScreen(card: card)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final err = tester.takeException();
    expect(err, isNull, reason: 'build threw: $err');
  });
}
