import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class StudentSignInInput {
  const StudentSignInInput({required this.email});

  /// Converts a `Map<String, dynamic>` to a [StudentSignInInput].
  factory StudentSignInInput.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'StudentSignInInput',
      json,
      () => StudentSignInInput(email: json['email'] as String),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static StudentSignInInput? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return StudentSignInInput.fromJson(json);
  }

  final String email;

  /// Converts a [StudentSignInInput] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'email': email};
  }

  @override
  int get hashCode => email.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentSignInInput && email == other.email;
  }
}
