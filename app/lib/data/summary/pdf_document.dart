/// A small PDF writer: pages of text and rules, in the base fonts.
///
/// Enough PDF for the summary a doctor is given (ADR-0024), and no more: text
/// in Helvetica and Helvetica Bold, which every PDF reader carries, so nothing
/// is embedded; thin grey rules; A4 pages; no images and no compression. Pure
/// Dart with no dependency, so the file can be checked byte by byte in a test,
/// and the app gains no library that could reach the network (ADR-0004).
///
/// Text is set in WinAnsiEncoding, the base fonts' own: English, the Latin-1
/// accents, typographic quotes and dashes, and the bullet. Anything else is
/// written as "?", which a summary of an English-only app does not meet.
///
/// Includes:
///     - PdfFont: The two faces, and their widths.
///     - PdfPage: One page's drawing.
///     - PdfDocument: The pages, and the file they make.
///     - PdfFlow: Text and tables laid down pages, a new one when one fills.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// The two faces a document is set in.
enum PdfFont {
  /// Helvetica.
  regular('Helvetica', 'F1', _helvetica),

  /// Helvetica Bold.
  bold('Helvetica-Bold', 'F2', _helveticaBold);

  const PdfFont(this.baseFont, this.resource, this._widths);

  /// The PostScript name of the base font.
  final String baseFont;

  /// The name a page's content refers to it by.
  final String resource;

  /// Advance widths in thousandths of an em, for codes 32 to 255.
  final List<int> _widths;

  /// How wide [text] is at [size] points, as it will be set.
  double widthOf(String text, double size) {
    var units = 0;
    for (final code in winAnsi(text)) {
      units += _widths[code - 32];
    }
    return units * size / 1000;
  }
}

/// [text] in WinAnsiEncoding, one byte a character.
///
/// A line break or a tab is a space. A character the encoding has no code for
/// is "?".
List<int> winAnsi(String text) => <int>[
  for (final rune in text.runes)
    if (rune == 0x09 || rune == 0x0A || rune == 0x0D)
      0x20
    else if ((rune >= 0x20 && rune <= 0x7E) || (rune >= 0xA0 && rune <= 0xFF))
      rune
    else
      _winAnsiExtras[rune] ?? 0x3F,
];

/// The characters WinAnsiEncoding puts at 128 to 159, by Unicode code point.
const Map<int, int> _winAnsiExtras = <int, int>{
  0x20AC: 0x80, // euro
  0x201A: 0x82, // low single quote
  0x0192: 0x83, // florin
  0x201E: 0x84, // low double quote
  0x2026: 0x85, // ellipsis
  0x2020: 0x86, // dagger
  0x2021: 0x87, // double dagger
  0x02C6: 0x88, // circumflex
  0x2030: 0x89, // per mille
  0x0160: 0x8A, // S caron
  0x2039: 0x8B, // single left angle quote
  0x0152: 0x8C, // OE
  0x017D: 0x8E, // Z caron
  0x2018: 0x91, // left single quote
  0x2019: 0x92, // right single quote, the apostrophe
  0x201C: 0x93, // left double quote
  0x201D: 0x94, // right double quote
  0x2022: 0x95, // bullet
  0x2013: 0x96, // en dash
  0x2014: 0x97, // em dash
  0x02DC: 0x98, // small tilde
  0x2122: 0x99, // trade mark
  0x0161: 0x9A, // s caron
  0x203A: 0x9B, // single right angle quote
  0x0153: 0x9C, // oe
  0x017E: 0x9E, // z caron
  0x0178: 0x9F, // Y diaeresis
};

/// One page: what is drawn on it, in PDF's own operators.
///
/// Coordinates are points from the bottom left, as PDF has them.
///
/// Attributes:
///     width (double): The page's width, in points.
///     height (double): Its height.
final class PdfPage {
  PdfPage._(this.width, this.height);

  /// The page's width, in points.
  final double width;

  /// The page's height, in points.
  final double height;

  /// The content stream so far.
  final StringBuffer _content = StringBuffer();

  /// Set [text] with its baseline starting at ([x], [y]). Nothing is written
  /// for no text, such as an empty table cell.
  ///
  /// Args:
  ///     text (String): What to set, on one line.
  ///     x (double): Where it starts.
  ///     y (double): Where its baseline is.
  ///     size (double): Its size, in points.
  ///     font (PdfFont): Its face. Defaults to [PdfFont.regular].
  ///     grey (double): Its colour, from 0 for black to 1 for white.
  ///         Defaults to 0.
  void text(
    String text, {
    required double x,
    required double y,
    required double size,
    PdfFont font = PdfFont.regular,
    double grey = 0,
  }) {
    if (text.isEmpty) return;
    _content.write(
      'BT /${font.resource} ${_number(size)} Tf ${_number(grey)} g '
      '${_number(x)} ${_number(y)} Td ${_literal(text)} Tj ET\n',
    );
  }

