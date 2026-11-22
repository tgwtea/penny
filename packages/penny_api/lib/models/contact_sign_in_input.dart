import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class ContactSignInInput {
  const ContactSignInInput({required this.canSignIn});

  /// Converts a `Map<String, dynamic>` to a [ContactSignInInput].
  factory ContactSignInInput.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'ContactSignInInput',
      json,
      () => ContactSignInInput(canSignIn: json['canSignIn'] as bool),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static ContactSignInInput? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ContactSignInInput.fromJson(json);
  }

  final bool canSignIn;

  /// Converts a [ContactSignInInput] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'canSignIn': canSignIn};
  }

  @override
  int get hashCode => canSignIn.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactSignInInput && canSignIn == other.canSignIn;
  }
}
