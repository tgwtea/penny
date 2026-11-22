# ADR 023: Stay on the SDK's Material library until the catalogue can move

- **Status:** Accepted
- **Date:** 2026-11-22

## Context

Flutter 3.47 deprecated `package:flutter/material.dart` in favour of the `material_ui` package on pub.dev. Flutter 3.50.0, pinned in `.mise.toml`, keeps both: two separate copies of every Material class. A `ThemeData` from one is not a `ThemeData` from the other, and `Theme.of` from one does not see a theme provided by the other.

`flutter analyze` fails on the deprecation, so `task lint` failed on a clean checkout.

Penny's dependencies are mid-migration:

| Dependency | Imports |
| --- | --- |
| go_router 18.1 | `material_ui` |
| Widgetbook 3.25 | `flutter/material.dart`; `MaterialThemeAddon` takes the SDK's `ThemeData` |
| flutter_test (SDK) | `flutter/material.dart`; `find.byTooltip` matches the SDK's `Tooltip` |

Moving penny_ui to `material_ui` now would break the Widgetbook catalogue (ADR 016), which cannot accept the theme, and every test that finds a control by its tooltip.

## Decision

Keep importing `package:flutter/material.dart` in penny_ui, the catalogue and the client. Each such import carries one line above it:

```dart
// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
```

The ignore is per import, not a project-wide setting, so every other deprecation still fails the build.

## Consequences

New files that import Material need the same line. Routes built by go_router's default `builder:` render a `material_ui` page inside the SDK theme; Penny's top-level routes use `NoTransitionPage`, and detail routes set their own page, so nothing visible depends on the page's theme.

Revisit when Widgetbook accepts a `material_ui` theme and flutter_test's finders follow. The migration is then mechanical: change the imports, add `material_ui` to each pubspec, delete the ignore lines.
