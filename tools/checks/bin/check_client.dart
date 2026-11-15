/// Checks the Flutter client's layering and design-token rules.
///
///     dart run bin/check_client.dart [app-root] [package-name]
///
/// Defaults to ../../apps/client and package `penny`. Exits 1 and lists every
/// violation as `file:line: [rule] message` when any rule is broken.
library;

import 'dart:io';

import 'package:penny_checks/checks.dart';

void main(List<String> args) {
  final root = args.isNotEmpty ? args[0] : '../../apps/client';
  final package = args.length > 1 ? args[1] : 'penny';
  final violations = checkApp(root, packageName: package);
  for (final v in violations) {
    stderr.writeln(v);
  }
  if (violations.isNotEmpty) {
    stderr.writeln(
      '\n${violations.length} violation(s). See tools/checks/README.md.',
    );
    exit(1);
  }
  stdout.writeln('client boundaries and design tokens: ok');
}
