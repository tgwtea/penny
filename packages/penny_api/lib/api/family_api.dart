// Some OpenAPI specs flatten inline schemas into class names long
// enough that `dart format` can't keep imports and call sites under
// 80 cols as bare identifiers.
// ignore_for_file: lines_longer_than_80_chars
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:penny_api/api_client.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/messages/family_payment_request.dart';
import 'package:penny_api/models/family_lesson_list.dart';
import 'package:penny_api/models/family_payment_request_list.dart';
import 'package:penny_api/models/family_student_list.dart';
import 'package:penny_api/models/problem.dart';
import 'package:penny_api/models/receipt_list.dart';

/// What a signed-in student or parent sees of their own lessons and payments,
/// read-only (ADR 025).
class FamilyApi {
  FamilyApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  /// The students a family account is linked to
  /// A student sees themselves; a parent sees their children in the team.
  Future<FamilyStudentList> listFamilyStudents(String workspaceId) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/family/students'.replaceAll(
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
      return FamilyStudentList.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// The linked students' lessons in a range
  /// Read-only. Other students in a group lesson are counted, not named,
  /// and only items meant for the caller are included (ADR 025).
  Future<FamilyLessonList> listFamilyLessons(
    String workspaceId,
    DateTime from,
    DateTime to,
  ) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/family/lessons'.replaceAll(
        '{workspaceId}',
        Uri.encodeComponent(workspaceId),
      ),
      queryParameters: {
        'from': [from.toUtc().toIso8601String()],
        'to': [to.toUtc().toIso8601String()],
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
      return FamilyLessonList.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// A parent's open and paid payment requests
  /// What each request's payment page shows, with its PayNow code while
  /// open, for the parent's children. Newest first.
  Future<FamilyPaymentRequestList> listFamilyPaymentRequests(
    String workspaceId,
  ) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/family/payment-requests'.replaceAll(
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
      return FamilyPaymentRequestList.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Say "I've paid" as a signed-in parent
  /// The payer's confirmation (ADR 024), exactly as the payment page records
  /// it.
  Future<FamilyPaymentRequest> confirmFamilyPayment(
    String workspaceId,
    String requestId,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path:
          '/v1/workspaces/{workspaceId}/family/payment-requests/{requestId}/paid'
              .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
              .replaceAll('{requestId}', Uri.encodeComponent(requestId)),
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
      return FamilyPaymentRequest.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// A parent's receipts, newest first
  Future<ReceiptList> listFamilyReceipts(String workspaceId) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/family/receipts'.replaceAll(
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
      return ReceiptList.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// One of a parent's receipts as a PDF
  Future<Uint8List> getFamilyReceiptPdf(
    String workspaceId,
    String receiptId,
  ) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/family/receipts/{receiptId}/pdf'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{receiptId}', Uri.encodeComponent(receiptId)),
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
      return response.bodyBytes;
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }
}
