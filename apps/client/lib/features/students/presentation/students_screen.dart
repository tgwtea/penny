// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/failure.dart';
import '../../shared/application/active_team.dart';
import '../../shared/presentation/failure_text.dart';
import '../../shared/presentation/paths.dart';
import '../application/student_providers.dart';
import '../domain/student.dart';
import 'student_forms.dart';

/// Students (docs/design/screens.md, "Students"): every student for owners,
/// the ones they teach for teachers. Search by any part of a name; owners
/// can also see archived students and add new ones.
class StudentsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  String _search = '';
  bool _archived = false;

  Future<void> _add(ActiveTeam team) async {
    final added = await showPennySheet<Student>(
      context,
      title: 'Add student',
      builder: (sheetContext) => AddStudentForm(
        team: team,
        onDone: (s) => Navigator.of(sheetContext).pop(s),
      ),
    );
    if (added != null && mounted) {
      PennySnackbar.show(context, message: '${added.name} added');
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(activeTeamProvider);
    if (team == null) return const SizedBox.shrink();
    final manage = canManageStudents(team);
    final query = (search: _search, archived: manage && _archived);
    final students = ref.watch(studentsProvider(query));

    return PennyPage(
      title: 'Students',
      actions: [
        if (manage)
          PennyButton(
            label: 'Add student',
            icon: PennyIcons.addPerson,
            onPressed: () => _add(team),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PennyTextField(
            label: 'Search',
            placeholder: 'A student\'s name',
            prefixIcon: PennyIcons.search,
            onChanged: (v) => setState(() => _search = v),
          ),
          if (manage) ...[
            const SizedBox(height: PennySpace.s3),
            Align(
              alignment: Alignment.centerLeft,
              child: PennySegmented<bool>(
                segments: const [
                  PennySegment(value: false, label: 'Current'),
                  PennySegment(value: true, label: 'Archived'),
                ],
                selected: _archived,
                compact: PennyLayout.isWide(context),
                onChanged: (v) => setState(() => _archived = v),
              ),
            ),
          ],
          const SizedBox(height: PennySpace.s4),
          switch (students) {
            AsyncData(:final value) =>
              value.isEmpty
                  ? PennyEmptyState(
                      title: _search.trim().isNotEmpty
                          ? 'No students match "${_search.trim()}"'
                          : _archived
                          ? 'No archived students'
                          : 'No students yet',
                      body: _search.trim().isNotEmpty || _archived
                          ? null
                          : manage
                          ? 'Add a student to book their lessons.'
                          : 'Students you teach will appear here.',
                      // "Add student" is already the page's action.
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, s) in value.indexed) ...[
                          if (i > 0) const PennyDivider(),
                          PennyListRow(
                            leading: PennyAvatar(name: s.name),
                            title: s.name,
                            subtitle: team.isTeamOfOne
                                ? null
                                : s.primaryTeacherName,
                            onTap: () => context.push(Paths.student(s.id)),
                          ),
                        ],
                      ],
                    ),
            AsyncError(:final error) => PennyNotice(
              tone: PennyNoticeTone.danger,
              title: 'Couldn\'t load students.',
              body: error is Failure ? failureText(error) : null,
              action: PennyButton(
                label: 'Retry',
                icon: PennyIcons.retry,
                variant: PennyButtonVariant.quiet,
                onPressed: () => ref.invalidate(studentsProvider(query)),
              ),
            ),
            _ => const Column(
              children: [
                PennySkeletonRow(),
                PennySkeletonRow(),
                PennySkeletonRow(),
              ],
            ),
          },
        ],
      ),
    );
  }
}