  /// Draw a straight rule from ([x1], [y1]) to ([x2], [y2]).
  ///
  /// Args:
  ///     x1 (double): Where it starts, across.
  ///     y1 (double): Where it starts, up.
  ///     x2 (double): Where it ends, across.
  ///     y2 (double): Where it ends, up.
  ///     width (double): Its thickness, in points. Defaults to 0.5.
  ///     grey (double): Its colour. Defaults to 0.7, a light grey.
  void line({
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    double width = 0.5,
    double grey = 0.7,
  }) => _content.write(
    '${_number(grey)} G ${_number(width)} w ${_number(x1)} ${_number(y1)} m '
    '${_number(x2)} ${_number(y2)} l S\n',
  );

  /// What has been drawn, as the page's content stream.
  String get content => _content.toString();
}

/// A document: pages, and the PDF file they make.
///
/// Attributes:
///     title (String): The title a reader shows for the file.
///     width (double): Each page's width, in points.
///     height (double): Each page's height.
///     pages (`List<PdfPage>`): The pages, in order.
final class PdfDocument {
  /// Creates an empty document of A4 pages.
  ///
  /// Args:
  ///     title (String): The title a reader shows for the file.
  ///     width (double, optional): Each page's width. Defaults to A4's.
  ///     height (double, optional): Each page's height. Defaults to A4's.
  PdfDocument({required this.title, this.width = 595.28, this.height = 841.89});

  /// The title a reader shows for the file.
  final String title;

  /// Each page's width, in points.
  final double width;

  /// Each page's height, in points.
  final double height;

  /// The pages, in order.
  final List<PdfPage> pages = <PdfPage>[];

  /// Add a page at the end, and return it.
  PdfPage addPage() {
    final page = PdfPage._(width, height);
    pages.add(page);
    return page;
  }

