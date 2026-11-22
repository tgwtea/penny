import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:penny_api/api_client.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/messages/update_me_request.dart';
import 'package:penny_api/models/me.dart';
import 'package:penny_api/models/problem.dart';

/// The signed-in person and their teams.
class IdentityApi {
  IdentityApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  /// Get the signed-in person, their teams and what they may do in each
  /// The first call after signing in creates Penny's record of the person,
  /// keyed by their identity-provider ID. Later calls keep its email in
  /// step with the provider. The email address must be verified.
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

  /// Delete the signed-in person's account
  /// Removes the person's name and email and ends every membership. Lessons,
  /// payments and receipts that mention them keep pointing at the anonymised
  /// record, because those records must stay intact. Refused with 409 while
  /// the person is the only owner of a team that has other members: they
  /// must hand the team over first. The client deletes the identity-provider
  /// account afterwards.
  Future<void> deleteMe() async {
    final response = await client.invokeApi(
      method: Method.delete,
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
  }

  /// Change the signed-in person's name
  Future<Me> updateMe(UpdateMeRequest updateMeRequest) async {
    final response = await client.invokeApi(
      method: Method.patch,
      path: '/v1/me',
      body: updateMeRequest.toJson(),
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
