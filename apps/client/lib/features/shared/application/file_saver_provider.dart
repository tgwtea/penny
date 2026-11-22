import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/file_saver.dart';

/// How the app hands files to the person, set by the composition root.
final fileSaverProvider = Provider<FileSaver>(
  (ref) => throw UnimplementedError(
    'fileSaverProvider is set by backendOverrides()',
  ),
);
