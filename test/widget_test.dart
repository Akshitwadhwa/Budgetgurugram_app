import 'package:flutter_test/flutter_test.dart';
import 'package:gurugram_commons/main.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const GurugramCommonsApp());
    await tester.pump();
    expect(find.byType(GurugramCommonsApp), findsOneWidget);
  });
}
