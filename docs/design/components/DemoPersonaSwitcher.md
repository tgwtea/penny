# DemoPersonaSwitcher

Demo builds only (`PENNY_BACKEND=demo`): switches the signed-in persona between the studio owner, one teacher and a solo tutor. Flutter: `DemoPersonaSwitcher`, living in `lib/demo/` and never imported by feature code.

- It must look unmistakably like a demo control: dashed `warning` border on `warning-subtle`, a flask icon and the words "Demo data". It must never look like part of the product.
- Laptop: pinned at the bottom of the Sidebar. Phone: a floating chip in the top bar that opens a sheet.
- Deleting `lib/demo/` removes it with no other change.

**In code.** The switcher is `PersonaSwitcher` in `apps/client/lib/features/auth/presentation/`, drawn with `PennyDemoChip`. It does not live in `lib/demo/` because the shell may not import the demo (only `app/backend_overrides.dart` may). Instead it shows the personas the active `AuthRepository` offers, and only the demo repository offers any, so deleting `lib/demo/` still removes it with no other change.
