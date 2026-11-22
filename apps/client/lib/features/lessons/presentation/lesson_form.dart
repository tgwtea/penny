// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/capability.dart';
import '../../shared/application/active_team.dart';
import '../../shared/application/clock.dart';
import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../../students/application/student_providers.dart';
import '../../team/application/team_controller.dart';
import '../../team/domain/team_member.dart';
import '../application/lesson_providers.dart';
import '../domain/lesson.dart';
import 'lesson_views.dart';

/// Opens the form to add a lesson, or to reschedule [lesson]: a sheet on
/// phone and laptop alike (designs: "add lesson", "reschedule").
Future<void> showLessonForm(
  BuildContext context,
  WidgetRef ref, {
  required ActiveTeam team,
  Lesson? lesson,
}) async {
  final saved = await showPennySheet<String>(
    context,
    title: lesson == null ? 'Add lesson' : 'Reschedule lesson',
    builder: (sheetContext) => LessonForm(
      team: team,
      lesson: lesson,
      onDone: (message) => Navigator.of(sheetContext).pop(message),
    ),
  );
  if (saved != null && context.mounted) {
    PennySnackbar.show(context, message: saved);
  }
}

/// Picks the date, time, length, tutors, students, place, title and fee of
/// a lesson. A clash is shown after saving and never blocks it (ADR 019).
class LessonForm extends ConsumerStatefulWidget {
  /// Creates the form; with [lesson], it changes that lesson.
  const LessonForm({
    super.key,
    required this.team,
    this.lesson,
    required this.onDone,
  });

  /// The team the lesson is in.
  final ActiveTeam team;

  /// The lesson to reschedule, or null to add one.
  final Lesson? lesson;

  /// Called with the snackbar message once the person is done.
  final ValueChanged<String> onDone;

  @override
  ConsumerState<LessonForm> createState() => _LessonFormState();
}

class _LessonFormState extends ConsumerState<LessonForm> with AsyncAction {
  static const _lengths = [30, 45, 60, 90, 120];

  late DateTime _date; // team wall clock, midnight
  late TimeOfDay _time;
  late int _minutes;
  String? _leadId;
  late List<String> _assisting;
  late List<String> _studentIds;
  String? _placeId;
  late final TextEditingController _title;
  late final TextEditingController _fee;
  LessonKind _kind = LessonKind.regular;
  String? _feeError;
  String? _leadError;

  /// The lesson just saved, when it clashes; the form then shows the clash.
  Lesson? _clashing;
  Lesson? _editing;

