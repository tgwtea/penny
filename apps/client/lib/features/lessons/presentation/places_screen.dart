// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/failure.dart';
import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/back_link.dart';
import '../../shared/presentation/failure_text.dart';
import '../application/lesson_providers.dart';
import '../domain/location.dart';

/// The team's saved places (designs: "places"), for owners: in person with
/// a Singapore postal code, or online with a meeting link. Lessons keep the
/// address they were booked with, so changing a place rewrites nothing.
class PlacesScreen extends ConsumerWidget {
  /// Creates the screen.
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = PennyColors.of(context);
    final places = ref.watch(locationsProvider);

    Future<void> add() async {
      final added = await showPennySheet<Location>(
        context,
        title: 'Add a place',
        builder: (sheetContext) =>
            PlaceForm(onDone: (l) => Navigator.of(sheetContext).pop(l)),
      );
      if (added != null && context.mounted) {
        PennySnackbar.show(context, message: '${added.name} added');
      }
    }

    return PennyPage(
      title: 'Places',
      actions: [
        PennyButton(label: 'Add a place', icon: PennyIcons.add, onPressed: add),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BackLink(fallback: '/account'),
          const SizedBox(height: PennySpace.s2),
          switch (places) {
            AsyncData(:final value) =>
              value.isEmpty
                  ? PennyEmptyState(
                      title: 'No places yet',
                      body:
                          'Save the studio, a student\'s home or an online '
                          'room to pick it for lessons.',
                      action: PennyButton(
                        label: 'Add a place',
                        variant: PennyButtonVariant.secondary,
                        onPressed: add,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, p) in value.indexed) ...[
                          if (i > 0) const PennyDivider(),
                          PennyListRow(
                            leading: Icon(
                              p.kind == LocationKind.online
                                  ? PennyIcons.online
                                  : PennyIcons.location,
                              size: PennyIconSize.standard,
                              color: c.textSecondary,
                            ),
                            title: p.name,
                            subtitle: p.kind == LocationKind.online
                                ? (p.meetingUrl.isEmpty
                                      ? 'Online'
                                      : p.meetingUrl)
                                : p.addressLine,
                            trailing: [
                              PennyMenuButton(
                                tooltip: 'Actions for ${p.name}',
                                items: [
                                  PennyMenuItem(
                                    label: 'Stop offering',
                                    icon: PennyIcons.delete,
                                    destructive: true,
                                    onSelected: () async {
                                      try {
                                        await ref
                                            .read(lessonActionsProvider)
                                            .archiveLocation(p.id);
                                        if (context.mounted) {
                                          PennySnackbar.show(
                                            context,
                                            message: '${p.name} removed',
                                          );
                                        }
                                      } on Failure catch (f) {
                                        if (context.mounted) {
                                          PennySnackbar.show(
                                            context,
                                            message: failureText(f),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            AsyncError(:final error) => PennyNotice(
              tone: PennyNoticeTone.danger,
              title: 'Couldn\'t load the places.',
              body: error is Failure ? failureText(error) : null,
              action: PennyButton(
                label: 'Retry',
                icon: PennyIcons.retry,
                variant: PennyButtonVariant.quiet,
                onPressed: () => ref.invalidate(locationsProvider),
              ),
            ),
            _ => const Column(
              children: [PennySkeletonRow(), PennySkeletonRow()],
            ),
          },
        ],
      ),
    );
  }
}

/// Saves a place.
class PlaceForm extends ConsumerStatefulWidget {
  /// Creates the form.
  const PlaceForm({super.key, required this.onDone});

  /// Called with the saved place.
  final ValueChanged<Location> onDone;

  @override
  ConsumerState<PlaceForm> createState() => _PlaceFormState();
}

class _PlaceFormState extends ConsumerState<PlaceForm> with AsyncAction {
  LocationKind _kind = LocationKind.inPerson;
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _unit = TextEditingController();
  final _postal = TextEditingController();
  final _link = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    for (final c in [_name, _address, _unit, _postal, _link]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final draft = LocationDraft(
      name: _name.text,
      kind: _kind,
      addressLine1: _address.text,
      addressLine2: _unit.text,
      postalCode: _postal.text,
      meetingUrl: _link.text,
    );
    setState(() => _problem = locationProblem(draft));
    if (_problem != null) return;
    Location? saved;
    final ok = await run(() async {
      saved = await ref.read(lessonActionsProvider).createLocation(draft);
    });
    if (ok && saved != null) widget.onDone(saved!);
  }

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    final inPerson = _kind == LocationKind.inPerson;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) ...[
          PennyNotice(
            tone: PennyNoticeTone.danger,
            title: failureText(failure),
          ),
          const SizedBox(height: PennySpace.s4),
        ],
        PennyOptionRow(
          title: 'In person',
          body: 'A studio, a school or a student\'s home.',
          selected: inPerson,
          onSelected: () => setState(() => _kind = LocationKind.inPerson),
        ),
        const SizedBox(height: PennySpace.s2),
        PennyOptionRow(
          title: 'Online',
          body: 'A video call.',
          selected: !inPerson,
          onSelected: () => setState(() => _kind = LocationKind.online),
        ),
        const SizedBox(height: PennySpace.s4),
        PennyTextField(
          label: 'Name',
          placeholder: inPerson ? 'Studio room 2' : 'Online',
          controller: _name,
          error: _problem == 'Enter a name for the place.' ? _problem : null,
        ),
        const SizedBox(height: PennySpace.s4),
        if (inPerson) ...[
          PennyTextField(label: 'Address', controller: _address),
          const SizedBox(height: PennySpace.s4),
          PennyTextField(
            label: 'Unit or building',
            placeholder: '#03-12',
            controller: _unit,
          ),
          const SizedBox(height: PennySpace.s4),
          PennyTextField(
            label: 'Postal code',
            hint: 'Six digits.',
            controller: _postal,
            keyboardType: TextInputType.number,
            tabularFigures: true,
            error: _problem == 'Enter the six-digit postal code.'
                ? _problem
                : null,
          ),
        ] else
          PennyTextField(
            label: 'Meeting link',
            placeholder: 'https://',
            controller: _link,
            keyboardType: TextInputType.url,
            error: _problem?.startsWith('Enter a meeting link') ?? false
                ? _problem
                : null,
          ),
        const SizedBox(height: PennySpace.s6),
        PennyButton(
          label: 'Save place',
          size: PennyButtonSize.large,
          expand: true,
          onPressed: busy ? null : _save,
        ),
      ],
    );
  }
}
