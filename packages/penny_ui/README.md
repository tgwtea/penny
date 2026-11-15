# penny_ui

Penny's design system in Flutter (ADR 016, ADR 020): tokens, theme and components. Apps build every screen from these; the rules behind them are in `DESIGN.md` and `docs/design/`.

```dart
import 'package:penny_ui/penny_ui.dart';

MaterialApp(theme: PennyTheme.light(), darkTheme: PennyTheme.dark());

final c = PennyColors.of(context);
Text('Today', style: PennyText.heading.copyWith(color: c.text));
const SizedBox(height: PennySpace.s4);
PennyButton(label: 'Add lesson', icon: PennyIcons.add, onPressed: add);
```

## What is here

| Path | Contents |
| --- | --- |
| `lib/src/tokens.g.dart` | Generated from `docs/design/tokens.json` by `task gen:tokens`: `PennyColors` and `PennyShadows` (theme extensions, light and dark), `PennyText`, `PennySpace`, `PennyRadius`, `PennySize`. Never edit by hand |
| `lib/src/foundation/` | `PennyTheme`, `PennyIcons` and `PennyIconSize`, `PennyMotion`, `PennyLayout`, `PennyFormat`, and `PennyPressable`: hover and pressed overlays, the copper focus ring and the 48 px hit area every control shares |
| `lib/src/components/` | One widget per component guideline in `docs/design/components/` |
| `lib/testing.dart` | For tests in any package: `loadPennyFonts`, `pennyTestApp`, `pennyGoldens` |
| `fonts/` | IBM Plex Sans 400, 400 italic, 600 (OFL) and Phosphor Regular and Fill (MIT, ADR 021). Bundled; nothing is fetched at run time |
| `widgetbook/` | The catalogue: every component in each state, both themes, phone and laptop, up to 200% text. `task ui:catalogue` |

## Changing the system

- **A token value:** change `docs/design/tokens.json` (copied from the design system), run `task gen:tokens`. `test/foundation/contrast_test.dart` fails if a text or control pairing drops below WCAG AA in either theme.
- **An icon:** add it to `PennyIcons` with its Phosphor code point (instructions in `icons.dart`).
- **A component or state:** build it here, add a Widgetbook use case and a golden, and update its guideline in `docs/design/components/`.

## Golden images

`test/goldens_test.dart` renders every component in light and dark. Text rasterises slightly differently per operating system, so goldens are rendered and compared on Linux only: CI runs them directly; elsewhere `task test:goldens` compares and `task test:goldens:update` re-renders them in Docker. Review changed PNGs in the pull request like code.
