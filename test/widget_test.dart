import 'package:flutter_test/flutter_test.dart';
import 'package:masroofi_smart/main.dart';

void main() {
  testWidgets('Masroofi Smart starts', (tester) async {
    await tester.pumpWidget(const MasroofiSmartApp());
    expect(find.text('مصروفي الذكي'), findsOneWidget);
  });
}
