// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:penny_ui/penny_ui.dart';

/// The frame of every page before someone is in: the brand mark (one of the
/// few places for pixel art), a heading and a narrow column of content.
class AuthLayout extends StatelessWidget {
  /// Creates the layout.
  const AuthLayout({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  /// The page's one heading.
  final String title;

  /// A sentence under it.
  final String? subtitle;

  /// The form or message.
  final List<Widget> children;

  static const double _formWidth = 400;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PennySpace.s6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _formWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: PennyPixelArt(
                      image: AssetImage('assets/brand/app-icon-32.png'),
                      pixels: 32,
                      scale: 2,
                      semanticLabel: 'Penny',
                    ),
                  ),
                  const SizedBox(height: PennySpace.s4),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: PennyText.title.copyWith(color: c.text),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: PennySpace.s1),
                    Text(
                      subtitle!,
                      style: PennyText.body.copyWith(color: c.textSecondary),
                    ),
                  ],
                  const SizedBox(height: PennySpace.s8),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A gap between form fields.
const formGap = SizedBox(height: PennySpace.s4);
