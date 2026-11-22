import 'dart:convert';
import 'dart:typed_data';

/// A data export, ready to hand to the person as a file (docs/privacy.md).
class DataExport {
  /// Creates one.
  const DataExport({required this.filename, required this.bytes});

  /// "Penny data 2026-11-22.json".
  final String filename;

  /// The JSON document, UTF-8.
  final Uint8List bytes;

  /// [json] as an indented JSON file named for [what] on [at]'s date.
  factory DataExport.of(String what, DateTime at, Map<String, Object?> json) {
    final day = at.toUtc().toIso8601String().substring(0, 10);
    return DataExport(
      filename: '$what $day.json',
      bytes: Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
      ),
    );
  }
}

/// PDPA access requests (build plan, Phase 9): what Penny holds about the
/// signed-in person, and, for a team's owner, about one of its students.
///
/// Methods throw Failures. Only owners export a student; the server
/// refuses anyone else.
abstract interface class PrivacyRepository {
  /// Everything Penny holds about the signed-in person.
  Future<DataExport> myData();

  /// Everything the team holds about [studentId], for its owner to review
  /// before passing it on.
  Future<DataExport> studentData(String teamId, String studentId);
}
