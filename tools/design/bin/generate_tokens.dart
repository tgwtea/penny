/// Writes packages/penny_ui/lib/src/tokens.g.dart from docs/design/tokens.json.
///
/// Run from the repository root with `task gen:tokens`, which also formats
/// the output. Paths can be overridden for tests:
///
///     dart run bin/generate_tokens.dart [tokens.json] [tokens.g.dart]
library;

import 'dart:io';

import 'package:penny_design_tools/tokens.dart';

void main(List<String> args) {
  final input = File(
    args.isNotEmpty ? args[0] : '../../docs/design/tokens.json',
  );
  final output = File(
    args.length > 1 ? args[1] : '../../packages/penny_ui/lib/src/tokens.g.dart',
  );
  output.writeAsStringSync(generateTokens(input.readAsStringSync()));
  stdout.writeln('wrote ${output.path}');
}
