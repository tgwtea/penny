import 'package:penny_checks/checks.dart';
import 'package:test/test.dart';

List<String> boundaries(String libPath, String source) => checkBoundaries(
  libPath,
  source,
  packageName: 'penny',
).map((v) => v.message).toList();

List<String> tokens(String source) => checkDesignTokens(
  'features/x/presentation/x.dart',
  source,
).map((v) => v.message).toList();

void main() {
  group('layers', () {
    test('are read from the path', () {
      expect(layerOf('main.dart'), Layer.main);
      expect(layerOf('app/router.dart'), Layer.app);
      expect(layerOf('data/api_failures.dart'), Layer.data);
      expect(
        layerOf('features/auth/presentation/sign_in_screen.dart'),
        Layer.presentation,
      );
      expect(layerOf('features/auth/domain/session.dart'), Layer.domain);
      expect(layerOf('demo/demo_backend.dart'), Layer.demo);
    });
  });

  group('boundaries', () {
    test('presentation may not import data, even through a package URI', () {
      expect(
        boundaries(
          'features/team/presentation/team_screen.dart',
          "import '../data/http_team_repository.dart';",
        ),
        [contains('presentation may not import data')],
      );
      expect(
        boundaries(
          'features/team/presentation/team_screen.dart',
          "import 'package:penny/features/team/data/http_team_repository.dart';",
        ),
        [contains('presentation may not import data')],
      );
    });

    test('presentation may import application, domain and core', () {
      expect(
        boundaries('features/team/presentation/team_screen.dart', '''
import 'package:flutter/material.dart';
import 'package:penny_ui/penny_ui.dart';
import '../application/team_controller.dart';
import '../domain/member.dart';
import '../../../core/capability.dart';
'''),
        isEmpty,
      );
    });

    test('only data/ may import the generated client or raw HTTP', () {
      expect(
        boundaries(
          'features/team/application/team_controller.dart',
          "import 'package:penny_api/api.dart';",
        ),
        [contains('only data/ may import package:penny_api')],
      );
      expect(
        boundaries(
          'features/team/data/http_team_repository.dart',
          "import 'package:penny_api/api.dart';",
        ),
        isEmpty,
      );
      expect(
        boundaries(
          'data/api_failures.dart',
          "import 'package:http/http.dart';",
        ),
        isEmpty,
      );
    });

    test('only the composition root may import demo/', () {
      expect(
        boundaries(
          'features/team/presentation/team_screen.dart',
          "import '../../../demo/demo_personas.dart';",
        ),
        [contains('only app/backend_overrides.dart may import lib/demo/')],
      );
      expect(
        boundaries('app/router.dart', "import '../demo/demo_backend.dart';"),
        [contains('only app/backend_overrides.dart')],
      );
      expect(
        boundaries(
          'app/backend_overrides.dart',
          "import '../demo/demo_backend.dart';",
        ),
        isEmpty,
      );
    });

    test('domain stays plain Dart', () {
      expect(
        boundaries(
          'features/team/domain/member.dart',
          "import 'package:flutter/material.dart';",
        ),
        [contains('domain/ is plain Dart')],
      );
      expect(
        boundaries(
          'features/team/domain/member.dart',
          "import 'package:flutter/foundation.dart';",
        ),
        isEmpty,
      );
      expect(
        boundaries(
          'features/team/domain/member.dart',
          "import '../application/team_controller.dart';",
        ),
        [contains('domain may not import application')],
      );
    });

    test('core depends on nothing in the app', () {
      expect(
        boundaries(
          'core/env.dart',
          "import '../features/auth/domain/session.dart';",
        ),
        [contains('core may not import domain')],
      );
    });
  });

  group('design tokens', () {
    test('raw colours are flagged', () {
      expect(tokens('final a = Color(0xFF112233);'), [
        contains('raw colour Color'),
      ]);
      expect(tokens('final a = const Color(0xFF112233);'), [
        contains('raw colour Color'),
      ]);
      expect(tokens('final a = Color.fromARGB(1, 2, 3, 4);'), [
        contains('raw colour Color.fromARGB'),
      ]);
      expect(tokens('final a = Colors.red;'), [
        contains('raw colour Colors.red'),
      ]);
      expect(tokens('final a = Colors.transparent;'), isEmpty);
    });

    test(
      'literal spacing, sizes and radii are flagged; tokens and zero are not',
      () {
        expect(tokens('final a = EdgeInsets.all(16);'), [
          contains('literal 16 in EdgeInsets.all'),
        ]);
        expect(
          tokens('final a = const EdgeInsets.symmetric(horizontal: 12);'),
          [contains('literal 12')],
        );
        expect(tokens('final a = SizedBox(height: 8);'), [
          contains('literal 8 in SizedBox'),
        ]);
        expect(tokens('final a = BorderRadius.circular(6);'), [
          contains('literal 6 in BorderRadius.circular'),
        ]);
        expect(tokens('final a = EdgeInsets.all(PennySpace.s4);'), isEmpty);
        expect(tokens('final a = SizedBox(height: 0);'), isEmpty);
      },
    );

    test('font sizes and new text styles are flagged', () {
      expect(tokens('final a = PennyText.body.copyWith(fontSize: 18);'), [
        contains('literal fontSize'),
      ]);
      expect(tokens('final a = TextStyle(color: c);'), [
        contains('new TextStyle'),
      ]);
    });

    test('an annotated line is exempt', () {
      expect(
        tokens(
          'final a = EdgeInsets.all(3); // penny-checks: allow matches platform inset',
        ),
        isEmpty,
      );
    });
  });
}
