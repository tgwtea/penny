import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class ExtraLine {
  ExtraLine({required this.description, required this.amountCents}) {
    description.validate(minLength: 1, maxLength: 200);
    amountCents.validate(min: 1);
  }

  /// Converts a `Map<String, dynamic>` to an [ExtraLine].
  factory ExtraLine.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'ExtraLine',
      json,
      () => ExtraLine(
        description: json['description'] as String,
        amountCents: json['amountCents'] as int,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static ExtraLine? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ExtraLine.fromJson(json);
  }

  final String description;
  final int amountCents;

  /// Converts an [ExtraLine] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'description': description, 'amountCents': amountCents};
  }

  @override
  int get hashCode => Object.hashAll([description, amountCents]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExtraLine &&
        description == other.description &&
        amountCents == other.amountCents;
  }
}
