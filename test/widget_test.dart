import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/main.dart';

void main() {
  setUp(() {
    // main() loads .env and the app reads the token from secure storage; tests have neither.
    dotenv.loadFromString(envString: 'USE_LOCAL_SERVER=false');
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('MetanoiaApp boots up correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MetanoiaApp());
    expect(find.byType(MetanoiaApp), findsOneWidget);
  });
}
