// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/failure.dart';
import '../../shared/presentation/failure_text.dart';

/// A secondary button that downloads a data export with [download], then
/// says it did, or why it could not.
class DataExportButton extends ConsumerStatefulWidget {
  /// Creates the button.
  const DataExportButton({
    super.key,
    required this.label,
    required this.download,
  });

  /// "Download my data".
  final String label;

  /// Fetches and saves the export.
  final Future<void> Function(WidgetRef ref) download;

  @override
  ConsumerState<DataExportButton> createState() => _DataExportButtonState();
}

class _DataExportButtonState extends ConsumerState<DataExportButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    String message;
    try {
      await widget.download(ref);
      message = 'Download started';
    } on Failure catch (f) {
      message = failureText(f);
    } on UnsupportedError {
      message = 'Downloads work in the web app. Open Penny in a browser.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) PennySnackbar.show(context, message: message);
  }

  @override
  Widget build(BuildContext context) => PennyButton(
    label: widget.label,
    icon: PennyIcons.download,
    variant: PennyButtonVariant.secondary,
    onPressed: _busy ? null : _run,
  );
}
