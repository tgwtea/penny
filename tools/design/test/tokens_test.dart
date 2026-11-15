import 'package:penny_design_tools/tokens.dart';
import 'package:test/test.dart';

const _tokens = '''
{
  "color": {
    "tokens": [
      {"name": "canvas", "value": {"light": "#f6f7f9", "dark": "#0F141A"}, "usage": "Page."},
      {"name": "focus-ring", "value": {"light": "{canvas}", "dark": "{canvas}"}, "usage": "Focus."},
      {"name": "scrim", "value": {"light": "rgba(16, 24, 40, 0.40)", "dark": "rgba(0, 0, 0, 0.60)"}, "usage": "Backdrop."}
    ]
  },
  "shadow": {
    "note": "Only floating things.",
    "tokens": [
      {"name": "shadow-float", "value": {
        "light": "0 4px 12px rgba(16, 24, 40, 0.10), 0 0 0 1px rgba(16, 24, 40, 0.06)",
        "dark": "0 4px 12px rgba(0, 0, 0, 0.45)"
      }, "usage": "Menus."}
    ]
  },
  "type": {
    "families": {"sans": "\\"IBM Plex Sans\\", system-ui, sans-serif"},
    "groups": [
      {"name": "Text", "styles": [
        {"name": "display", "fontSize": "28px", "lineHeight": "34px", "fontWeight": 600,
         "letterSpacing": "-0.01em", "sample": "Thursday", "usage": "Titles."}
      ]},
      {"name": "Numerals", "styles": [
        {"name": "time-lg", "fontSize": "20px", "lineHeight": "28px", "fontWeight": 600,
         "sample": "16:30", "usage": "Times."}
      ]}
    ]
  },
  "spacing": {"tokens": [{"name": "space-4", "value": "16px", "usage": "Margins."}]},
  "radius": {"tokens": [{"name": "radius-md", "value": "8px", "usage": "Controls."}]},
  "size": {"tokens": [{"name": "control-height-sm", "value": "36px", "usage": "Compact."}]}
}
''';

void main() {
  final source = generateTokens(_tokens);

  test('colours become camelCase fields with both themes', () {
    expect(source, contains('final Color canvas;'));
    expect(source, contains('canvas: Color(0xFFF6F7F9),'));
    expect(source, contains('canvas: Color(0xFF0F141A),'));
  });

  test('aliases resolve to the referenced value', () {
    expect(source, contains('focusRing: Color(0xFFF6F7F9),'));
  });

  test('rgba values keep their alpha', () {
    // 0.40 * 255 = 102 = 0x66
    expect(source, contains('scrim: Color(0x66101828),'));
  });

  test('CSS box-shadow lists become BoxShadow lists', () {
    expect(
      source,
      contains(
        'BoxShadow(offset: Offset(0, 4), blurRadius: 12, spreadRadius: 0, '
        'color: Color(0x1A101828))',
      ),
    );
    expect(
      source,
      contains(
        'BoxShadow(offset: Offset(0, 0), blurRadius: 0, spreadRadius: 1',
      ),
    );
  });

  test('text styles convert line height and em letter spacing', () {
    expect(source, contains('static const display = TextStyle('));
    expect(source, contains('height: 1.2143,'));
    expect(source, contains('letterSpacing: -0.28,'));
    expect(source, contains("static const fontFamily = 'IBM Plex Sans';"));
  });

  test('numeral styles use tabular figures', () {
    final timeLg = source.substring(source.indexOf('static const timeLg'));
    expect(
      timeLg.substring(0, timeLg.indexOf(');')),
      contains('FontFeature.tabularFigures()'),
    );
  });

  test('dimensions are named after their token', () {
    expect(source, contains('static const double s4 = 16;'));
    expect(source, contains('static const double md = 8;'));
    expect(source, contains('static const double controlHeightSm = 36;'));
  });

  test('unsupported colour formats fail loudly', () {
    expect(
      () => generateTokens(_tokens.replaceFirst('#f6f7f9', 'hsl(0, 0%, 0%)')),
      throwsFormatException,
    );
  });
}
