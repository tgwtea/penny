# DemoPersonaSwitcher

Demo builds only (`PENNY_BACKEND=demo`): switches the signed-in persona between the studio owner, one teacher and a solo tutor. Flutter: `DemoPersonaSwitcher`, living in `lib/demo/` and never imported by feature code.

- It must look unmistakably like a demo control: dashed `warning` border on `warning-subtle`, a flask icon and the words "Demo data". It must never look like part of the product.
- Laptop: pinned at the bottom of the Sidebar. Phone: a floating chip in the top bar that opens a sheet.
- Deleting `lib/demo/` removes it with no other change.
