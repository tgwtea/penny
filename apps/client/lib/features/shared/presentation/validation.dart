/// Checks people make on submit (TextField guideline: validate on blur and
/// on submit, never while typing). Each returns what to fix, or null.
library;

/// The longest name the API accepts for a person or a team.
const maxNameLength = 100;

/// Checks an email address.
String? emailProblem(String email) {
  final e = email.trim();
  if (e.isEmpty) return 'Enter an email address.';
  final at = e.indexOf('@');
  if (at < 1 ||
      at == e.length - 1 ||
      e.contains(' ') ||
      !e.substring(at + 1).contains('.')) {
    return 'Enter an email address like name@example.com.';
  }
  return null;
}

/// Checks a name, saying [missing] when there is none.
String? nameProblem(String name, {required String missing}) {
  final n = name.trim();
  if (n.isEmpty) return missing;
  if (n.length > maxNameLength) {
    return 'Use a name of at most $maxNameLength characters.';
  }
  return null;
}
