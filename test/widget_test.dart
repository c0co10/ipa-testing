import 'package:doodle_jump/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Builds and shows the ready screen', (tester) async {
    await tester.pumpWidget(const DoodleJumpApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Doodle Jump'), findsOneWidget);
    expect(find.text('Tap to Start'), findsOneWidget);
    expect(find.textContaining('Ride the springs'), findsOneWidget);
  });
}