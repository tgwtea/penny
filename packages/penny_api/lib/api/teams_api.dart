import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:penny_api/api_client.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/messages/add_member_request.dart';
import 'package:penny_api/messages/create_workspace_request.dart';
import 'package:penny_api/messages/update_member_request.dart';
import 'package:penny_api/messages/update_workspace_request.dart';
import 'package:penny_api/models/member.dart';
import 'package:penny_api/models/member_list.dart';
import 'package:penny_api/models/membership.dart';
import 'package:penny_api/models/problem.dart';
import 'package:penny_api/models/workspace.dart';

/// Teams, their members and roles. The UI says "Team"; the API says workspace.
class TeamsApi {
  TeamsApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  /// Create a team with the caller as its owner
  /// Onboarding's "Do you teach on your own, or run a team?" creates one
  /// either way: a solo tutor gets a team of one, which hides every team
  /// feature until someone else joins.
  Future<Membership> createWorkspace(
    CreateWorkspaceRequest createWorkspaceRequest,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces',
      body: createWorkspaceRequest.toJson(),
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
      return Membership.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Get a team the caller belongs to
  Future<Workspace> getWorkspace(String workspaceId) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}'.replaceAll(
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
      return Workspace.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Rename a team or change its timezone
  /// Needs `manage_team`.
  Future<Workspace> updateWorkspace(
    String workspaceId,
    UpdateWorkspaceRequest updateWorkspaceRequest,
  ) async {
    final response = await client.invokeApi(
      method: Method.patch,
      path: '/v1/workspaces/{workspaceId}'.replaceAll(
        '{workspaceId}',
        Uri.encodeComponent(workspaceId),
      ),
      body: updateWorkspaceRequest.toJson(),
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
      return Workspace.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// List the team's members and pending invitations
  /// Needs `manage_team`. A team has tens of members at most, so the
  /// whole list comes in one page; `nextCursor` is never set.
  Future<MemberList> listMembers(String workspaceId) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/v1/workspaces/{workspaceId}/members'.replaceAll(
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
      return MemberList.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Add a teacher by email
  /// Needs `manage_team`. The member is `invited` until someone signs in
  /// with that verified email address, which makes them `active`.
  /// Refused with 409 if the email already belongs to a member.
  Future<Member> addMember(
    String workspaceId,
    AddMemberRequest addMemberRequest,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/v1/workspaces/{workspaceId}/members'.replaceAll(
        '{workspaceId}',
        Uri.encodeComponent(workspaceId),
      ),
      body: addMemberRequest.toJson(),
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
      return Member.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  /// Remove a member or withdraw an invitation
  /// Needs `manage_team`. The member's past lessons and receipts keep
  /// pointing at them. Refused with 409 for the team's last owner.
  Future<void> removeMember(String workspaceId, String memberId) async {
    final response = await client.invokeApi(
      method: Method.delete,
      path: '/v1/workspaces/{workspaceId}/members/{memberId}'
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

  /// Change a member's role
  /// Needs `manage_team`. Refused with 409 if it would leave the team
  /// without an owner.
  Future<Member> updateMember(
    String workspaceId,
    String memberId,
    UpdateMemberRequest updateMemberRequest,
  ) async {
    final response = await client.invokeApi(
      method: Method.patch,
      path: '/v1/workspaces/{workspaceId}/members/{memberId}'
          .replaceAll('{workspaceId}', Uri.encodeComponent(workspaceId))
          .replaceAll('{memberId}', Uri.encodeComponent(memberId)),
      body: updateMemberRequest.toJson(),
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
      return Member.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }
}
