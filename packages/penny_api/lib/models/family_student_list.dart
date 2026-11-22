import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/family_student.dart';

@immutable
class FamilyStudentList {
  const FamilyStudentList({required this.items});

  /// Converts a `Map<String, dynamic>` to a [FamilyStudentList].
  factory FamilyStudentList.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'FamilyStudentList',
      json,
      () => FamilyStudentList(
        items: (json['items'] as List)
            .map<FamilyStudent>(
              (e) => FamilyStudent.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static FamilyStudentList? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return FamilyStudentList.fromJson(json);
  }

  final List<FamilyStudent> items;

  /// Converts a [FamilyStudentList] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'items': items.map((e) => e.toJson()).toList()};
  }

  @override
  int get hashCode => listHash(items).hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FamilyStudentList && listsEqual(items, other.items);
  }
}
