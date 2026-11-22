import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/email_category.dart';

@immutable
class Unsubscribe1 {
  const Unsubscribe1({
    required this.category,
    required this.teamName,
    required this.maskedEmail,
  });

  /// Converts a `Map<String, dynamic>` to a [Unsubscribe1].
  factory Unsubscribe1.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Unsubscribe1',
      json,
      () => Unsubscribe1(
        category: EmailCategory.fromJson(json['category'] as String),
        teamName: json['teamName'] as String,
        maskedEmail: json['maskedEmail'] as String,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Unsubscribe1? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Unsubscribe1.fromJson(json);
  }

  /// A kind of email a contact may stop. Receipts are not one of them.
  final EmailCategory category;

  /// Who sends these emails.
  final String teamName;

  /// The address, partly hidden, such as p***@example.com.
  final String maskedEmail;

  /// Converts a [Unsubscribe1] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'category': category.toJson(),
      'teamName': teamName,
      'maskedEmail': maskedEmail,
    };
  }

  @override
  int get hashCode => Object.hashAll([category, teamName, maskedEmail]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Unsubscribe1 &&
        category == other.category &&
        teamName == other.teamName &&
        maskedEmail == other.maskedEmail;
  }
}
