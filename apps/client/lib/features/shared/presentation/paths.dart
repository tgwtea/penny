/// Paths of the pages features link to. app/routes.dart routes the same
/// patterns; presentation may not import the app layer, so the links live
/// here.
abstract final class Paths {
  /// Today.
  static const today = '/today';

  /// Students.
  static const students = '/students';

  /// The team's saved places.
  static const places = '/places';

  /// One lesson.
  static String lesson(String id) => '/lessons/$id';

  /// One student.
  static String student(String id) => '/students/$id';
}
