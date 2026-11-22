import 'dart:typed_data';

import '../core/file_saver.dart';
import 'file_saver_stub.dart'
    if (dart.library.js_interop) 'file_saver_web.dart'
    as platform;

/// Hands files to the person the way the platform allows: a download in the
/// browser. Other platforms have no saving yet (mobile is deferred).
class PlatformFileSaver implements FileSaver {
  @override
  Future<void> save(String filename, String mimeType, Uint8List bytes) =>
      platform.saveFile(filename, mimeType, bytes);
}
