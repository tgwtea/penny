// Some OpenAPI specs flatten inline schemas into class names long
// enough that `dart format` can't keep imports and call sites under
// 80 cols as bare identifiers.
// ignore_for_file: lines_longer_than_80_chars
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:penny_api/api_client.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/models/contact.dart';
import 'package:penny_api/models/contact_input.dart';
import 'package:penny_api/models/contact_sign_in_input.dart';
import 'package:penny_api/models/goal.dart';
import 'package:penny_api/models/goal_changes.dart';
import 'package:penny_api/models/goal_input.dart';
import 'package:penny_api/models/problem.dart';
import 'package:penny_api/models/student.dart';
import 'package:penny_api/models/student_changes.dart';
import 'package:penny_api/models/student_data_export.dart';
import 'package:penny_api/models/student_input.dart';
import 'package:penny_api/models/student_list.dart';
import 'package:penny_api/models/student_sign_in_input.dart';

/// Students, the people who get their reminders and receipts, and their goals.
class StudentsApi {
  StudentsApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  /// List students
  /// Owners (`manage_students`) see every student; teachers
  /// (`view_own_students`) see students they are the primary teacher of
  /// or teach in a lesson.
  Future<StudentList> listStudents(
    String workspaceId, {
    String? search,
    String? teacherId,
    bool? archived = false,
    String? cursor,
    int? limit = 100,
  }) async {
    search?.validate(maxLength: 100);
    cursor?.validate(maxLength: 200);
    limit?.validate(min: 1, max: 500);

    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/students'.replaceAll(
        '{workspaceId}',
        Uri.encodeComponent(workspaceId),
      ),
      queryParameters: {
        if (search != null) 'search': [search],
        if (teacherId != null) 'teacherId': [teacherId],
        if (archived != null) 'archived': [archived.toString()],
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
      return StudentList.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Add a student
  /// Needs `manage_students`.
  Future<Student> createStudent(
    String workspaceId,
    StudentInput studentInput,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/students'.replaceAll(
        '{workspaceId}',
        Uri.encodeComponent(workspaceId),
      ),
      body: studentInput.toJson(),
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
      return Student.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Get a student with their contacts and goals
  Future<Student> getStudent(String workspaceId, String studentId) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/students/{studentId}'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{studentId}', Uri.encodeComponent(studentId)),
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
      return Student.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Change a student, or archive or restore them
  /// Needs `manage_students`. Archived students keep their lessons and
  /// receipts but are not offered for new lessons.
  Future<Student> updateStudent(
    String workspaceId,
    String studentId,
    StudentChanges studentChanges,
  ) async {
    final response = await client.invokeApi(
      method: Method.patch,
      path: '/v1/workspaces/{workspaceId}/students/{studentId}'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{studentId}', Uri.encodeComponent(studentId)),
      body: studentChanges.toJson(),
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
      return Student.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Download everything the team holds about a student
  /// For a PDPA access request from a student or their family, for the
  /// owner to review before passing on: the student with their contacts
  /// and goals, every lesson they are in with its tasks, goals and notes,
  /// and every payment request and receipt. Owners only, since it spans
  /// every tutor's notes. Each export is written to the audit log.
  Future<StudentDataExport> exportStudentData(
    String workspaceId,
    String studentId,
  ) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/students/{studentId}/export'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{studentId}', Uri.encodeComponent(studentId)),
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
      return StudentDataExport.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Give the student their own account, at an email address
  /// Owners only (ADR 025). Penny invites the address to the team as a
  /// student, who then sees their own lessons, read-only, after they
  /// first sign in with it. A new address replaces the old one.
  Future<Student> setStudentSignIn(
    String workspaceId,
    String studentId,
    StudentSignInInput studentSignInInput,
  ) async {
    final response = await client.invokeApi(
      method: Method.put,
      path: '/v1/workspaces/{workspaceId}/students/{studentId}/sign-in'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{studentId}', Uri.encodeComponent(studentId)),
      body: studentSignInInput.toJson(),
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
      return Student.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Take the student's account away
  Future<Student> removeStudentSignIn(
    String workspaceId,
    String studentId,
  ) async {
    final response = await client.invokeApi(
      method: Method.delete,
      path: '/v1/workspaces/{workspaceId}/students/{studentId}/sign-in'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{studentId}', Uri.encodeComponent(studentId)),
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
      return Student.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Add someone who gets a student's reminders or receipts
  /// Needs `manage_students`.
  Future<Contact> addContact(
    String workspaceId,
    String studentId,
    ContactInput contactInput,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/students/{studentId}/contacts'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{studentId}', Uri.encodeComponent(studentId)),
      body: contactInput.toJson(),
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
      return Contact.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Change a contact
  /// Needs `manage_students`.
  Future<Contact> updateContact(
    String workspaceId,
    String studentId,
    String contactId,
    ContactInput contactInput,
  ) async {
    final response = await client.invokeApi(
      method: Method.put,
      path:
          '/v1/workspaces/{workspaceId}/students/{studentId}/contacts/{contactId}'
              .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
              .replaceAll('{studentId}', Uri.encodeComponent(studentId))
              .replaceAll('{contactId}', Uri.encodeComponent(contactId)),
      body: contactInput.toJson(),
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
      return Contact.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Remove a contact
  /// Needs `manage_students`.
  Future<void> removeContact(
    String workspaceId,
    String studentId,
    String contactId,
  ) async {
    final response = await client.invokeApi(
      method: Method.delete,
      path:
          '/v1/workspaces/{workspaceId}/students/{studentId}/contacts/{contactId}'
              .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
              .replaceAll('{studentId}', Uri.encodeComponent(studentId))
              .replaceAll('{contactId}', Uri.encodeComponent(contactId)),
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

  /// Give a contact a parent account, or take it away
  /// Owners only (ADR 025). Giving access invites the contact's email to
  /// the team as a parent, who after first signing in sees this student's
  /// lessons and payments, read-only. One account covers all of a
  /// parent's children in the team. A contact who can sign in keeps their
  /// email until access is taken away.
  Future<Contact> setContactSignIn(
    String workspaceId,
    String studentId,
    String contactId,
    ContactSignInInput contactSignInInput,
  ) async {
    final response = await client.invokeApi(
      method: Method.put,
      path:
          '/v1/workspaces/{workspaceId}/students/{studentId}/contacts/{contactId}/sign-in'
              .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
              .replaceAll('{studentId}', Uri.encodeComponent(studentId))
              .replaceAll('{contactId}', Uri.encodeComponent(contactId)),
      body: contactSignInInput.toJson(),
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
      return Contact.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Set a goal that spans lessons
  /// Needs `manage_students`, or to teach the student.
  Future<Goal> addGoal(
    String workspaceId,
    String studentId,
    GoalInput goalInput,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/students/{studentId}/goals'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{studentId}', Uri.encodeComponent(studentId)),
      body: goalInput.toJson(),
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
      return Goal.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Rename a goal, or mark it achieved or dropped
  /// Needs `manage_students`, or to teach the student.
  Future<Goal> updateGoal(
    String workspaceId,
    String studentId,
    String goalId,
    GoalChanges goalChanges,
  ) async {
    final response = await client.invokeApi(
      method: Method.patch,
      path: '/v1/workspaces/{workspaceId}/students/{studentId}/goals/{goalId}'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{studentId}', Uri.encodeComponent(studentId))
          .replaceAll('{goalId}', Uri.encodeComponent(goalId)),
      body: goalChanges.toJson(),
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
      return Goal.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }
}
