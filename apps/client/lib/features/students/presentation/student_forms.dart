// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/capability.dart';
import '../../shared/application/active_team.dart';
import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../../shared/presentation/validation.dart';
import '../../team/application/team_controller.dart';
import '../../team/domain/team_member.dart';
import '../application/student_providers.dart';
import '../domain/student.dart';

/// Adds a student with who usually teaches them and a first contact
/// (designs: "add student").
class AddStudentForm extends ConsumerStatefulWidget {
  /// Creates the form.
  const AddStudentForm({super.key, required this.team, required this.onDone});

  /// The team.
  final ActiveTeam team;

  /// Called with the new student.
  final ValueChanged<Student> onDone;

  @override
  ConsumerState<AddStudentForm> createState() => _AddStudentFormState();
}

class _AddStudentFormState extends ConsumerState<AddStudentForm>
    with AsyncAction {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  ContactRelationship _relationship = ContactRelationship.parent;
  late String? _teacherId = widget.team.membershipId;
  String? _nameError;
  String? _emailError;

  @override
  void dispose() {
    for (final c in [_name, _contact, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _add() async {
    final email = _email.text.trim();
    setState(() {
      _nameError = nameProblem(
        _name.text,
        missing: 'Enter the student\'s name.',
      );
      _emailError = email.isEmpty ? null : emailProblem(email);
    });
    if (_nameError != null || _emailError != null) return;
    Student? added;
    final ok = await run(() async {
      added = await ref
          .read(studentActionsProvider)
          .create(
            StudentDraft(
              name: _name.text,
              primaryTeacherId: _teacherId,
              contacts: [
                if (_contact.text.trim().isNotEmpty)
                  ContactDraft(
                    name: _contact.text,
                    relationship: _relationship,
                    email: email.isEmpty ? null : email,
                    phone: _phone.text.trim().isEmpty ? null : _phone.text,
                  ),
              ],
            ),
          );
    });
    if (ok && added != null) widget.onDone(added!);
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(teamMembersProvider).value ?? const [];
    final staff = [
      for (final m in members)
        if (m.status == MemberStatus.active &&
            (m.role == TeamRole.owner || m.role == TeamRole.teacher))
          m,
    ];
    final failure = this.failure;
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
        PennyTextField(
          label: 'Student\'s name',
          controller: _name,
          error: _nameError,
          textInputAction: TextInputAction.next,
        ),
        if (!widget.team.isTeamOfOne) ...[
          const SizedBox(height: PennySpace.s4),
          PennySelectField(
            label: 'Usually taught by',
            value:
                staff.where((m) => m.id == _teacherId).firstOrNull?.name ??
                (_teacherId == null ? null : 'You'),
            placeholder: 'No one yet',
            onTap: () async {
              final id = await showPennyChoice<String>(
                context,
                title: 'Usually taught by',
                selected: _teacherId,
                choices: [
                  for (final m in staff)
                    PennyChoice(
                      value: m.id,
                      label: m.name,
                      description: m.role.label,
                    ),
                ],
              );
              if (id != null) setState(() => _teacherId = id);
            },
          ),
        ],
        const PennySectionHeader(title: 'Who gets reminders and receipts'),
        PennyTextField(
          label: 'Contact\'s name',
          hint: 'A parent or guardian, or the student.',
          controller: _contact,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: PennySpace.s4),
        PennySelectField(
          label: 'Relationship',
          value: _relationship.label,
          onTap: () async {
            final r = await pickRelationship(context, _relationship);
            if (r != null) setState(() => _relationship = r);
          },
        ),
        const SizedBox(height: PennySpace.s4),
        PennyTextField(
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          error: _emailError,
        ),
        const SizedBox(height: PennySpace.s4),
        PennyTextField(
          label: 'Phone',
          controller: _phone,
          keyboardType: TextInputType.phone,
          tabularFigures: true,
        ),
        const SizedBox(height: PennySpace.s6),
        PennyButton(
          label: 'Add student',
          size: PennyButtonSize.large,
          expand: true,
          onPressed: busy ? null : _add,
        ),
      ],
    );
  }
}

/// Adds a contact, or changes [contact].
class ContactForm extends ConsumerStatefulWidget {
  /// Creates the form.
  const ContactForm({
    super.key,
    required this.studentId,
    this.contact,
    required this.onDone,
  });

  /// The student.
  final String studentId;

  /// The contact to change, or null to add one.
  final Contact? contact;

  /// Called once saved.
  final VoidCallback onDone;

  @override
  ConsumerState<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<ContactForm> with AsyncAction {
  late final _name = TextEditingController(text: widget.contact?.name);
  late final _email = TextEditingController(text: widget.contact?.email);
  late final _phone = TextEditingController(text: widget.contact?.phone);
  late ContactRelationship _relationship =
      widget.contact?.relationship ?? ContactRelationship.parent;
  late bool _reminders = widget.contact?.receivesReminders ?? true;
  late bool _billing = widget.contact?.receivesBilling ?? true;
  late bool _paymentReminders =
      widget.contact?.receivesPaymentReminders ?? true;
  String? _nameError;
  String? _emailError;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final email = _email.text.trim();
    setState(() {
      _nameError = nameProblem(
        _name.text,
        missing: 'Enter the contact\'s name.',
      );
      _emailError = email.isEmpty ? null : emailProblem(email);
    });
    if (_nameError != null || _emailError != null) return;
    final draft = ContactDraft(
      name: _name.text,
      relationship: _relationship,
      email: email.isEmpty ? null : email,
      phone: _phone.text.trim().isEmpty ? null : _phone.text,
      receivesReminders: _reminders,
      receivesBilling: _billing,
      receivesPaymentReminders: _paymentReminders,
    );
    final actions = ref.read(studentActionsProvider);
    final contact = widget.contact;
    final ok = await run(
      () => contact == null
          ? actions.addContact(widget.studentId, draft)
          : actions.updateContact(widget.studentId, contact.id, draft),
    );
    if (ok) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
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
        PennyTextField(label: 'Name', controller: _name, error: _nameError),
        const SizedBox(height: PennySpace.s4),
        PennySelectField(
          label: 'Relationship',
          value: _relationship.label,
          onTap: () async {
            final r = await pickRelationship(context, _relationship);
            if (r != null) setState(() => _relationship = r);
          },
        ),
        const SizedBox(height: PennySpace.s4),
        PennyTextField(
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          error: _emailError,
        ),
        const SizedBox(height: PennySpace.s4),
        PennyTextField(
          label: 'Phone',
          controller: _phone,
          keyboardType: TextInputType.phone,
          tabularFigures: true,
        ),
        const SizedBox(height: PennySpace.s2),
        PennyToggleRow(
          title: 'Lesson reminders',
          value: _reminders,
          onChanged: (v) => setState(() => _reminders = v),
        ),
        PennyToggleRow(
          title: 'Payment requests and receipts',
          value: _billing,
          onChanged: (v) => setState(() => _billing = v),
        ),
        if (_billing)
          PennyToggleRow(
            title: 'Payment reminders',
            body: 'A weekly email while a request is overdue.',
            value: _paymentReminders,
            onChanged: (v) => setState(() => _paymentReminders = v),
          ),
        const SizedBox(height: PennySpace.s6),
        PennyButton(
          label: widget.contact == null ? 'Add contact' : 'Save contact',
          size: PennyButtonSize.large,
          expand: true,
          onPressed: busy ? null : _save,
        ),
      ],
    );
  }
}

/// Asks how a contact relates to the student.
Future<ContactRelationship?> pickRelationship(
  BuildContext context,
  ContactRelationship current,
) => showPennyChoice<ContactRelationship>(
  context,
  title: 'Relationship',
  selected: current,
  choices: [
    for (final r in ContactRelationship.values)
      PennyChoice(value: r, label: r.label),
  ],
);

/// Whether [team] may change students (for showing controls).
bool canManageStudents(ActiveTeam team) => team.can(Capability.manageStudents);
