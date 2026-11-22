import 'dart:typed_data';

/// Hands a file to the person: a download in the browser. Set by the
/// composition root, so features never see the platform.
abstract interface class FileSaver {
  /// Offers [bytes] as a file named [filename] of [mimeType]. Throws an
  /// [UnsupportedError] where the platform has no way to.
  Future<void> save(String filename, String mimeType, Uint8List bytes);
}
