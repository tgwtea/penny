import 'package:penny_api/api.dart' as api;

import '../../../data/api_connection.dart';
import '../domain/data_export.dart';

/// Data exports against the real API: `GET /v1/me/export` and
/// `GET /v1/workspaces/{id}/students/{id}/export`.
class HttpPrivacyRepository implements PrivacyRepository {
  /// Creates a repository calling the API through [_api].
  HttpPrivacyRepository(this._api);

  final ApiConnection _api;

  @override
  Future<DataExport> myData() => _api.call((client) async {
    final e = await api.IdentityApi(client).exportMyData();
    return DataExport.of('Penny data', e.exportedAt, e.toJson());
  });

  @override
  Future<DataExport> studentData(String teamId, String studentId) =>
      _api.call((client) async {
        final e = await api.StudentsApi(
          client,
        ).exportStudentData(teamId, studentId);
        return DataExport.of(
          'Penny data for ${e.student.name}',
          e.exportedAt,
          e.toJson(),
        );
      });
}
