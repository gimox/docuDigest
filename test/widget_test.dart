import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docudiget/main.dart';

void main() {
  testWidgets('DocuDigest OCR initial layout smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Verify that our initial project management screen elements exist.
    expect(find.text('Gestione Progetti'), findsOneWidget);
    expect(find.text('Nuovo Progetto'), findsOneWidget);
  });
}

