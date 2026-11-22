// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../application/lesson_providers.dart';
import '../domain/lesson.dart';

/// Adds a task, goal or note to a lesson.
class LessonItemForm extends ConsumerStatefulWidget {
  /// Creates the form.
  const LessonItemForm({
    super.key,
    required this.lessonId,
    required this.onDone,
  });

  /// The lesson.
  final String lessonId;

  /// Called once it is added.
  final VoidCallback onDone;

  @override
  ConsumerState<LessonItemForm> createState() => _LessonItemFormState();
}

class _LessonItemFormState extends ConsumerState<LessonItemForm>
    with AsyncAction {
  ItemKind _kind = ItemKind.task;
  final _body = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(
      () => _error = _body.text.trim().isEmpty ? 'Enter what to add.' : null,
    );
    if (_error != null) return;
    final ok = await run(
      () => ref
          .read(lessonActionsProvider)
          .addItem(widget.lessonId, kind: _kind, body: _body.text),
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
        PennySegmented<ItemKind>(
          segments: const [
            PennySegment(value: ItemKind.task, label: 'Task'),
            PennySegment(value: ItemKind.goal, label: 'Goal'),
            PennySegment(value: ItemKind.note, label: 'Note'),
          ],
          selected: _kind,
          onChanged: (k) => setState(() => _kind = k),
        ),
        const SizedBox(height: PennySpace.s4),
        PennyTextField(
          label: switch (_kind) {
            ItemKind.task => 'What to practise or do',
            ItemKind.goal => 'What to work towards',
            ItemKind.note => 'Note',
          },
          hint: 'Seen by the team\'s staff only.',
          controller: _body,
          error: _error,
          onSubmitted: (_) => _add(),
        ),
        const SizedBox(height: PennySpace.s6),
        PennyButton(
          label: 'Add',
          size: PennyButtonSize.large,
          expand: true,
          onPressed: busy ? null : _add,
        ),
      ],
    );
  }
}
