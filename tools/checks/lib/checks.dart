/// Rules for the Flutter client that the Dart analyzer cannot express.
///
/// - **Boundaries** (AGENTS.md, docs/architecture.md "Client"): which layer
///   may import which, that only `data/` imports the generated API client,
///   and that `demo/` is reached only from the composition root.
/// - **Design tokens** (DESIGN.md, ADR 016): no raw colours, literal
///   paddings, sizes, radii or font sizes in app code; they come from
///   penny_ui.
///
/// A line ending in `// penny-checks: allow <reason>` is exempt from the
/// design-token rules. Use it rarely, and say why.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;

/// One broken rule.
class Violation {
  Violation(this.file, this.line, this.rule, this.message);

  /// Path relative to the checked app's root.
  final String file;

  /// 1-based line number.
  final int line;

  /// Short rule name: `boundary` or `design-token`.
  final String rule;

  /// What is wrong and what to do instead.
  final String message;

  @override
  String toString() => '$file:$line: [$rule] $message';
}

/// The layer a file belongs to.
enum Layer {
  main,
  app,
  core,
  data,
  demo,
  presentation,
  application,
  domain,
  other,
}

/// Classifies a path relative to the app's `lib/` folder.
Layer layerOf(String libPath) {
  final parts = p.posix.split(libPath);
  if (parts.length == 1) {
    return parts.first == 'main.dart' ? Layer.main : Layer.other;
  }
  switch (parts.first) {
    case 'app':
      return Layer.app;
    case 'core':
      return Layer.core;
    case 'data':
      return Layer.data;
    case 'demo':
      return Layer.demo;
    case 'features':
      if (parts.length < 4) return Layer.other;
      return switch (parts[2]) {
        'presentation' => Layer.presentation,
        'application' => Layer.application,
        'domain' => Layer.domain,
        'data' => Layer.data,
        _ => Layer.other,
      };
  }
  return Layer.other;
}

/// Which app layers each layer may import. `main` and `app` are the
/// composition root and may import anything except `demo/`, which only
/// app/backend_overrides.dart may import.
const Map<Layer, Set<Layer>> allowedImports = {
  Layer.presentation: {
    Layer.presentation,
    Layer.application,
    Layer.domain,
    Layer.core,
  },
  Layer.application: {Layer.application, Layer.domain, Layer.core},
  Layer.domain: {Layer.domain, Layer.core},
  Layer.data: {Layer.data, Layer.domain, Layer.core},
  Layer.core: {Layer.core},
  Layer.demo: {
    Layer.demo,
    Layer.presentation,
    Layer.application,
    Layer.domain,
    Layer.core,
  },
};

/// The one file allowed to import `lib/demo/`.
const compositionRoot = 'app/backend_overrides.dart';

/// Generated API types: only `data/` may import them (AGENTS.md).
const dataOnlyPackages = {'penny_api'};

/// Raw HTTP: `data/` and the composition root (`main.dart`, `app/`), which
/// builds the shared client, may import it.
const transportPackages = {'http'};

/// Checks every Dart file under `<appRoot>/lib`.
List<Violation> checkApp(String appRoot, {required String packageName}) {
  final lib = Directory(p.join(appRoot, 'lib'));
  final violations = <Violation>[];
  final files =
      lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final libPath = p.posix.joinAll(
      p.split(p.relative(file.path, from: lib.path)),
    );
    final source = file.readAsStringSync();
    violations
      ..addAll(checkBoundaries(libPath, source, packageName: packageName))
      ..addAll(checkDesignTokens(libPath, source));
  }
  return violations;
}

/// Checks one file's imports and exports against the layer rules.
List<Violation> checkBoundaries(
  String libPath,
  String source, {
  required String packageName,
}) {
  final result = parseString(
    content: source,
    path: libPath,
    throwIfDiagnostics: false,
  );
  final lines = result.lineInfo;
  final from = layerOf(libPath);
  final violations = <Violation>[];

  void fail(AstNode node, String message) => violations.add(
    Violation(
      'lib/$libPath',
      lines.getLocation(node.offset).lineNumber,
      'boundary',
      message,
    ),
  );

  for (final directive
      in result.unit.directives.whereType<NamespaceDirective>()) {
    final uri = directive.uri.stringValue;
    if (uri == null || uri.startsWith('dart:')) continue;

    String? target;
    if (uri.startsWith('package:')) {
      final package = uri.substring('package:'.length).split('/').first;
      if (package == packageName) {
        target = uri.substring('package:$packageName/'.length);
      } else {
        if (dataOnlyPackages.contains(package) &&
            from != Layer.data &&
            !_isCompositionRoot(libPath, from)) {
          fail(
            directive,
            'only data/ may import package:$package; depend on a domain interface instead',
          );
        }
        if (from == Layer.domain && _isFrameworkImport(uri)) {
          fail(directive, 'domain/ is plain Dart: do not import $uri');
        }
        continue;
      }
    } else {
      target = p.posix.normalize(p.posix.join(p.posix.dirname(libPath), uri));
    }

    final to = layerOf(target);
    if (to == Layer.demo && from != Layer.demo && libPath != compositionRoot) {
      fail(
        directive,
        'only $compositionRoot may import lib/demo/; deleting demo/ must need no other change',
      );
      continue;
    }
    final allowed = allowedImports[from];
    if (allowed != null && !allowed.contains(to)) {
      fail(directive, '${from.name} may not import ${to.name} ($target)');
    }
  }
  return violations;
}

