import 'package:flutter/widgets.dart';

/// Icon sizes from the brand book, "Iconography".
abstract final class PennyIconSize {
  /// Icons in rows and buttons.
  static const double standard = 20;

  /// Icons in navigation.
  static const double navigation = 24;

  /// Icons inside status badges.
  static const double badge = 14;
}

/// Every icon Penny uses: Phosphor Icons, Regular weight, with Fill only for
/// the active navigation item (ADR 020).
///
/// The Phosphor fonts are bundled with penny_ui (ADR 021). Feature code takes
/// icons from here, so the set stays one family at one weight. To add one,
/// find its code point in the `@phosphor-icons/web` release's
/// `src/regular/style.css` (`.ph-<name>:before`), and name the constant for
/// what it means, not what it shows.
abstract final class PennyIcons {
  static const _package = 'penny_ui';
  static const _regular = 'Phosphor';
  static const _fill = 'Phosphor Fill';

  // Navigation. Each has a Fill twin for the active state.

  /// Today (house).
  static const IconData today = IconData(
    0xe2c2,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Today, active navigation item.
  static const IconData todayActive = IconData(
    0xe2c2,
    fontFamily: _fill,
    fontPackage: _package,
  );

  /// Calendar (calendar-blank).
  static const IconData calendar = IconData(
    0xe10a,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Calendar, active navigation item.
  static const IconData calendarActive = IconData(
    0xe10a,
    fontFamily: _fill,
    fontPackage: _package,
  );

  /// Students (student).
  static const IconData students = IconData(
    0xe73e,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Students, active navigation item.
  static const IconData studentsActive = IconData(
    0xe73e,
    fontFamily: _fill,
    fontPackage: _package,
  );

  /// Payments (wallet).
  static const IconData payments = IconData(
    0xe68a,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Payments, active navigation item.
  static const IconData paymentsActive = IconData(
    0xe68a,
    fontFamily: _fill,
    fontPackage: _package,
  );

  /// Team (users-three).
  static const IconData team = IconData(
    0xe68e,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Team, active navigation item.
  static const IconData teamActive = IconData(
    0xe68e,
    fontFamily: _fill,
    fontPackage: _package,
  );

  // Statuses (see StatusBadge).

  /// Done, paid (check).
  static const IconData check = IconData(
    0xe182,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Cancelled (x).
  static const IconData cancelled = IconData(
    0xe4f6,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// No-show (user-minus).
  static const IconData noShow = IconData(
    0xe4ce,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Clash, overdue, warnings and errors (warning).
  static const IconData warning = IconData(
    0xe4e0,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Make-up lesson (arrow-counter-clockwise).
  static const IconData makeUp = IconData(
    0xe038,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Shared lesson, several tutors (users).
  static const IconData shared = IconData(
    0xe4d6,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Open payment request (clock).
  static const IconData open = IconData(
    0xe19a,
    fontFamily: _regular,
    fontPackage: _package,
  );

  // Meta lines and controls.

  /// An in-person location (map-pin).
  static const IconData location = IconData(
    0xe316,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// An online lesson (video-camera).
  static const IconData online = IconData(
    0xe4da,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Neutral information (info).
  static const IconData info = IconData(
    0xe2ce,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Previous period (caret-left). Mirrors in right-to-left text.
  static const IconData previous = IconData(
    0xe138,
    fontFamily: _regular,
    fontPackage: _package,
    matchTextDirection: true,
  );

  /// Next period (caret-right). Mirrors in right-to-left text.
  static const IconData next = IconData(
    0xe13a,
    fontFamily: _regular,
    fontPackage: _package,
    matchTextDirection: true,
  );

  /// Opens a menu (caret-down).
  static const IconData chevronDown = IconData(
    0xe136,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Add something (plus).
  static const IconData add = IconData(
    0xe3d4,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Search (magnifying-glass).
  static const IconData search = IconData(
    0xe30c,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Retry a failed load (arrow-clockwise).
  static const IconData retry = IconData(
    0xe036,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Restricted to another role (lock-simple).
  static const IconData locked = IconData(
    0xe308,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Go back (arrow-left). Mirrors in right-to-left text.
  static const IconData back = IconData(
    0xe058,
    fontFamily: _regular,
    fontPackage: _package,
    matchTextDirection: true,
  );

  /// Sign out (sign-out).
  static const IconData signOut = IconData(
    0xe42a,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Demo builds only, see DemoPersonaSwitcher (flask).
  static const IconData demo = IconData(
    0xe79e,
    fontFamily: _regular,
    fontPackage: _package,
  );
}
