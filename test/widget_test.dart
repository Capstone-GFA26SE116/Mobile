import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/main.dart';

void main() {
  testWidgets('MetanoiaApp boots up correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MetanoiaApp());
    expect(find.byType(MetanoiaApp), findsOneWidget);
  });
}
