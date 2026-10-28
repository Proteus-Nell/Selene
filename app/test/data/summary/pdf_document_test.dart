// The PDF writer behind the summary for a doctor (ADR-0024).
//
// A file a doctor's computer has to open, written by hand rather than by a
// library, so what is pinned here is the file's structure: the header and
// trailer, a cross-reference table whose offsets are the objects' own, page
// text escaped as the format requires, and lines that wrap inside the page.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/summary/pdf_document.dart';

/// [bytes] as text, each byte a character.
String _text(List<int> bytes) => latin1.decode(bytes);

void main() {
  final created = DateTime.utc(2026, 10, 28, 9, 5, 7);

  group('a document', () {
    PdfDocument sample() {
      final document = PdfDocument(title: 'Cycle summary “1”');
      PdfFlow(document)
        ..paragraph('First page', size: 14, font: PdfFont.bold)
        ..paragraph(r'Text (with brackets) and a back\slash');
      document.addPage().text('Second page', x: 56, y: 700, size: 10);
      return document;
    }

    test('starts as PDF 1.4 and ends with its trailer', () {
      final file = _text(sample().encode(created: created));
      expect(file, startsWith('%PDF-1.4\n'));
      expect(file, endsWith('%%EOF\n'));
      expect(file, contains('/Count 2'));
    });

    test("points its cross-reference table at each object's own offset", () {
      final file = _text(sample().encode(created: created));
      final table = int.parse(
        RegExp(r'startxref\n(\d+)\n').firstMatch(file)!.group(1)!,
      );
      expect(file.substring(table), startsWith('xref\n'));
      final entries = RegExp(r'(\d{10}) 00000 n \n')
          .allMatches(file.substring(table))
          .map((match) => int.parse(match.group(1)!))
          .toList();
      // Catalog, pages, two fonts, information, and a page and its content
      // for each page.
      expect(entries, hasLength(5 + 2 * 2));
      for (final (i, offset) in entries.indexed) {
        expect(file.substring(offset), startsWith('${i + 1} 0 obj\n'));
      }
    });

    test('gives each content stream its true length', () {
      final file = _text(sample().encode(created: created));
      for (final match in RegExp(
        r'<< /Length (\d+) >>\nstream\n',
      ).allMatches(file)) {
        final length = int.parse(match.group(1)!);
        expect(
          file.substring(match.end + length),
          startsWith('endstream'),
        );
      }
    });

    test('escapes brackets and backslashes in page text', () {
      final file = _text(sample().encode(created: created));
      expect(file, contains(r'(Text \(with brackets\) and a back\\slash) Tj'));
    });

    test('writes its title in UTF-16, which any character survives', () {
      final file = _text(sample().encode(created: created));
      // "C" is 0043, and the left double quote 201C.
      expect(file, contains('/Title <FEFF0043'));
      expect(file, contains('201C'));
      expect(file, contains('/CreationDate (D:20261028090507Z)'));
    });
  });

  group('page text', () {
    test('is set in WinAnsi, escaped in octal above ASCII', () {
      final page = PdfDocument(title: 't').addPage()
        ..text('St. John’s – café', x: 0, y: 0, size: 10);
      expect(page.content, contains(r'(St. John\222s \226 caf\351)'));
    });

    test('writes a character WinAnsi has no code for as a question mark', () {
      expect(winAnsi('Ω'), <int>[0x3F]);
      expect(winAnsi('a\nb'), <int>[0x61, 0x20, 0x62]);
    });
  });

  group('widths', () {
    test("are Helvetica's own", () {
      // H 722, e 556, l 222, l 222, o 556: 2278 thousandths of an em, and
      // in bold 722, 556, 278, 278 and 611: 2445.
      expect(PdfFont.regular.widthOf('Hello', 10), closeTo(22.78, 1e-9));
      expect(PdfFont.bold.widthOf('Hello', 10), closeTo(24.45, 1e-9));
    });
  });

  group('wrapping', () {
    test('keeps every line inside the width', () {
      final lines = PdfFlow.wrap(
        'A long paragraph of words that has to be broken over several lines '
        'to fit inside a narrow column on the page.',
        width: 120,
        size: 10,
        font: PdfFont.regular,
      );
      expect(lines.length, greaterThan(2));
      for (final line in lines) {
        expect(PdfFont.regular.widthOf(line, 10), lessThanOrEqualTo(120));
      }
      expect(
        lines.join(' '),
        'A long paragraph of words that has to be broken over several lines '
        'to fit inside a narrow column on the page.',
      );
    });

    test('breaks a word wider than a line', () {
      final lines = PdfFlow.wrap(
        'Supercalifragilisticexpialidocious',
        width: 60,
        size: 10,
        font: PdfFont.regular,
      );
      expect(lines.length, greaterThan(1));
      expect(lines.join(), 'Supercalifragilisticexpialidocious');
    });

    test('gives one empty line for no text', () {
      expect(
        PdfFlow.wrap('', width: 60, size: 10, font: PdfFont.regular),
        <String>[''],
      );
    });
  });

  group('a flow', () {
    test('starts a new page when one is full, and sets the table header '
        'again on it', () {
      final document = PdfDocument(title: 't');
      PdfFlow(document).table(
        header: <String>['Started', 'Length'],
        rows: <List<String>>[
          for (var i = 0; i < 80; i++) <String>['Row $i', '$i'],
        ],
        columns: const <double>[0.5, 0.5],
      );
      expect(document.pages, hasLength(2));
      expect(document.pages[1].content, contains('(Started) Tj'));
      expect(document.pages[1].content, contains('(Row 79) Tj'));
    });

    test('numbers its pages once everything is laid out', () {
      final document = PdfDocument(title: 't');
      final flow = PdfFlow(document);
      for (var i = 0; i < 70; i++) {
        flow.paragraph('Line $i');
      }
      flow.footers(
        start: (page, count) => 'Footer',
        end: (page, count) => 'Page $page of $count',
      );
      expect(document.pages, hasLength(2));
      expect(document.pages[0].content, contains('(Page 1 of 2) Tj'));
      expect(document.pages[1].content, contains('(Page 2 of 2) Tj'));
    });
  });
}
