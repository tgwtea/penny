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

  /// Payment requests.
  static const payments = '/payments';

  /// Receipts.
  static const receipts = '/receipts';

  /// The signed-in person's account.
  static const account = '/account';

  /// One lesson.
  static String lesson(String id) => '/lessons/$id';

  /// One student.
  static String student(String id) => '/students/$id';

  /// One payment request.
  static String paymentRequest(String id) => '/payments/$id';

  /// One receipt.
  static String receipt(String id) => '/receipts/$id';

  /// The payer's page for a link's [token].
  static String pay(String token) => '/pay/$token';
}
