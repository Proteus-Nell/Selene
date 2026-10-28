/// List marks, drawn.
///
/// The bundled Figtree subset has the bullet and not the hollow bullet, the
/// square or the black circle that fact sheets and Medication Guides mark
/// their lists with (fonts_test.dart checks the subset against the ARB file,
/// and these come from data instead). A phone would fall back to a system
/// font for them, in another weight and size; drawn, they match the text.
///
/// Includes:
///     - ListMark: One list item's mark, beside the first line of its text.
///     - ListItem: A mark and its text, the text hanging clear of the mark.
///     - markDepth: How deep a typed mark says an item is.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How deep the typed mark [mark] says a list item is: 1 for a bullet or a
/// black circle, 2 for a hollow bullet, 3 for a square, and null for any
/// other character.
int? markDepth(String mark) => switch (mark) {
  '•' || '●' => 1,
  '◦' || '○' => 2,
  '▪' || '■' => 3,
  _ => null,
};

/// One list item's mark, the size of the text beside it: a disc, a circle
/// for an item nested in another, and a square for one nested deeper, as a
/// browser draws a nested list.
///
/// Attributes:
///     depth (int): How deep in lists the item is, from 1.
///     style (TextStyle?): The style of the item's text.
class ListMark extends StatelessWidget {
  /// Creates a mark.
  const ListMark({required this.depth, this.style, super.key});

  /// How deep in lists the item is, from 1.
  final int depth;

  /// The style of the item's text, which the mark is sized and coloured by.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = DefaultTextStyle.of(context).style.merge(style);
    final fontSize = MediaQuery.textScalerOf(
      context,
    ).scale(text.fontSize ?? 14);
    final line = fontSize * (text.height ?? 1.4);
    final size = math.max(4, fontSize * 0.36).toDouble();
    final colour = text.color ?? Theme.of(context).colorScheme.onSurface;
    final decoration = switch (depth) {
      1 => BoxDecoration(color: colour, shape: BoxShape.circle),
      2 => BoxDecoration(
        border: Border.all(color: colour, width: math.max(1, size / 5)),
        shape: BoxShape.circle,
      ),
      _ => BoxDecoration(color: colour),
    };
    // A screen reader reads the item, not its mark.
    return ExcludeSemantics(
      child: SizedBox(
        width: fontSize * 1.2,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            top: math.max(0, (line - size) / 2),
          ),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox.square(
              dimension: size,
              child: DecoratedBox(decoration: decoration),
            ),
          ),
        ),
      ),
    );
  }
}

/// A list item: its mark, and its text hanging clear of the mark, indented
/// as deep as the item is nested.
///
/// Attributes:
///     depth (int): How deep in lists the item is, from 1.
///     text (String): What it says, without its mark.
///     style (TextStyle?): The style to set it in.
class ListItem extends StatelessWidget {
  /// Creates an item.
  const ListItem({
    required this.depth,
    required this.text,
    this.style,
    super.key,
  });

  /// How deep in lists the item is, from 1.
  final int depth;

  /// What it says, without its mark.
  final String text;

  /// The style to set it in.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(start: 16.0 * (depth - 1)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListMark(depth: depth, style: style),
        Expanded(child: Text(text, style: style)),
      ],
    ),
  );
}