  @override
  void initState() {
    super.initState();
    final time = widget.team.time;
    final l = widget.lesson;
    _editing = l;
    final now = ref.read(clockProvider)();
    final start = l == null
        ? time.wallClock(now).add(const Duration(hours: 1))
        : time.wallClock(l.startsAt);
    _date = DateTime.utc(start.year, start.month, start.day);
    _time = l == null
        ? TimeOfDay(hour: start.hour, minute: 0)
        : TimeOfDay(hour: start.hour, minute: start.minute);
    _minutes = l == null ? 45 : l.length.inMinutes;
    _leadId = l?.lead?.membershipId ?? widget.team.membershipId;
    _assisting = [
      for (final t in l?.tutors ?? const <LessonTutor>[])
        if (!t.isLead) t.membershipId,
    ];
    _studentIds = [
      for (final s in l?.students ?? const <LessonStudent>[]) s.studentId,
    ];
    _placeId = l?.place?.locationId;
    _title = TextEditingController(text: l?.title ?? '');
    _fee = TextEditingController(
      text: l == null ? '' : (l.feeCents / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _fee.dispose();
    super.dispose();
  }

  DateTime get _start => widget.team.time.instant(
    DateTime.utc(_date.year, _date.month, _date.day, _time.hour, _time.minute),
  );

  /// "60", "60.5", "S$ 60.50" as cents, or null if it is not an amount.
  static int? _cents(String text) {
    final t = text.replaceAll(RegExp(r'[S$\s,]'), '');
    if (t.isEmpty) return 0;
    final m = RegExp(r'^(\d{1,6})(?:\.(\d{1,2}))?$').firstMatch(t);
    if (m == null) return null;
    final cents = (m.group(2) ?? '').padRight(2, '0');
    return int.parse(m.group(1)!) * 100 + int.parse(cents);
  }

  Future<void> _save() async {
    final fee = _cents(_fee.text);
    setState(() {
      _feeError = fee == null ? 'Enter an amount like 60.00.' : null;
      _leadError = _leadId == null ? 'Choose who leads the lesson.' : null;
    });
    if (fee == null || _leadId == null) return;
    final start = _start;
    final end = start.add(Duration(minutes: _minutes));
    final tutors = <TutorChoice>[
      (membershipId: _leadId!, role: TutorRole.lead),
      for (final a in _assisting)
        if (a != _leadId) (membershipId: a, role: TutorRole.assisting),
    ];
    final actions = ref.read(lessonActionsProvider);
    final editing = _editing;
    Lesson? saved;
    final ok = await run(() async {
      saved = editing == null
          ? await actions.create(
              LessonDraft(
                startsAt: start,
                endsAt: end,
                tutors: tutors,
                studentIds: _studentIds,
                locationId: _placeId,
                title: _title.text,
                feeCents: fee,
                kind: _kind,
              ),
            )
          : await actions.update(
              editing,
              LessonChanges(
                startsAt: start,
                endsAt: end,
                tutors: tutors,
                studentIds: _studentIds,
                locationId: _placeId,
                title: _title.text.trim(),
                feeCents: fee,
              ),
            );
    });
    if (!ok || !mounted) return;
    final lesson = saved!;
    if (lesson.clashes.isNotEmpty) {
      setState(() {
        _clashing = lesson;
        _editing = lesson;
      });
      return;
    }
    widget.onDone(editing == null ? 'Lesson added' : 'Lesson rescheduled');
  }

  @override
  Widget build(BuildContext context) {
    final clashing = _clashing;
    if (clashing != null) return _clashView(clashing);

    final members = ref.watch(teamMembersProvider).value ?? const [];
    final staff = [
      for (final m in members)
        if (m.status == MemberStatus.active &&
            (m.role == TeamRole.owner || m.role == TeamRole.teacher))
          m,
    ];
    String nameOf(String id) =>
        staff.where((m) => m.id == id).firstOrNull?.name ??
        widget.lesson?.tutors
            .where((t) => t.membershipId == id)
            .firstOrNull
            ?.name ??
        'You';
    final students =
        ref.watch(studentsProvider((search: '', archived: false))).value ??
        const [];
    String studentName(String id) =>
        students.where((s) => s.id == id).firstOrNull?.name ??
        widget.lesson?.students
            .where((s) => s.studentId == id)
            .firstOrNull
            ?.name ??
        '';
    final places = ref.watch(locationsProvider).value ?? const [];
    final placeName =
        places.where((p) => p.id == _placeId).firstOrNull?.name ??
        (widget.lesson?.place?.locationId == _placeId
            ? widget.lesson?.place?.name
            : null);
    final failure = this.failure;
    final teamOfOne = widget.team.isTeamOfOne;

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
        Row(
          children: [
            Expanded(
              child: PennySelectField(
                label: 'Date',
                value: PennyFormat.shortDate(_date),
                icon: PennyIcons.calendar,
                onTap: _pickDate,
              ),
            ),
            const SizedBox(width: PennySpace.s3),
            Expanded(
              child: PennySelectField(
                label: 'Starts',
                value: PennyFormat.time(
                  context,
                  DateTime.utc(2026, 1, 1, _time.hour, _time.minute),
                ),
                icon: PennyIcons.open,
                tabularFigures: true,
                onTap: _pickTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: PennySpace.s4),
        PennySelectField(
          label: 'Length',
          value: PennyFormat.minutes(_minutes),
          onTap: () async {
            final m = await showPennyChoice<int>(
              context,
              title: 'Length',
              selected: _minutes,
              choices: [
                for (final m in {..._lengths, _minutes}.toList()..sort())
                  PennyChoice(value: m, label: PennyFormat.minutes(m)),
              ],
            );
            if (m != null) setState(() => _minutes = m);
          },
        ),
        if (!teamOfOne) ...[
          const SizedBox(height: PennySpace.s4),
          PennySelectField(
            label: 'Lead tutor',
            hint: 'The lead tutor bills the lesson.',
            value: _leadId == null ? null : nameOf(_leadId!),
            placeholder: 'Choose a tutor',
            error: _leadError,
            onTap: () async {
              final id = await showPennyChoice<String>(
                context,
                title: 'Lead tutor',
                selected: _leadId,
                choices: [
                  for (final m in staff)
                    PennyChoice(
                      value: m.id,
                      label: m.name,
                      description: m.role.label,
                    ),
                ],
              );
              if (id != null) setState(() => _leadId = id);
            },
          ),
          const SizedBox(height: PennySpace.s4),
          PennySelectField(
            label: 'Assisting tutors',
            value: _assisting.isEmpty
                ? null
                : PennyFormat.names([for (final a in _assisting) nameOf(a)]),
            placeholder: 'None',
            onTap: () async {
              final ids = await _pickMany(
                title: 'Assisting tutors',
                options: [
                  for (final m in staff)
                    if (m.id != _leadId) (id: m.id, label: m.name),
                ],
                chosen: _assisting,
              );
              if (ids != null) setState(() => _assisting = ids);
            },
          ),
        ],
        const SizedBox(height: PennySpace.s4),
        PennySelectField(
          label: 'Students',
          value: _studentIds.isEmpty
              ? null
              : PennyFormat.names([
                  for (final s in _studentIds) studentName(s),
                ], max: 3),
          placeholder: 'Choose students',
          onTap: () async {
            final ids = await _pickMany(
              title: 'Students',
              options: [for (final s in students) (id: s.id, label: s.name)],
              chosen: _studentIds,
              searchable: true,
            );
            if (ids != null) setState(() => _studentIds = ids);
          },
        ),
        const SizedBox(height: PennySpace.s4),
        PennySelectField(
          label: 'Place',
          value: placeName,
          placeholder: 'No place',
          icon: PennyIcons.location,
          onTap: () async {
            final id = await showPennyChoice<String>(
              context,
              title: 'Place',
              selected: _placeId ?? '',
              choices: [
                const PennyChoice(value: '', label: 'No place'),
                for (final p in places)
                  PennyChoice(
                    value: p.id,
                    label: p.name,
                    description: p.addressLine.isEmpty
                        ? (p.meetingUrl.isEmpty ? null : p.meetingUrl)
                        : p.addressLine,
                  ),
              ],
            );
            if (id != null) setState(() => _placeId = id.isEmpty ? null : id);
          },
        ),
        const SizedBox(height: PennySpace.s4),
        PennyTextField(
          label: 'Title',
          placeholder: 'Guitar, Grade 5',
          controller: _title,
        ),
        const SizedBox(height: PennySpace.s4),
        PennyTextField(
          label: 'Fee (S\$)',
          hint: 'For the whole lesson. Leave empty for no fee.',
          controller: _fee,
          placeholder: '60.00',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          tabularFigures: true,
          error: _feeError,
        ),
        if (widget.lesson == null) ...[
          const SizedBox(height: PennySpace.s4),
          PennyOptionRow(
            title: 'A regular lesson',
            selected: _kind == LessonKind.regular,
            onSelected: () => setState(() => _kind = LessonKind.regular),
          ),
          const SizedBox(height: PennySpace.s2),
          PennyOptionRow(
            title: 'A trial lesson',
            body: 'A first lesson to see how it goes.',
            selected: _kind == LessonKind.trial,
            onSelected: () => setState(() => _kind = LessonKind.trial),
          ),
        ],
        const SizedBox(height: PennySpace.s6),
        PennyButton(
          label: _editing == null ? 'Add lesson' : 'Save changes',
          size: PennyButtonSize.large,
          expand: true,
          onPressed: busy ? null : _save,
        ),
      ],
    );
  }

  Widget _clashView(Lesson saved) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PennyNotice(
          tone: PennyNoticeTone.warning,
          title: clashText(context, saved.clashes.first, widget.team.time),
          body:
              'The lesson is saved: clashes never block. Change the time if '
              'one of them should move.',
        ),
        const SizedBox(height: PennySpace.s6),
        PennyButton(
          label: 'Keep it',
          size: PennyButtonSize.large,
          expand: true,
          onPressed: () => widget.onDone(
            widget.lesson == null ? 'Lesson added' : 'Lesson rescheduled',
          ),
        ),
        const SizedBox(height: PennySpace.s3),
        PennyButton(
          label: 'Change the time',
          variant: PennyButtonVariant.secondary,
          expand: true,
          onPressed: () => setState(() => _clashing = null),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 2),
    );
    if (picked != null) {
      setState(
        () => _date = DateTime.utc(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  /// Chooses any number of [options] in a sheet of check rows.
  Future<List<String>?> _pickMany({
    required String title,
    required List<({String id, String label})> options,
    required List<String> chosen,
    bool searchable = false,
  }) {
    return showPennySheet<List<String>>(
      context,
      title: title,
      builder: (sheetContext) =>
          _ManyPicker(options: options, chosen: chosen, searchable: searchable),
    );
  }
}

class _ManyPicker extends StatefulWidget {
  const _ManyPicker({
    required this.options,
    required this.chosen,
    required this.searchable,
  });

  final List<({String id, String label})> options;
  final List<String> chosen;
  final bool searchable;

  @override
  State<_ManyPicker> createState() => _ManyPickerState();
}

class _ManyPickerState extends State<_ManyPicker> {
  late final _chosen = [...widget.chosen];
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final term = _search.trim().toLowerCase();
    final shown = [
      for (final o in widget.options)
        if (term.isEmpty ||
            o.label.toLowerCase().split(' ').any((w) => w.startsWith(term)))
          o,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.searchable) ...[
          PennyTextField(
            label: 'Search',
            prefixIcon: PennyIcons.search,
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: PennySpace.s2),
        ],
        if (shown.isEmpty)
          const PennyEmptyState(title: 'No one to choose here')
        else
          for (final o in shown)
            PennyCheckRow(
              title: o.label,
              checked: _chosen.contains(o.id),
              onChanged: (on) =>
                  setState(() => on ? _chosen.add(o.id) : _chosen.remove(o.id)),
            ),
        const SizedBox(height: PennySpace.s4),
        PennyButton(
          label: 'Done',
          expand: true,
          onPressed: () => Navigator.of(context).pop(_chosen),
        ),
      ],
    );
  }
}
