## What and why

<!-- One or two sentences. Link the issue or the build-plan task. -->

## How I verified it

<!-- Commands run and their results. Screenshots for UI changes at phone and laptop widths. -->

- [ ] `task lint`
- [ ] `task test`

## Checklist

- [ ] Title follows Conventional Commits with a scope, e.g. `feat(api): ...`
- [ ] One concern only; any migration ships with the code that needs it
- [ ] Contract changed? Ran `task gen` and committed the output
- [ ] New dependency? Named here with the reason
- [ ] Architectural decision? Added or updated an ADR in `docs/adr/`
