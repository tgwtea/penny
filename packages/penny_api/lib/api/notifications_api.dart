import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:penny_api/api_client.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/messages/unsubscribe_request.dart';
import 'package:penny_api/models/problem.dart';
import 'package:penny_api/models/unsubscribe_1.dart';

/// The emails Penny sends, and how people stop them.
class NotificationsApi {
  NotificationsApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  /// Say what an unsubscribe link would stop, without stopping it
  /// Public: the signed link is the credential. Opening a link changes
  /// nothing, so mail scanners that follow links cannot unsubscribe
  /// anyone; the page asks, then POSTs.
  Future<Unsubscribe1> describeUnsubscribe(String token) async {
    token.validate(maxLength: 500);

    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/unsubscribe/{token}'.replaceAll(
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
      return Unsubscribe1.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Stop one kind of email for one contact
  /// Public, and also the RFC 8058 one-click target in each email's
  /// List-Unsubscribe header. Receipts cannot be stopped: they are the
  /// record of a payment.
  Future<Unsubscribe1> unsubscribe(
    String token, {
    UnsubscribeRequest? unsubscribeRequest,
  }) async {
    token.validate(maxLength: 500);

    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/unsubscribe/{token}'.replaceAll(
        '{token}',
        Uri.encodeComponent(token),
      ),
      body: <String, String>{
        if (unsubscribeRequest?.listUnsubscribe case final value?)
          'List-Unsubscribe': value,
      },
      bodyContentType: BodyContentType.formUrlEncoded,
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
      return Unsubscribe1.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }
}
