import 'package:flutter_test/flutter_test.dart';
import 'package:docudiget/state/ocr_state.dart';

void main() {
  group('HTML to Markdown table conversion tests', () {
    test('converts simple HTML table to Markdown', () {
      const input = '''
Some introductory text.

<table>
  <tr>
    <th>Header 1</th>
    <th>Header 2</th>
  </tr>
  <tr>
    <td>Value 1</td>
    <td>Value 2</td>
  </tr>
</table>

Some trailing text.
''';

      final output = convertHtmlTablesToMarkdown(input);

      expect(output, contains('| Header 1 | Header 2 |'));
      expect(output, contains('| --- | --- |'));
      expect(output, contains('| Value 1 | Value 2 |'));
      expect(output, isNot(contains('<table>')));
      expect(output, isNot(contains('<tr>')));
    });

    test('handles case-insensitive and attribute-laden table tags', () {
      const input = '''
<TABLE class="my-table" style="color: red;">
  <TR>
    <TH align="left">A</TH>
    <TH>B</TH>
  </TR>
  <TR>
    <TD>1</TD>
    <TD>2</TD>
  </TR>
</TABLE>
''';

      final output = convertHtmlTablesToMarkdown(input);

      expect(output, contains('| A | B |'));
      expect(output, contains('| --- | --- |'));
      expect(output, contains('| 1 | 2 |'));
    });

    test('ignores helper tags like thead/tbody but matches tr/td', () {
      const input = '''
<table>
  <thead>
    <tr><th>ColA</th><th>ColB</th></tr>
  </thead>
  <tbody>
    <tr><td>ValA</td><td>ValB</td></tr>
  </tbody>
</table>
''';

      final output = convertHtmlTablesToMarkdown(input);

      expect(output, contains('| ColA | ColB |'));
      expect(output, contains('| --- | --- |'));
      expect(output, contains('| ValA | ValB |'));
    });

    test('strips inner html tags inside table cells', () {
      const input = '''
<table>
  <tr>
    <th><b>Bold Header</b></th>
    <th><span class="highlight">Span Header</span></th>
  </tr>
  <tr>
    <td><p>Paragraph Cell</p></td>
    <td>Plain Cell</td>
  </tr>
</table>
''';

      final output = convertHtmlTablesToMarkdown(input);

      expect(output, contains('| Bold Header | Span Header |'));
      expect(output, contains('| Paragraph Cell | Plain Cell |'));
    });
  });
}
