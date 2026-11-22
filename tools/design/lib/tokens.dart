/// Reads Penny's design tokens and renders them as Dart source.
///
/// The input is `docs/design/tokens.json`, copied from the design system.
/// The output is `packages/penny_ui/lib/src/tokens.g.dart`. Nothing else
/// should hold token values: feature code reads them from the theme.
library;

import 'dart:convert';

/// Generates the Dart source for [tokensJson].
String generateTokens(String tokensJson) {
  final json = jsonDecode(tokensJson) as Map<String, dynamic>;
  final out = StringBuffer()
    ..writeln('// GENERATED CODE. Do not edit by hand.')
    ..writeln('//')
    ..writeln('// Source: docs/design/tokens.json')
    ..writeln('// Generator: tools/design/bin/generate_tokens.dart')
    ..writeln('// Regenerate with `task gen:tokens`.')
    ..writeln()
    ..writeln(
      '// ignore: deprecated_member_use, '
      'see docs/adr/023-stay-on-the-sdk-material-library.md',
    )
    ..writeln("import 'package:flutter/material.dart';")
    ..writeln();

  _writeColors(out, json['color'] as Map<String, dynamic>);
  _writeShadows(out, json['shadow'] as Map<String, dynamic>);
  _writeText(out, json['type'] as Map<String, dynamic>);
  _writeDimensions(
    out,
    className: 'PennySpace',
    doc: 'Spacing on the 4 px grid. `s4` is the `space-4` token (16 px).',
    tokens: (json['spacing'] as Map<String, dynamic>)['tokens'] as List,
    name: (token) => 's${token.substring('space-'.length)}',
  );
  _writeDimensions(
    out,
    className: 'PennyRadius',
    doc:
        'Corner radii, by hierarchy: badges, blocks, controls, panels, '
        'dialogs, avatars.',
    tokens: (json['radius'] as Map<String, dynamic>)['tokens'] as List,
    name: (token) => _camel(token.substring('radius-'.length)),
  );
  _writeDimensions(
    out,
    className: 'PennySize',
    doc: 'Fixed dimensions shared by several components.',
    tokens: (json['size'] as Map<String, dynamic>)['tokens'] as List,
    name: _camel,
  );
  return out.toString();
}

