// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/failure.dart';
import '../application/server_info_provider.dart';

/// Which API build the app is connected to, or why it is not.
class ServerStatus extends ConsumerWidget {
  /// Creates the status line.
  const ServerStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = PennyColors.of(context);
    final info = ref.watch(serverInfoProvider);
    return switch (info) {
      AsyncData(:final value) => Text(
        value.version == 'demo'
            ? 'Demo data, no server'
            : 'Connected to Penny API ${value.version} (${value.commit})',
        style: PennyText.small.copyWith(color: c.textSecondary),
      ),
      AsyncError(:final error) => PennyNotice(
        tone: PennyNoticeTone.danger,
        title: error is NetworkFailure
            ? 'Couldn\'t reach the Penny API.'
            : 'The Penny API answered with an error.',
        body: 'Check your connection, then try again.',
        action: PennyButton(
          label: 'Retry',
          icon: PennyIcons.retry,
          variant: PennyButtonVariant.quiet,
          onPressed: () => ref.invalidate(serverInfoProvider),
        ),
      ),
      _ => const PennySkeleton(width: _loadingWidth, height: _loadingHeight),
    };
  }

  static const double _loadingWidth = 200;
  static const double _loadingHeight = 14;
}
