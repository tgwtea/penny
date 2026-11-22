// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../../../core/failure.dart';

/// One action at a time from a screen: whether it is running, and why it
/// last failed. Screens disable their buttons while [busy] and show
/// [failure] in a Notice.
///
///     final ok = await run(() => repository.save(lesson));
///     if (ok && mounted) PennySnackbar.show(context, message: 'Lesson saved');
mixin AsyncAction<T extends StatefulWidget> on State<T> {
  /// Whether the action is running.
  bool busy = false;

  /// Why the last run failed, or null.
  Failure? failure;

  /// Runs [action] unless one is already running. Returns whether it
  /// succeeded; a Failure is kept in [failure], anything else is a bug and
  /// propagates.
  Future<bool> run(Future<void> Function() action) async {
    if (busy) return false;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await action();
      return true;
    } on Failure catch (f) {
      if (mounted) setState(() => failure = f);
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Forgets the last failure, such as when the person edits a field.
  void clearFailure() {
    if (failure != null) setState(() => failure = null);
  }
}
