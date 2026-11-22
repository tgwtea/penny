import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/member.dart';

@immutable
class MemberList {
  const MemberList({required this.items, this.nextCursor});

  /// Converts a `Map<String, dynamic>` to a [MemberList].
  factory MemberList.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'MemberList',
      json,
      () => MemberList(
        items: (json['items'] as List)
            .map<Member>((e) => Member.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static MemberList? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return MemberList.fromJson(json);
  }

  final List<Member> items;

  /// Pass as `cursor` for the next page. Absent on the last page.
  final String? nextCursor;

  /// Converts a [MemberList] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'nextCursor': ?nextCursor,
    };
  }

  @override
  int get hashCode => Object.hashAll([listHash(items), nextCursor]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemberList &&
        listsEqual(items, other.items) &&
        nextCursor == other.nextCursor;
  }
}