void _writeColors(StringBuffer out, Map<String, dynamic> color) {
  final tokens = (color['tokens'] as List).cast<Map<String, dynamic>>();
  final byName = {for (final t in tokens) t['name'] as String: t};

  String resolve(String name, String theme) {
    final raw =
        (byName[name]!['value'] as Map<String, dynamic>)[theme] as String;
    final alias = RegExp(r'^\{(.+)\}$').firstMatch(raw);
    return alias == null ? raw : resolve(alias.group(1)!, theme);
  }

  final fields = [for (final t in tokens) _camel(t['name'] as String)];

  out
    ..writeln(
      '/// Penny\'s colour tokens for one theme (ink and copper, ADR 020).',
    )
    ..writeln('///')
    ..writeln(
      '/// Read them with `PennyColors.of(context)`. Never write a colour',
    )
    ..writeln('/// literal outside penny_ui.')
    ..writeln('@immutable')
    ..writeln('class PennyColors extends ThemeExtension<PennyColors> {')
    ..writeln('  /// Creates a colour set. Use [light] or [dark] instead.')
    ..writeln('  const PennyColors({');
  for (final f in fields) {
    out.writeln('    required this.$f,');
  }
  out
    ..writeln('  });')
    ..writeln();

  for (final t in tokens) {
    out
      ..writeln(_doc('  ', t['usage'] as String))
      ..writeln('  final Color ${_camel(t['name'] as String)};')
      ..writeln();
  }

  for (final theme in ['light', 'dark']) {
    out
      ..writeln('  /// The $theme theme.')
      ..writeln('  static const $theme = PennyColors(');
    for (final t in tokens) {
      final name = t['name'] as String;
      out.writeln('    ${_camel(name)}: ${_color(resolve(name, theme))},');
    }
    out
      ..writeln('  );')
      ..writeln();
  }

  out
    ..writeln('  /// The colours of the nearest Penny theme.')
    ..writeln('  static PennyColors of(BuildContext context) =>')
    ..writeln('      Theme.of(context).extension<PennyColors>()!;')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  PennyColors copyWith({');
  for (final f in fields) {
    out.writeln('    Color? $f,');
  }
  out
    ..writeln('  }) {')
    ..writeln('    return PennyColors(');
  for (final f in fields) {
    out.writeln('      $f: $f ?? this.$f,');
  }
  out
    ..writeln('    );')
    ..writeln('  }')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  PennyColors lerp(PennyColors? other, double t) {')
    ..writeln('    if (other == null) return this;')
    ..writeln('    return PennyColors(');
  for (final f in fields) {
    out.writeln('      $f: Color.lerp($f, other.$f, t)!,');
  }
  out
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('}')
    ..writeln();
}

void _writeShadows(StringBuffer out, Map<String, dynamic> shadow) {
  final tokens = (shadow['tokens'] as List).cast<Map<String, dynamic>>();
  final fields = [
    for (final t in tokens)
      _camel((t['name'] as String).substring('shadow-'.length)),
  ];

  out
    ..writeln(_doc('', shadow['note'] as String))
    ..writeln('@immutable')
    ..writeln('class PennyShadows extends ThemeExtension<PennyShadows> {')
    ..writeln('  /// Creates a shadow set. Use [light] or [dark] instead.')
    ..writeln('  const PennyShadows({');
  for (final f in fields) {
    out.writeln('    required this.$f,');
  }
  out
    ..writeln('  });')
    ..writeln();
  for (var i = 0; i < tokens.length; i++) {
    out
      ..writeln(_doc('  ', tokens[i]['usage'] as String))
      ..writeln('  final List<BoxShadow> ${fields[i]};')
      ..writeln();
  }
  for (final theme in ['light', 'dark']) {
    out
      ..writeln('  /// The $theme theme.')
      ..writeln('  static const $theme = PennyShadows(');
    for (var i = 0; i < tokens.length; i++) {
      final css = (tokens[i]['value'] as Map<String, dynamic>)[theme] as String;
      out.writeln('    ${fields[i]}: ${_boxShadows(css)},');
    }
    out
      ..writeln('  );')
      ..writeln();
  }
  out
    ..writeln('  /// The shadows of the nearest Penny theme.')
    ..writeln('  static PennyShadows of(BuildContext context) =>')
    ..writeln('      Theme.of(context).extension<PennyShadows>()!;')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  PennyShadows copyWith({');
  for (final f in fields) {
    out.writeln('    List<BoxShadow>? $f,');
  }
  out
    ..writeln('  }) {')
    ..writeln('    return PennyShadows(');
  for (final f in fields) {
    out.writeln('      $f: $f ?? this.$f,');
  }
  out
    ..writeln('    );')
    ..writeln('  }')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  PennyShadows lerp(PennyShadows? other, double t) {')
    ..writeln('    if (other == null) return this;')
    ..writeln('    return PennyShadows(');
  for (final f in fields) {
    out.writeln('      $f: BoxShadow.lerpList($f, other.$f, t)!,');
  }
  out
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('}')
    ..writeln();
}

void _writeText(StringBuffer out, Map<String, dynamic> type) {
  final family = _primaryFamily(
    (type['families'] as Map<String, dynamic>)['sans'] as String,
  );
  out
    ..writeln('/// Penny\'s type scale: IBM Plex Sans at weights 400 and 600.')
    ..writeln('///')
    ..writeln('/// Styles carry no colour; text takes it from the theme or the')
    ..writeln('/// component. Times and amounts use tabular figures.')
    ..writeln('abstract final class PennyText {')
    ..writeln('  /// The font family bundled with penny_ui.')
    ..writeln("  static const fontFamily = '$family';")
    ..writeln()
    ..writeln('  /// The package that bundles [fontFamily].')
    ..writeln("  static const fontPackage = 'penny_ui';")
    ..writeln();

  for (final group in (type['groups'] as List).cast<Map<String, dynamic>>()) {
    final tabular = group['name'] == 'Numerals';
    for (final style
        in (group['styles'] as List).cast<Map<String, dynamic>>()) {
      final size = _px(style['fontSize'] as String);
      final lineHeight = _px(style['lineHeight'] as String);
      final weight = style['fontWeight'] as int;
      final spacing = style['letterSpacing'] as String?;
      out
        ..writeln(_doc('  ', '${style['usage']} Sample: "${style['sample']}".'))
        ..writeln(
          '  static const ${_camel(style['name'] as String)} = TextStyle(',
        )
        ..writeln('    fontFamily: fontFamily,')
        ..writeln('    package: fontPackage,')
        ..writeln('    fontSize: ${_num(size)},')
        ..writeln('    height: ${_num(lineHeight / size)},')
        ..writeln('    fontWeight: FontWeight.w$weight,');
      if (spacing != null) {
        out.writeln('    letterSpacing: ${_num(_em(spacing) * size)},');
      }
      if (tabular) {
        out.writeln('    fontFeatures: [FontFeature.tabularFigures()],');
      }
      out
        ..writeln('    leadingDistribution: TextLeadingDistribution.even,')
        ..writeln('  );')
        ..writeln();
    }
  }
  out
    ..writeln('}')
    ..writeln();
}

void _writeDimensions(
  StringBuffer out, {
  required String className,
  required String doc,
  required List tokens,
  required String Function(String token) name,
}) {
  out
    ..writeln(_doc('', doc))
    ..writeln('abstract final class $className {');
  for (final t in tokens.cast<Map<String, dynamic>>()) {
    out
      ..writeln(_doc('  ', '`${t['name']}`: ${t['usage']}'))
      ..writeln(
        '  static const double ${name(t['name'] as String)} = '
        '${_num(_px(t['value'] as String))};',
      )
      ..writeln();
  }
  out
    ..writeln('}')
    ..writeln();
}

/// `surface-sunken` becomes `surfaceSunken`; `control-height-sm` becomes
/// `controlHeightSm`.
String _camel(String kebab) {
  final parts = kebab.split('-');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

String _doc(String indent, String text) {
  final lines = <String>[];
  var line = '';
  for (final word in text.split(RegExp(r'\s+'))) {
    if (line.isNotEmpty && indent.length + 4 + line.length + word.length > 80) {
      lines.add(line);
      line = word;
    } else {
      line = line.isEmpty ? word : '$line $word';
    }
  }
  if (line.isNotEmpty) lines.add(line);
  return lines.map((l) => '$indent/// $l').join('\n');
}

/// Parses `#RRGGBB` or `rgba(r, g, b, a)` into a `Color(0xAARRGGBB)` literal.
String _color(String css) {
  final hex = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(css);
  if (hex != null) {
    return 'Color(0xFF${hex.group(1)!.toUpperCase()})';
  }
  final rgba = RegExp(
    r'^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)$',
  ).firstMatch(css);
  if (rgba != null) {
    final alpha = (double.parse(rgba.group(4)!) * 255).round();
    String hexOf(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    final channels = [for (var i = 1; i <= 3; i++) int.parse(rgba.group(i)!)];
    return 'Color(0x${hexOf(alpha)}${channels.map(hexOf).join()})';
  }
  throw FormatException('Unsupported colour value', css);
}

/// Parses a CSS box-shadow list such as
/// `0 4px 12px rgba(16, 24, 40, 0.10), 0 0 0 1px rgba(...)`.
String _boxShadows(String css) {
  final shadow = RegExp(
    r'(-?[\d.]+(?:px)?(?:\s+-?[\d.]+(?:px)?){1,3})\s+(rgba\([^)]*\)|#[0-9a-fA-F]{6})',
  );
  final parts = shadow.allMatches(css).map((m) {
    final lengths = m.group(1)!.trim().split(RegExp(r'\s+')).map(_px).toList();
    while (lengths.length < 4) {
      lengths.add(0);
    }
    return 'BoxShadow('
        'offset: Offset(${_num(lengths[0])}, ${_num(lengths[1])}), '
        'blurRadius: ${_num(lengths[2])}, '
        'spreadRadius: ${_num(lengths[3])}, '
        'color: ${_color(m.group(2)!)})';
  }).toList();
  if (parts.isEmpty) throw FormatException('Unsupported shadow value', css);
  return '[${parts.join(', ')}]';
}

double _px(String value) {
  final m = RegExp(r'^(-?[\d.]+)(px)?$').firstMatch(value.trim());
  if (m == null) throw FormatException('Expected a px value', value);
  return double.parse(m.group(1)!);
}

double _em(String value) {
  final m = RegExp(r'^(-?[\d.]+)em$').firstMatch(value.trim());
  if (m == null) throw FormatException('Expected an em value', value);
  return double.parse(m.group(1)!);
}

/// `"IBM Plex Sans", system-ui, ...` becomes `IBM Plex Sans`.
String _primaryFamily(String cssFamilies) =>
    cssFamilies.split(',').first.trim().replaceAll('"', '');

/// Prints whole numbers without a fraction and others to four places.
String _num(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return double.parse(v.toStringAsFixed(4)).toString();
}
