# QrCode

A QR code, for PayNow payloads on the payment page and the payee's test code. Flutter: `PennyQrCode(data:, semanticLabel:, size:)`, in `packages/penny_ui`, encoding with the pure-Dart `qr` package and drawing with Penny's own painter.

- Always dark on light, in both themes: `text` on `surface` from the light theme. Banking apps read a light ground most reliably, so in the dark theme the code shows as a light square.
- Modules are whole pixels, so edges stay sharp, with the four-module quiet zone scanners need. The default size, 240, scans from a phone at arm's length off another screen.
- Never put anything over the code (no logo in the middle) and never crop the quiet zone.
- One image to a screen reader: give a label that says what it pays, "PayNow code for S$ 240.00". Always show the amount and the reference as text beside it, so the code is never the only way to pay.
- On a phone, the payer may be on the same device as their banking app; the payment page says to save the code to photos and choose it from the app.
