import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:penny_api/api_client.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/messages/cancel_lesson_request.dart';
import 'package:penny_api/messages/complete_lesson_request.dart';
import 'package:penny_api/messages/end_series_request.dart';
import 'package:penny_api/models/calendar_feed.dart';
import 'package:penny_api/models/cancellation_policy.dart';
import 'package:penny_api/models/cancellation_policy_input.dart';
import 'package:penny_api/models/history_list.dart';
import 'package:penny_api/models/lesson.dart';
import 'package:penny_api/models/lesson_changes.dart';
import 'package:penny_api/models/lesson_input.dart';
import 'package:penny_api/models/lesson_item.dart';
import 'package:penny_api/models/lesson_item_changes.dart';
import 'package:penny_api/models/lesson_item_input.dart';
import 'package:penny_api/models/lesson_list.dart';
import 'package:penny_api/models/location.dart';
import 'package:penny_api/models/location_input.dart';
import 'package:penny_api/models/location_list.dart';
import 'package:penny_api/models/problem.dart';
import 'package:penny_api/models/series.dart';
import 'package:penny_api/models/series_changes.dart';
import 'package:penny_api/models/series_input.dart';
import 'package:penny_api/models/timetable.dart';

/// Lessons, where they happen, what happens in them, and cancellation policies.
class LessonsApi {
  LessonsApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  /// List the team's saved places
  Future<LocationList> listLocations(String workspaceId) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/locations'.replaceAll(
        '{workspaceId}',
        Uri.encodeComponent(workspaceId),
      ),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return LocationList.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Save a place lessons happen
  /// Needs `manage_lessons`.
  Future<Location> createLocation(
    String workspaceId,
    LocationInput locationInput,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/locations'.replaceAll(
        '{workspaceId}',
        Uri.encodeComponent(workspaceId),
      ),
      body: locationInput.toJson(),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return Location.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Change a saved place
  /// Needs `manage_lessons`. Lessons keep the address they were booked
  /// with; only lessons added later use the change.
  Future<Location> updateLocation(
    String workspaceId,
    String locationId,
    LocationInput locationInput,
  ) async {
    final response = await client.invokeApi(
      method: Method.put,
      path: '/v1/workspaces/{workspaceId}/locations/{locationId}'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{locationId}', Uri.encodeComponent(locationId)),
      body: locationInput.toJson(),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return Location.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Stop offering a saved place
  /// Needs `manage_lessons`. Past and booked lessons keep it.
  Future<void> archiveLocation(String workspaceId, String locationId) async {
    final response = await client.invokeApi(
      method: Method.delete,
      path: '/v1/workspaces/{workspaceId}/locations/{locationId}'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{locationId}', Uri.encodeComponent(locationId)),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }
  }

  /// List lessons in a time range
  /// Owners (`view_team_timetable`) see every lesson and may filter by
  /// tutor; teachers see only lessons they tutor, whatever `teacherId`
  /// says. Each lesson carries its clashes.
  Future<LessonList> listLessons(
    String workspaceId,
    DateTime from,
    DateTime to, {
    String? teacherId,
    String? studentId,
    String? cursor,
    int? limit = 100,
  }) async {
    cursor?.validate(maxLength: 200);
    limit?.validate(min: 1, max: 500);

    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/lessons'.replaceAll(
        '{workspaceId}',
        Uri.encodeComponent(workspaceId),
      ),
      queryParameters: {
        'from': [from.toUtc().toIso8601String()],
        'to': [to.toUtc().toIso8601String()],
        if (teacherId != null) 'teacherId': [teacherId],
        if (studentId != null) 'studentId': [studentId],
        if (cursor != null) 'cursor': [cursor],
        if (limit != null) 'limit': [limit.toString()],
      },
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return LessonList.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Add a lesson
  /// Needs `manage_lessons`. A clash with another lesson of a tutor or
  /// student is reported in `clashes` and never blocks saving (ADR 019).
  /// The first tutor listed with role `lead` bills the lesson (ADR 018).
  Future<Lesson> createLesson(
    String workspaceId,
    LessonInput lessonInput,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/lessons'.replaceAll(
        '{workspaceId}',
        Uri.encodeComponent(workspaceId),
      ),
      body: lessonInput.toJson(),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return Lesson.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Get a lesson with its tasks, goals and notes
  /// For owners, and for tutors on the lesson.
  Future<Lesson> getLesson(String workspaceId, String lessonId) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/lessons/{lessonId}'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{lessonId}', Uri.encodeComponent(lessonId)),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return Lesson.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Move, reassign or otherwise change a scheduled lesson
  /// Needs `manage_lessons`; changing tutors also needs
  /// `reassign_lessons`. Send the lesson's `version` in `If-Match`; a
  /// lesson changed since gets 412.
  Future<Lesson> updateLesson(
    String workspaceId,
    String lessonId,
    String ifMatch,
    LessonChanges lessonChanges,
  ) async {
    final response = await client.invokeApi(
      method: Method.patch,
      path: '/v1/workspaces/{workspaceId}/lessons/{lessonId}'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{lessonId}', Uri.encodeComponent(lessonId)),
      body: lessonChanges.toJson(),
      headerParameters: {'If-Match': ifMatch},
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return Lesson.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Mark a lesson done
  /// For owners, and for tutors on the lesson (`complete_own_lessons`).
  /// The lesson becomes billable.
  Future<Lesson> completeLesson(
    String workspaceId,
    String lessonId,
    String ifMatch, {
    CompleteLessonRequest? completeLessonRequest,
  }) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/lessons/{lessonId}/complete'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{lessonId}', Uri.encodeComponent(lessonId)),
      body: completeLessonRequest?.toJson(),
      headerParameters: {'If-Match': ifMatch},
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return Lesson.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Record that the student did not come
  /// For owners, and for tutors on the lesson. Billable when the lead
  /// tutor's cancellation policy says no-shows are.
  Future<Lesson> markNoShow(
    String workspaceId,
    String lessonId,
    String ifMatch,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/lessons/{lessonId}/no-show'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{lessonId}', Uri.encodeComponent(lessonId)),
      headerParameters: {'If-Match': ifMatch},
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return Lesson.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Cancel a lesson, optionally booking a make-up
  /// Needs `manage_lessons`. A cancellation by the student's side with
  /// less notice than the lead tutor's policy asks for is late, and
  /// billable only if that policy says so. Pending reminders stop.
  Future<Lesson> cancelLesson(
    String workspaceId,
    String lessonId,
    String ifMatch,
    CancelLessonRequest cancelLessonRequest,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/lessons/{lessonId}/cancel'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{lessonId}', Uri.encodeComponent(lessonId)),
      body: cancelLessonRequest.toJson(),
      headerParameters: {'If-Match': ifMatch},
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return Lesson.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Put a done, no-show or cancelled lesson back to scheduled
  /// Owners may reopen any lesson; the tutor who marked a lesson done or
  /// no-show may reopen it, which is how Undo works. Refused with 409
  /// while a payment request covers the lesson: withdraw the request, or
  /// void its receipt, first.
  Future<Lesson> reopenLesson(
    String workspaceId,
    String lessonId,
    String ifMatch,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/lessons/{lessonId}/reopen'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{lessonId}', Uri.encodeComponent(lessonId)),
      headerParameters: {'If-Match': ifMatch},
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return Lesson.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Add a task, goal or note to a lesson
  /// For owners, and for tutors on the lesson (`edit_own_lesson_items`).
  Future<LessonItem> addLessonItem(
    String workspaceId,
    String lessonId,
    LessonItemInput lessonItemInput,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/lessons/{lessonId}/items'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{lessonId}', Uri.encodeComponent(lessonId)),
      body: lessonItemInput.toJson(),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return LessonItem.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Remove an item
  /// For owners, and for the item's author.
  Future<void> deleteLessonItem(
    String workspaceId,
    String lessonId,
    String itemId,
  ) async {
    final response = await client.invokeApi(
      method: Method.delete,
      path: '/v1/workspaces/{workspaceId}/lessons/{lessonId}/items/{itemId}'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{lessonId}', Uri.encodeComponent(lessonId))
          .replaceAll('{itemId}', Uri.encodeComponent(itemId)),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }
  }

  /// Edit an item, or tick or untick a task
  /// For owners, and for tutors on the lesson.
  Future<LessonItem> updateLessonItem(
    String workspaceId,
    String lessonId,
    String itemId,
    LessonItemChanges lessonItemChanges,
  ) async {
    final response = await client.invokeApi(
      method: Method.patch,
      path: '/v1/workspaces/{workspaceId}/lessons/{lessonId}/items/{itemId}'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{lessonId}', Uri.encodeComponent(lessonId))
          .replaceAll('{itemId}', Uri.encodeComponent(itemId)),
      body: lessonItemChanges.toJson(),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return LessonItem.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Every change to a lesson, oldest first
  /// For owners, and for tutors on the lesson.
  Future<HistoryList> getLessonHistory(
    String workspaceId,
    String lessonId,
  ) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/lessons/{lessonId}/history'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{lessonId}', Uri.encodeComponent(lessonId)),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return HistoryList.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Get a tutor's cancellation policy
  /// Any member may read it; it is shown to parents too. Tutors who have
  /// not set one have Penny's default: 24 hours' notice, late
  /// cancellations not billable, no-shows billable.
  Future<CancellationPolicy> getCancellationPolicy(
    String workspaceId,
    String memberId,
  ) async {
    final response = await client.invokeApi(
      method: Method.get,
      path:
          '/v1/workspaces/{workspaceId}/members/{memberId}/cancellation-policy'
              .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
              .replaceAll('{memberId}', Uri.encodeComponent(memberId)),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return CancellationPolicy.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Set a tutor's cancellation policy
  /// The tutor themselves, or the team owner (`manage_team`).
  Future<CancellationPolicy> setCancellationPolicy(
    String workspaceId,
    String memberId,
    CancellationPolicyInput cancellationPolicyInput,
  ) async {
    final response = await client.invokeApi(
      method: Method.put,
      path:
          '/v1/workspaces/{workspaceId}/members/{memberId}/cancellation-policy'
              .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
              .replaceAll('{memberId}', Uri.encodeComponent(memberId)),
      body: cancellationPolicyInput.toJson(),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return CancellationPolicy.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Book a recurring lesson
  /// Needs `manage_lessons`. A series is a rule (RFC 5545, evaluated in the
  /// team's timezone) plus the lesson it repeats. Every occurrence is its
  /// own lesson, booked ahead over a rolling horizon of 12 weeks, so each
  /// can carry its own notes, attendance and payment.
  Future<Series> createSeries(
    String workspaceId,
    SeriesInput seriesInput,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/series'.replaceAll(
        '{workspaceId}',
        Uri.encodeComponent(workspaceId),
      ),
      body: seriesInput.toJson(),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return Series.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Get a recurring lesson
  /// For owners, and for tutors on the series.
  Future<Series> getSeries(String workspaceId, String seriesId) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/series/{seriesId}'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{seriesId}', Uri.encodeComponent(seriesId)),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return Series.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Change a recurring lesson from a date onwards
  /// Needs `manage_lessons`; changing tutors also needs
  /// `reassign_lessons`. The change applies to scheduled lessons on and
  /// after `from` ("this and following"; send today for "all future
  /// lessons"). Earlier lessons, and lessons that are done or cancelled,
  /// are never rewritten. To change one lesson only, change the lesson.
  /// Send the series' `version` in `If-Match`.
  Future<Series> updateSeries(
    String workspaceId,
    String seriesId,
    String ifMatch,
    SeriesChanges seriesChanges,
  ) async {
    final response = await client.invokeApi(
      method: Method.patch,
      path: '/v1/workspaces/{workspaceId}/series/{seriesId}'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{seriesId}', Uri.encodeComponent(seriesId)),
      body: seriesChanges.toJson(),
      headerParameters: {'If-Match': ifMatch},
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return Series.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Stop a recurring lesson after a date
  /// Needs `manage_lessons`. Scheduled lessons after `after` are removed;
  /// lessons that are done, cancelled or have notes on them stay.
  Future<Series> endSeries(
    String workspaceId,
    String seriesId,
    String ifMatch,
    EndSeriesRequest endSeriesRequest,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/series/{seriesId}/end'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{seriesId}', Uri.encodeComponent(seriesId)),
      body: endSeriesRequest.toJson(),
      headerParameters: {'If-Match': ifMatch},
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return Series.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// The team timetable, one column per tutor
  /// Needs `view_team_timetable`. Every current owner and teacher gets a
  /// column, with or without lessons, so free time is visible. A lesson
  /// with several tutors appears in each of their columns.
  Future<Timetable> getTimetable(
    String workspaceId,
    DateTime from,
    DateTime to, {
    List<String>? teacherIds,
  }) async {
    teacherIds?.validate(maxItems: 50);

    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/timetable'.replaceAll(
        '{workspaceId}',
        Uri.encodeComponent(workspaceId),
      ),
      queryParameters: {
        'from': [from.toUtc().toIso8601String()],
        'to': [to.toUtc().toIso8601String()],
        if (teacherIds != null) 'teacherIds': [teacherIds.join(',')],
      },
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return Timetable.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Make a new private calendar link for a tutor
  /// The tutor themselves, or the team owner. Any earlier link for the
  /// tutor stops working. The link is shown once; Penny keeps only a hash
  /// of it.
  Future<CalendarFeed> createCalendarFeed(
    String workspaceId,
    String memberId,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/members/{memberId}/calendar-feed'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{memberId}', Uri.encodeComponent(memberId)),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return CalendarFeed.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Stop a tutor's calendar link working
  Future<void> revokeCalendarFeed(String workspaceId, String memberId) async {
    final response = await client.invokeApi(
      method: Method.delete,
      path: '/v1/workspaces/{workspaceId}/members/{memberId}/calendar-feed'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{memberId}', Uri.encodeComponent(memberId)),
      authRequest: const HttpAuth(
        scheme: 'bearer',
        secretName: 'firebaseIdToken',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }
  }

  /// A tutor's lessons as an iCalendar feed
  /// Public: the unguessable link is the credential. Lessons from 30 days
  /// ago to 180 days ahead, with students' first names and the place only,
  /// never notes or contacts.
  Future<String> getCalendarFeed(String token) async {
    token.validate(maxLength: 100);

    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/calendar/{token}'.replaceAll(
        '{token}',
        Uri.encodeComponent(token),
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Problem>(
        response.statusCode,
        response.body,
        body: Problem.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }

    if (response.body.isNotEmpty) {
      return response.body;
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }
}
