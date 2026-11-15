import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
  });

  /// Converts a `Map<String, dynamic>` to a [User].
  factory User.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'User',
      json,
      () => User(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static User? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return User.fromJson(json);
  }

  final String id;
  final String email;
  final String displayName;

  /// Converts a [User] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'id': id, 'email': email, 'displayName': displayName};
  }

  @override
  int get hashCode => Object.hashAll([id, email, displayName]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        id == other.id &&
        email == other.email &&
        displayName == other.displayName;
  }
}
