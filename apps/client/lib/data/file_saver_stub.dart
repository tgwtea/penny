import 'dart:typed_data';

/// Where no browser is: nothing to hand the file to yet.
Future<void> saveFile(String filename, String mimeType, Uint8List bytes) =>
    throw UnsupportedError('Saving files works in the web app only.');
