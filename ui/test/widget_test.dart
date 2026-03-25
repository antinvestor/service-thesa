import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thesa/app.dart';

void main() {
  testWidgets('App renders dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ThesaApp()));
    await tester.pumpAndSettle();

    expect(find.text('Antinvestor'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
  });
}
