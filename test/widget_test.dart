import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docudiget/main.dart';

void main() {
  testWidgets('DocuDigest OCR initial layout smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Verify that our initial welcome screen elements exist.
    expect(find.text('Converti i tuoi PDF in Markdown'), findsOneWidget);
    expect(find.text('Seleziona PDF'), findsOneWidget);
  });
}

