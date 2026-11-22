import 'package:penny_api/api.dart';

class Penny {
  Penny({ApiClient? client}) : client = client ?? ApiClient();

  final ApiClient client;

  HealthApi get health => HealthApi(client);
  IdentityApi get identity => IdentityApi(client);
  LessonsApi get lessons => LessonsApi(client);
  StudentsApi get students => StudentsApi(client);
  SystemApi get system => SystemApi(client);
  TeamsApi get teams => TeamsApi(client);
}
