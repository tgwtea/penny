// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../application/session_controller.dart';
import '../domain/auth_repository.dart';
import '../domain/session.dart';

/// On the sign-in page of a demo build: who to view the demo as (PRD R2).
class PersonaChooser extends StatelessWidget {
  /// Creates the chooser.
  const PersonaChooser({
    super.key,
    required this.personas,
    required this.onChosen,
  });

  /// The personas the build offers.
  final List<SignInPersona> personas;

  /// Signs in as one. Null while signing in.
  final ValueChanged<SignInPersona>? onChosen;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PennyDemoChip(label: 'Choose who to view Penny as'),
        const SizedBox(height: PennySpace.s3),
        for (final p in personas)
          Padding(
            padding: const EdgeInsets.only(bottom: PennySpace.s2),
            child: PennyPressable(
              onPressed: onChosen == null ? null : () => onChosen!(p),
              contentColor: c.text,
              child: Container(
                padding: const EdgeInsets.all(PennySpace.s3),
                decoration: BoxDecoration(
                  border: Border.all(color: c.borderControl),
                  borderRadius: BorderRadius.circular(PennyRadius.md),
                ),
                child: Row(
                  children: [
                    PennyAvatar(name: p.name),
                    const SizedBox(width: PennySpace.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: PennyText.bodyStrong.copyWith(color: c.text),
                          ),
                          Text(
                            p.description,
                            style: PennyText.small.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      PennyIcons.next,
                      size: PennyIconSize.standard,
                      color: c.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "Viewing as" in the shell of a demo build (DemoPersonaSwitcher
/// guideline): bottom of the sidebar on laptop, a chip in the top bar on
/// phone. Shows nothing in builds without personas.
///
/// It is generic over AuthRepository.methods rather than living in
/// `lib/demo/`, because the shell may not import the demo; only the demo
/// offers personas, so deleting `lib/demo/` still removes it.
class PersonaSwitcher extends ConsumerWidget {
  /// Creates the switcher.
  const PersonaSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authRepositoryProvider);
    final personas = auth.methods.personas;
    final session = ref.watch(sessionProvider);
    if (personas.isEmpty || session is! SignedIn) {
      return const SizedBox.shrink();
    }
    return PennyDemoChip(
      label: 'Viewing as ${session.user.displayName}',
      onPressed: () async {
        final chosen = await showModalBottomSheet<SignInPersona>(
          context: context,
          backgroundColor: PennyColors.of(context).surfaceFloat,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(PennyRadius.xl),
            ),
          ),
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(PennySpace.s4),
              child: PersonaChooser(
                personas: personas,
                onChosen: (p) => Navigator.of(context).pop(p),
              ),
            ),
          ),
        );
        if (chosen != null) await auth.signInAsPersona(chosen.id);
      },
    );
  }
}
