import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:penny_api/api_client.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/models/problem.dart';
import 'package:penny_api/models/server_version.dart';

/// Facts about the running server.
class SystemApi {
  SystemApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  /// Report the server's build version
  Future<ServerVersion> getVersion() async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/version',
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
      return ServerVersion.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }
}
