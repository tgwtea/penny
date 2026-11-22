// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:penny_ui/penny_ui.dart';

/// The frame of a page opened from a link in an email, by someone who does
/// not sign in: a parent paying, or stopping reminders. One narrow column on
/// `canvas`, the same at every width, with nothing to navigate to.
class PublicPage extends StatelessWidget {
  /// Creates the frame around [children].
  const PublicPage({super.key, required this.children});

  /// The page's content, top to bottom.
  final List<Widget> children;

  static const double _width = 480;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: PennySpace.s4,
            vertical: PennySpace.s6,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _width),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A public page's heading: the team that sent the link, as an avatar and
/// its name, with what the page is for under it.
class PublicPageHeader extends StatelessWidget {
  /// Creates the header for [teamName].
  const PublicPageHeader({super.key, required this.teamName, this.subtitle});

  /// The team that sent the link.
  final String teamName;

  /// What the page is for: "Payment request for Arjun's lessons".
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return Row(
      children: [
        PennyAvatar(name: teamName),
        const SizedBox(width: PennySpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  teamName,
                  style: PennyText.bodyStrong.copyWith(color: c.text),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: PennyText.small.copyWith(color: c.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