  /// Write the document as a PDF file.
  ///
  /// Args:
  ///     created (DateTime): When it was made, for the file's own record.
  ///
  /// Returns:
  ///     Uint8List: The file: PDF 1.4, every object uncompressed, and a
  ///     cross-reference table whose offsets are those of the bytes written.
  Uint8List encode({required DateTime created}) {
    final out = BytesBuilder(copy: false);
    final offsets = <int>[];
    void add(String text) => out.add(ascii.encode(text));
    void object(String body) {
      offsets.add(out.length);
      add('${offsets.length} 0 obj\n$body\nendobj\n');
    }

    add('%PDF-1.4\n');
    // Four bytes above 127, so that a transfer that treats the file as text
    // is seen to have damaged it.
    out.add(<int>[0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
    const firstPage = 6;
    final kids = <String>[
      for (var i = 0; i < pages.length; i++) '${firstPage + 2 * i} 0 R',
    ];
    object('<< /Type /Catalog /Pages 2 0 R >>');
    object(
      '<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pages.length} >>',
    );
    for (final font in PdfFont.values) {
      object(
        '<< /Type /Font /Subtype /Type1 /BaseFont /${font.baseFont} '
        '/Encoding /WinAnsiEncoding >>',
      );
    }
    object(
      '<< /Title ${_textString(title)} /Producer (Selene) '
      '/CreationDate (D:${_timestamp(created.toUtc())}Z) >>',
    );
    for (final (i, page) in pages.indexed) {
      object(
        '<< /Type /Page /Parent 2 0 R '
        '/MediaBox [0 0 ${_number(page.width)} ${_number(page.height)}] '
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> '
        '/Contents ${firstPage + 2 * i + 1} 0 R >>',
      );
      final content = page.content;
      object(
        '<< /Length ${ascii.encode(content).length} >>\nstream\n'
        '${content}endstream',
      );
    }
    final table = out.length;
    add('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n');
    for (final offset in offsets) {
      add('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    add(
      'trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R /Info 5 0 R >>\n'
      'startxref\n$table\n%%EOF\n',
    );
    return out.takeBytes();
  }
}

/// Text and tables laid down a document's pages, a new page whenever the one
/// being filled has no room for what comes next.
///
/// Attributes:
///     document (PdfDocument): Where the pages go.
///     margin (double): The space left at the top and either side.
///     bottom (double): The space left at the foot, where footers go.
final class PdfFlow {
  /// Starts laying out at the top of a new page of [document].
  PdfFlow(this.document, {this.margin = 56, this.bottom = 64}) {
    _newPage();
  }

  /// Where the pages go.
  final PdfDocument document;

  /// The space left at the top and either side, in points.
  final double margin;

  /// The space left at the foot of each page, in points.
  final double bottom;

  /// The page being filled.
  late PdfPage _page;

  /// How far down it is filled: the top of the space left.
  late double _y;

  /// Where text starts, across.
  double get left => margin;

  /// How wide a line may be.
  double get width => document.width - 2 * margin;

  /// The space between two lines' baselines, for text of [size].
  static double leading(double size) => size * 1.4;

  void _newPage() {
    _page = document.addPage();
    _y = document.height - margin;
  }

  /// Start a new page unless [height] more fits on this one.
  void keep(double height) {
    if (_y - height < bottom) _newPage();
  }

  /// Leave [height] points of space, or start a new page.
  void space(double height) {
    if (_y - height < bottom) {
      _newPage();
    } else {
      _y -= height;
    }
  }

  /// Set [text] as a paragraph, wrapped to the page.
  ///
  /// Args:
  ///     text (String): The paragraph.
  ///     size (double): Its size, in points. Defaults to 10.
  ///     font (PdfFont): Its face. Defaults to [PdfFont.regular].
  ///     grey (double): Its colour. Defaults to black.
  ///     indent (double): How far in it starts. Defaults to none.
  ///     keepWith (double): How much of what follows must fit on the page
  ///         with its first line, so that a heading is not left alone at the
  ///         foot of one. Defaults to none.
  void paragraph(
    String text, {
    double size = 10,
    PdfFont font = PdfFont.regular,
    double grey = 0,
    double indent = 0,
    double keepWith = 0,
  }) {
    final step = leading(size);
    final lines = wrap(text, width: width - indent, size: size, font: font);
    keep(step + keepWith);
    for (final line in lines) {
      keep(step);
      _y -= step;
      _page.text(
        line,
        x: left + indent,
        y: _y + step - size,
        size: size,
        font: font,
        grey: grey,
      );
    }
  }

  /// Draw a rule across the page, under what was set last.
  void rule() {
    keep(6);
    _y -= 3;
    _page.line(x1: left, y1: _y, x2: left + width, y2: _y);
    _y -= 3;
  }

  /// Set a table: a bold header row, a rule, and the rows under it.
  ///
  /// A cell wraps within its column. A row that does not fit starts a new
  /// page, and the header is set again at its top.
  ///
  /// Args:
  ///     header (`List<String>`): The columns' headings.
  ///     rows (`List<List<String>>`): The rows, each a cell a column.
  ///     columns (`List<double>`): Each column's share of the width, adding
  ///         up to 1.
  ///     size (double): The text's size. Defaults to 9.5.
  void table({
    required List<String> header,
    required List<List<String>> rows,
    required List<double> columns,
    double size = 9.5,
  }) {
    final step = leading(size);
    const gap = 8.0;
    final xs = <double>[];
    var x = left;
    for (final share in columns) {
      xs.add(x);
      x += share * width;
    }
    List<List<String>> wrapped(List<String> cells, PdfFont font) =>
        <List<String>>[
          for (final (i, cell) in cells.indexed)
            wrap(
              cell,
              width: columns[i] * width - (i == columns.length - 1 ? 0 : gap),
              size: size,
              font: font,
            ),
        ];
    void row(List<List<String>> cells, PdfFont font) {
      final height =
          step * cells.map((lines) => lines.length).fold(1, math.max);
      for (final (i, lines) in cells.indexed) {
        for (final (j, line) in lines.indexed) {
          _page.text(
            line,
            x: xs[i],
            y: _y - step * j - size,
            size: size,
            font: font,
          );
        }
      }
      _y -= height;
    }

    final head = wrapped(header, PdfFont.bold);
    final headHeight =
        step * head.map((lines) => lines.length).fold(1, math.max);
    void heading() {
      row(head, PdfFont.bold);
      _y -= 2;
      _page.line(x1: left, y1: _y, x2: left + width, y2: _y);
      _y -= 4;
    }

    final first = rows.isEmpty
        ? <List<String>>[]
        : wrapped(rows.first, PdfFont.regular);
    keep(
      headHeight +
          6 +
          step * first.map((lines) => lines.length).fold(1, math.max),
    );
    heading();
    for (final cells in rows) {
      final lines = wrapped(cells, PdfFont.regular);
      final height = step * lines.map((each) => each.length).fold(1, math.max);
      if (_y - height < bottom) {
        _newPage();
        heading();
      }
      row(lines, PdfFont.regular);
      // A little air between rows, so that a cell that wraps is not read as
      // running into the row below.
      _y -= 2;
    }
  }

  /// Set a footer on every page: [start] at the left, and [end] at the right,
  /// each told which page it is on and how many there are.
  ///
  /// Called once everything else is laid out, since only then is the number
  /// of pages known.
  void footers({
    required String Function(int page, int count) start,
    required String Function(int page, int count) end,
    double size = 8,
  }) {
    final count = document.pages.length;
    for (final (i, page) in document.pages.indexed) {
      final y = bottom / 2;
      page
        ..text(
          start(i + 1, count),
          x: left,
          y: y,
          size: size,
          grey: 0.4,
        )
        ..text(
          end(i + 1, count),
          x: left + width - PdfFont.regular.widthOf(end(i + 1, count), size),
          y: y,
          size: size,
          grey: 0.4,
        );
    }
  }

  /// Break [text] into lines no wider than [width].
  ///
  /// At spaces where it can, and inside a word only where the word is wider
  /// than a whole line.
  ///
  /// Args:
  ///     text (String): What to break.
  ///     width (double): The widest a line may be, in points.
  ///     size (double): The text's size.
  ///     font (PdfFont): Its face.
  ///
  /// Returns:
  ///     `List<String>`: The lines, in order. One empty line for no text.
  static List<String> wrap(
    String text, {
    required double width,
    required double size,
    required PdfFont font,
  }) {
    final lines = <String>[];
    var line = '';
    for (final word in text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty)) {
      final candidate = line.isEmpty ? word : '$line $word';
      if (font.widthOf(candidate, size) <= width) {
        line = candidate;
        continue;
      }
      if (line.isNotEmpty) lines.add(line);
      // A word wider than a line on its own is broken where it must be.
      var rest = word;
      while (font.widthOf(rest, size) > width && rest.length > 1) {
        var cut = rest.length - 1;
        while (cut > 1 && font.widthOf(rest.substring(0, cut), size) > width) {
          cut--;
        }
        lines.add(rest.substring(0, cut));
        rest = rest.substring(cut);
      }
      line = rest;
    }
    if (line.isNotEmpty || lines.isEmpty) lines.add(line);
    return lines;
  }
}

/// [value] as PDF writes a number: up to two decimals, no trailing zeros.
String _number(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.contains('.')
      ? fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : fixed;
}

/// [text] as a PDF string literal, in WinAnsiEncoding, every byte outside
/// printable ASCII and every delimiter escaped, so the file stays ASCII.
String _literal(String text) {
  final out = StringBuffer('(');
  for (final code in winAnsi(text)) {
    if (code == 0x28 || code == 0x29 || code == 0x5C) {
      out
        ..write(r'\')
        ..writeCharCode(code);
    } else if (code < 0x20 || code > 0x7E) {
      out.write('\\${code.toRadixString(8).padLeft(3, '0')}');
    } else {
      out.writeCharCode(code);
    }
  }
  out.write(')');
  return out.toString();
}

/// [text] as a PDF text string, for the document's own information rather
/// than a page: UTF-16BE behind its byte order mark, in hex, so any character
/// survives. A page's text is set in the font's encoding instead, which these
/// strings are not read in.
String _textString(String text) {
  final out = StringBuffer('<FEFF');
  for (final unit in text.codeUnits) {
    out.write(unit.toRadixString(16).padLeft(4, '0').toUpperCase());
  }
  out.write('>');
  return out.toString();
}

/// [utc] as a PDF date's digits: YYYYMMDDHHmmSS.
String _timestamp(DateTime utc) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
      '${two(utc.day)}${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
}

/// Helvetica's advance widths, in thousandths of an em, for WinAnsi codes
/// 32 to 255. Zero where WinAnsi defines no character.
const List<int> _helvetica = <int>[
  278,
  278,
  355,
  556,
  556,
  889,
  667,
  191,
  333,
  333,
  389,
  584,
  278,
  333,
  278,
  278,
  556,
  556,
  556,
  556,
  556,
  556,
  556,
  556,
  556,
  556,
  278,
  278,
  584,
  584,
  584,
  556,
  1015,
  667,
  667,
  722,
  722,
  667,
  611,
  778,
  722,
  278,
  500,
  667,
  556,
  833,
  722,
  778,
  667,
  778,
  722,
  667,
  611,
  722,
  667,
  944,
  667,
  667,
  611,
  278,
  278,
  278,
  469,
  556,
  333,
  556,
  556,
  500,
  556,
  556,
  278,
  556,
  556,
  222,
  222,
  500,
  222,
  833,
  556,
  556,
  556,
  556,
  333,
  500,
  278,
  556,
  500,
  722,
  500,
  500,
  500,
  334,
  260,
  334,
  584,
  350,
  556,
  0,
  222,
  556,
  333,
  1000,
  556,
  556,
  333,
  1000,
  667,
  333,
  1000,
  0,
  611,
  0,
  0,
  222,
  222,
  333,
  333,
  350,
  556,
  1000,
  333,
  1000,
  500,
  333,
  944,
  0,
  500,
  667,
  278,
  333,
  556,
  556,
  556,
  556,
  260,
  556,
  333,
  737,
  370,
  556,
  584,
  333,
  737,
  333,
  400,
  584,
  333,
  333,
  333,
  556,
  537,
  278,
  333,
  333,
  365,
  556,
  834,
  834,
  834,
  611,
  667,
  667,
  667,
  667,
  667,
  667,
  1000,
  722,
  667,
  667,
  667,
  667,
  278,
  278,
  278,
  278,
  722,
  722,
  778,
  778,
  778,
  778,
  778,
  584,
  778,
  722,
  722,
  722,
  722,
  667,
  667,
  611,
  556,
  556,
  556,
  556,
  556,
  556,
  889,
  500,
  556,
  556,
  556,
  556,
  278,
  278,
  278,
  278,
  556,
  556,
  556,
  556,
  556,
  556,
  556,
  584,
  611,
  556,
  556,
  556,
  556,
  500,
  556,
  500,
];

/// Helvetica-Bold's advance widths, in thousandths of an em, for WinAnsi codes
/// 32 to 255. Zero where WinAnsi defines no character.
const List<int> _helveticaBold = <int>[
  278,
  333,
  474,
  556,
  556,
  889,
  722,
  238,
  333,
  333,
  389,
  584,
  278,
  333,
  278,
  278,
  556,
  556,
  556,
  556,
  556,
  556,
  556,
  556,
  556,
  556,
  333,
  333,
  584,
  584,
  584,
  611,
  975,
  722,
  722,
  722,
  722,
  667,
  611,
  778,
  722,
  278,
  556,
  722,
  611,
  833,
  722,
  778,
  667,
  778,
  722,
  667,
  611,
  722,
  667,
  944,
  667,
  667,
  611,
  333,
  278,
  333,
  584,
  556,
  333,
  556,
  611,
  556,
  611,
  556,
  333,
  611,
  611,
  278,
  278,
  556,
  278,
  889,
  611,
  611,
  611,
  611,
  389,
  556,
  333,
  611,
  556,
  778,
  556,
  556,
  500,
  389,
  280,
  389,
  584,
  350,
  556,
  0,
  278,
  556,
  500,
  1000,
  556,
  556,
  333,
  1000,
  667,
  333,
  1000,
  0,
  611,
  0,
  0,
  278,
  278,
  500,
  500,
  350,
  556,
  1000,
  333,
  1000,
  556,
  333,
  944,
  0,
  500,
  667,
  278,
  333,
  556,
  556,
  556,
  556,
  280,
  556,
  333,
  737,
  370,
  556,
  584,
  333,
  737,
  333,
  400,
  584,
  333,
  333,
  333,
  611,
  556,
  278,
  333,
  333,
  365,
  556,
  834,
  834,
  834,
  611,
  722,
  722,
  722,
  722,
  722,
  722,
  1000,
  722,
  667,
  667,
  667,
  667,
  278,
  278,
  278,
  278,
  722,
  722,
  778,
  778,
  778,
  778,
  778,
  584,
  778,
  722,
  722,
  722,
  722,
  667,
  667,
  611,
  556,
  556,
  556,
  556,
  556,
  556,
  889,
  556,
  556,
  556,
  556,
  556,
  278,
  278,
  278,
  278,
  611,
  611,
  611,
  611,
  611,
  611,
  611,
  584,
  611,
  611,
  611,
  611,
  611,
  556,
  611,
  556,
];
