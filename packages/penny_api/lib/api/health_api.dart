import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:penny_api/api_client.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/models/health.dart';

/// Probes for Kubernetes and uptime checks.
class HealthApi {
  HealthApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  /// Report that the process is running
  /// Succeeds whenever the process can serve HTTP. It never checks
  /// dependencies, so a database outage does not restart every pod.
  Future<Health> getLivez() async {
    final response = await client.invokeApi(method: Method.get, path: '/livez');

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(response.statusCode, response.body);
    }

    if (response.body.isNotEmpty) {
      return Health.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Report whether the server can take traffic
  /// Succeeds when the database is reachable and its schema is at the version
  /// this build expects. Kubernetes stops routing to a pod that fails it.
  Future<Health> getReadyz() async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/readyz',
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(response.statusCode, response.body);
    }

    if (response.body.isNotEmpty) {
      return Health.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }
}