bool _isCompositionRoot(String libPath, Layer layer) =>
    layer == Layer.main || libPath == compositionRoot;

bool _isFrameworkImport(String uri) =>
    (uri.startsWith('package:flutter/') &&
        uri != 'package:flutter/foundation.dart') ||
    uri.startsWith('package:flutter_riverpod/') ||
    uri.startsWith('package:riverpod/') ||
    uri.startsWith('package:go_router/') ||
    uri.startsWith('package:penny_ui/');

/// Checks one file for raw colours and literal dimensions.
List<Violation> checkDesignTokens(String libPath, String source) {
  final result = parseString(
    content: source,
    path: libPath,
    throwIfDiagnostics: false,
  );
  final visitor = _TokenVisitor(
    'lib/$libPath',
    result.lineInfo,
    source.split('\n'),
  );
  result.unit.accept(visitor);
  return visitor.violations;
}

/// Constructors whose numeric arguments are spacing, size or radius.
const _dimensionTypes = {
  'EdgeInsets',
  'EdgeInsetsDirectional',
  'SizedBox',
  'BorderRadius',
  'Radius',
  'Gap',
};

/// Named arguments that must come from tokens wherever they appear.
const _tokenArguments = {
  'fontSize',
  'letterSpacing',
  'fontFamily',
  'borderRadius',
  'elevation',
};

class _TokenVisitor extends RecursiveAstVisitor<void> {
  _TokenVisitor(this.file, this.lines, this.sourceLines);

  final String file;
  final LineInfo lines;
  final List<String> sourceLines;
  final violations = <Violation>[];

  void _fail(AstNode node, String message) {
    final line = lines.getLocation(node.offset).lineNumber;
    if (sourceLines[line - 1].contains('// penny-checks: allow')) return;
    violations.add(Violation(file, line, 'design-token', message));
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // Unresolved, `const EdgeInsets.all(8)` can parse as the type
    // `EdgeInsets.all` with no constructor name; split it back.
    var type = node.constructorName.type.toSource();
    var constructor = node.constructorName.name?.name;
    final dot = type.indexOf('.');
    if (constructor == null && dot > 0) {
      constructor = type.substring(dot + 1);
      type = type.substring(0, dot);
    }
    _checkConstruction(node, type, constructor, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Without type information `EdgeInsets.all(8)` parses as a method call on
    // `EdgeInsets`, and `Color(0xFF...)` as a call to a function `Color`.
    final target = node.target;
    if (target == null) {
      _checkConstruction(node, node.methodName.name, null, node.argumentList);
    } else if (target is SimpleIdentifier) {
      _checkConstruction(
        node,
        target.name,
        node.methodName.name,
        node.argumentList,
      );
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == 'Colors' && node.identifier.name != 'transparent') {
      _fail(node, 'raw colour ${node.toSource()}; use PennyColors.of(context)');
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitArgumentList(ArgumentList node) {
    for (final arg in node.arguments) {
      if (arg is NamedArgument &&
          _tokenArguments.contains(arg.name.lexeme) &&
          _isLiteral(arg.argumentExpression)) {
        _fail(
          arg,
          'literal ${arg.name.lexeme}; use a PennyText style or a penny_ui token',
        );
      }
    }
    super.visitArgumentList(node);
  }

  void _checkConstruction(
    AstNode node,
    String type,
    String? constructor,
    ArgumentList args,
  ) {
    final name = constructor == null ? type : '$type.$constructor';
    if (type == 'Color') {
      _fail(node, 'raw colour $name(...); use PennyColors.of(context)');
      return;
    }
    if (type == 'TextStyle') {
      _fail(
        node,
        'new TextStyle; start from a PennyText style and copyWith a token colour',
      );
      return;
    }
    if (!_dimensionTypes.contains(type)) return;
    for (final arg in args.arguments) {
      final value = arg.argumentExpression;
      if (_isLiteral(value)) {
        _fail(
          arg,
          'literal ${value.toSource()} in $name; use PennySpace, PennySize or PennyRadius',
        );
      }
    }
  }

  /// A non-zero number written in place: `16`, `-4.0`.
  static bool _isLiteral(Expression e) {
    if (e is PrefixExpression && e.operator.lexeme == '-') {
      return _isLiteral(e.operand);
    }
    if (e is IntegerLiteral) return e.value != 0;
    if (e is DoubleLiteral) return e.value != 0;
    if (e is SimpleStringLiteral) return true; // fontFamily: 'Arial'
    return false;
  }
}
