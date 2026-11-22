import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:penny_api/api_client.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/messages/payment_request.dart';
import 'package:penny_api/messages/public_payment_request.dart';
import 'package:penny_api/models/billable_lesson_list.dart';
import 'package:penny_api/models/payee_account.dart';
import 'package:penny_api/models/payee_account_input.dart';
import 'package:penny_api/models/payment_input.dart';
import 'package:penny_api/models/payment_request_input.dart';
import 'package:penny_api/models/payment_request_list.dart';
import 'package:penny_api/models/payment_request_status.dart';
import 'package:penny_api/models/payment_request_with_link.dart';
import 'package:penny_api/models/problem.dart';
import 'package:penny_api/models/receipt.dart';
import 'package:penny_api/models/receipt_list.dart';
import 'package:penny_api/models/void_receipt_input.dart';

/// PayNow payment requests, payments and receipts. Penny never moves money.
class PaymentsApi {
  PaymentsApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  /// Where a tutor receives PayNow
  /// The tutor themselves, or an owner.
  Future<PayeeAccount> getPayeeAccount(
    String workspaceId,
    String memberId,
  ) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/members/{memberId}/payee-account'
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
      return PayeeAccount.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Set where a tutor receives PayNow
  /// The tutor themselves, or an owner. Changing the proxy clears
  /// `verified`: the tutor scans the new test code before any parent sees it.
  Future<PayeeAccount> setPayeeAccount(
    String workspaceId,
    String memberId,
    PayeeAccountInput payeeAccountInput,
  ) async {
    final response = await client.invokeApi(
      method: Method.put,
      path: '/v1/workspaces/{workspaceId}/members/{memberId}/payee-account'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{memberId}', Uri.encodeComponent(memberId)),
      body: payeeAccountInput.toJson(),
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
      return PayeeAccount.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Confirm the test code showed the right recipient
  /// The tutor scanned `testPayload` in their own banking app and saw their
  /// registered name. Only verified accounts can receive payment requests.
  Future<PayeeAccount> verifyPayeeAccount(
    String workspaceId,
    String memberId,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path:
          '/v1/workspaces/{workspaceId}/members/{memberId}/payee-account/verify'
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
      return PayeeAccount.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Billable lessons not yet on a payment request
  /// Done lessons, and no-shows and late cancellations the lead tutor's
  /// policy bills, that no open or paid request covers. Owners see every
  /// payee's; teachers only lessons they lead.
  Future<BillableLessonList> listBillableLessons(
    String workspaceId, {
    String? studentId,
    String? payeeId,
  }) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/billable-lessons'.replaceAll(
        '{workspaceId}',
        Uri.encodeComponent(workspaceId),
      ),
      queryParameters: {
        if (studentId != null) 'studentId': [studentId],
        if (payeeId != null) 'payeeId': [payeeId],
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
      return BillableLessonList.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// List payment requests
  /// Owners see every request; teachers those they are the payee of.
  Future<PaymentRequestList> listPaymentRequests(
    String workspaceId, {
    PaymentRequestStatus? status,
    String? studentId,
    String? cursor,
    int? limit = 100,
  }) async {
    cursor?.validate(maxLength: 200);
    limit?.validate(min: 1, max: 500);

    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/payment-requests'.replaceAll(
        '{workspaceId}',
        Uri.encodeComponent(workspaceId),
      ),
      queryParameters: {
        if (status != null) 'status': [status.toJson()],
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
      return PaymentRequestList.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Ask for payment
  /// Owners for any payee, teachers for themselves (ADR 024). The payee
  /// needs a verified PayNow account. Lesson lines take the lesson's fee and
  /// must be billable and led by the payee (ADR 018). If the payee sends
  /// automatically, the request is sent at once; otherwise it is a draft.
  Future<PaymentRequestWithLink> createPaymentRequest(
    String workspaceId,
    String idempotencyKey,
    PaymentRequestInput paymentRequestInput,
  ) async {
    idempotencyKey.validate(minLength: 8, maxLength: 100);

    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/payment-requests'.replaceAll(
        '{workspaceId}',
        Uri.encodeComponent(workspaceId),
      ),
      body: paymentRequestInput.toJson(),
      headerParameters: {'Idempotency-Key': idempotencyKey},
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
      return PaymentRequestWithLink.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Get a payment request with what it covers and its confirmations
  Future<PaymentRequest> getPaymentRequest(
    String workspaceId,
    String requestId,
  ) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/payment-requests/{requestId}'
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
      return PaymentRequest.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Send a draft, or send an open request again
  /// Emails the student's billing contacts a fresh link. Any earlier link
  /// stops working: Penny keeps only a hash of the current one.
  Future<PaymentRequestWithLink> sendPaymentRequest(
    String workspaceId,
    String requestId,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/payment-requests/{requestId}/send'
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
      return PaymentRequestWithLink.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Withdraw a request that is not paid
  /// Its link stops working and its lessons can be billed again.
  Future<PaymentRequest> cancelPaymentRequest(
    String workspaceId,
    String requestId,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/payment-requests/{requestId}/cancel'
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
      return PaymentRequest.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Confirm the money arrived
  /// The payee, or an owner, records what their bank shows. When the parent
  /// has confirmed too, the request is paid and the receipt is issued and
  /// emailed (ADR 024).
  Future<PaymentRequest> recordPayment(
    String workspaceId,
    String requestId,
    String idempotencyKey,
    PaymentInput paymentInput,
  ) async {
    idempotencyKey.validate(minLength: 8, maxLength: 100);

    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/payment-requests/{requestId}/payment'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{requestId}', Uri.encodeComponent(requestId)),
      body: paymentInput.toJson(),
      headerParameters: {'Idempotency-Key': idempotencyKey},
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
      return PaymentRequest.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// List receipts
  /// Owners see every receipt; teachers those they issued as payee.
  Future<ReceiptList> listReceipts(
    String workspaceId, {
    String? cursor,
    int? limit = 100,
  }) async {
    cursor?.validate(maxLength: 200);
    limit?.validate(min: 1, max: 500);

    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/receipts'.replaceAll(
        '{workspaceId}',
        Uri.encodeComponent(workspaceId),
      ),
      queryParameters: {
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
      return ReceiptList.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Get a receipt and everything it traces back to
  Future<Receipt> getReceipt(String workspaceId, String receiptId) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/receipts/{receiptId}'
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
      return Receipt.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// The receipt as a PDF
  /// Rendered the same way every time from the receipt's record; its SHA-256
  /// matches the receipt's `contentSha256`, so a copy can be shown to be
  /// unaltered.
  Future<Uint8List> getReceiptPdf(String workspaceId, String receiptId) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/receipts/{receiptId}/pdf'
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

  /// Void a receipt, optionally issuing a corrected one
  /// The payee or an owner. Receipts are never edited: a correction voids
  /// this one with a reason and issues a new one that references it.
  Future<Receipt> voidReceipt(
    String workspaceId,
    String receiptId,
    String idempotencyKey,
    VoidReceiptInput voidReceiptInput,
  ) async {
    idempotencyKey.validate(minLength: 8, maxLength: 100);

    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/receipts/{receiptId}/void'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{receiptId}', Uri.encodeComponent(receiptId)),
      body: voidReceiptInput.toJson(),
      headerParameters: {'Idempotency-Key': idempotencyKey},
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
      return Receipt.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// The public payment page's data
  /// Anyone with the link. Shows the payee, what is owed and the PayNow
  /// code, and no more about the student than a first name.
  Future<PublicPaymentRequest> getPublicPaymentRequest(String token) async {
    token.validate(maxLength: 100);

    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/pay/{token}'.replaceAll('{token}', Uri.encodeComponent(token)),
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
      return PublicPaymentRequest.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// The payer says they have paid
  /// Records the parent's confirmation and tells the payee. When the payee
  /// has confirmed the money too, the request is paid and the receipt is
  /// issued (ADR 024).
  Future<PublicPaymentRequest> confirmPaidByPayer(String token) async {
    token.validate(maxLength: 100);

    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/pay/{token}/paid'.replaceAll(
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
      return PublicPaymentRequest.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }
}
