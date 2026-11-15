# ADR 021: Bundle the Phosphor icon fonts in penny_ui

- **Status:** Accepted. Supersedes the `phosphor_flutter` package named in ADR 020; the rest of ADR 020 stands
- **Date:** 2026-11-15

## Context

ADR 020 chose Phosphor Icons, Regular weight with Fill for the active navigation item, through the `phosphor_flutter` package. Its last release (2.1.0, May 2024) no longer compiles: it extends `IconData`, which current Flutter makes a `final` class. The pub.dev forks that fix this are recent and have few users.

penny_ui already exposes a curated `PennyIcons` set rather than the whole icon family, so feature code never touches the icon package.

## Decision

Bundle the official Phosphor 2.1 Regular and Fill fonts (MIT licence) from the `@phosphor-icons/web` release in `packages/penny_ui/fonts/`, and define each icon in `PennyIcons` as a `const IconData` with its code point. No icon package dependency.

## Consequences

Same icons, same weights, one dependency fewer, and Flutter's icon tree shaking keeps working because every icon is a const `IconData`. Adding an icon means looking up its code point in the release's `style.css`. Upgrading Phosphor means replacing two font files and checking the code points still match. Revisit if a maintained, official Flutter package returns.
