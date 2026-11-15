import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:penny_api/api_client.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/models/me.dart';
import 'package:penny_api/models/problem.dart';

/// The signed-in person and their teams.
class IdentityApi {
  IdentityApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  /// Get the signed-in person, their teams and what they may do in each
  Future<Me> getMe() async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/me',
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
      return Me.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }
}
