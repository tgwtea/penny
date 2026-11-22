import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/cancellation.dart';
import 'package:penny_api/models/family_lesson_item.dart';
import 'package:penny_api/models/lesson_location.dart';
import 'package:penny_api/models/lesson_status.dart';

@immutable
class FamilyLesson {
  const FamilyLesson({
    required this.id,
    required this.studentIds,
    required this.otherStudents,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.tutors,
    required this.items,
    this.title,
    this.location,
    this.cancellation,
  });

  /// Converts a `Map<String, dynamic>` to a [FamilyLesson].
  factory FamilyLesson.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'FamilyLesson',
      json,
      () => FamilyLesson(
        id: json['id'] as String,
        studentIds: (json['studentIds'] as List).cast<String>(),
        otherStudents: json['otherStudents'] as int,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        status: LessonStatus.fromJson(json['status'] as String),
        title: json['title'] as String?,
        tutors: (json['tutors'] as List).cast<String>(),
        location: LessonLocation.maybeFromJson(
          json['location'] as Map<String, dynamic>?,
        ),
        cancellation: Cancellation.maybeFromJson(
          json['cancellation'] as Map<String, dynamic>?,
        ),
        items: (json['items'] as List)
            .map<FamilyLessonItem>(
              (e) => FamilyLessonItem.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static FamilyLesson? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return FamilyLesson.fromJson(json);
  }

  final String id;

  /// The caller's students in the lesson.
  final List<String> studentIds;

  /// How many other students are in it, unnamed.
  final int otherStudents;
  final DateTime startsAt;
  final DateTime endsAt;
  final LessonStatus status;
  final String? title;
  final List<String> tutors;

  /// Where the lesson is, as it was when booked.
  final LessonLocation? location;
  final Cancellation? cancellation;
  final List<FamilyLessonItem> items;

  /// Converts a [FamilyLesson] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentIds': studentIds,
      'otherStudents': otherStudents,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'endsAt': endsAt.toUtc().toIso8601String(),
      'status': status.toJson(),
      'title': ?title,
      'tutors': tutors,
      'location': ?location?.toJson(),
      'cancellation': ?cancellation?.toJson(),
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    listHash(studentIds),
    otherStudents,
    startsAt,
    endsAt,
    status,
    title,
    listHash(tutors),
    location,
    cancellation,
    listHash(items),
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FamilyLesson &&
        id == other.id &&
        listsEqual(studentIds, other.studentIds) &&
        otherStudents == other.otherStudents &&
        startsAt == other.startsAt &&
        endsAt == other.endsAt &&
        status == other.status &&
        title == other.title &&
        listsEqual(tutors, other.tutors) &&
        location == other.location &&
        cancellation == other.cancellation &&
        listsEqual(items, other.items);
  }
}
