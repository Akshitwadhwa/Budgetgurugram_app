import 'package:flutter_test/flutter_test.dart';
import 'package:budget_gurugram/main.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const BudgetGurugramApp());
    await tester.pump();
    expect(find.byType(BudgetGurugramApp), findsOneWidget);
  });
}
