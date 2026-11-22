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

  // Actions and objects.

  /// The signed-in person's account (user-circle).
  static const IconData account = IconData(
    0xe4c4,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Edit something (pencil-simple).
  static const IconData edit = IconData(
    0xe3b4,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Delete or remove (trash).
  static const IconData delete = IconData(
    0xe4a6,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Close a sheet, dialog or panel (x).
  static const IconData close = IconData(
    0xe4f6,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// More actions (dots-three).
  static const IconData more = IconData(
    0xe1fe,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Email (envelope-simple).
  static const IconData email = IconData(
    0xe218,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Copy to the clipboard (copy).
  static const IconData copy = IconData(
    0xe1ca,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// A link, such as a payment link (link-simple).
  static const IconData link = IconData(
    0xe2e6,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Send, such as a payment request (paper-plane-tilt).
  static const IconData send = IconData(
    0xe398,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// A receipt (receipt).
  static const IconData receipt = IconData(
    0xe3ec,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// A PayNow QR code (qr-code).
  static const IconData qrCode = IconData(
    0xe3e6,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// A recurring lesson series (repeat).
  static const IconData recurring = IconData(
    0xe3f6,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// A note on a lesson (note-pencil).
  static const IconData note = IconData(
    0xe34c,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// A done task on a lesson (check-square).
  static const IconData taskDone = IconData(
    0xe186,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// An open task on a lesson (square).
  static const IconData taskOpen = IconData(
    0xe45e,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// A goal (target).
  static const IconData goal = IconData(
    0xe47c,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// A phone number (phone).
  static const IconData phone = IconData(
    0xe3b8,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Add a lesson (calendar-plus).
  static const IconData addLesson = IconData(
    0xe714,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Download, such as a receipt PDF (download-simple).
  static const IconData download = IconData(
    0xe20c,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// A voided receipt (prohibit).
  static const IconData voided = IconData(
    0xe3de,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Settings (gear-six).
  static const IconData settings = IconData(
    0xe272,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Filter a list (funnel-simple).
  static const IconData filter = IconData(
    0xe268,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Collapse (caret-up).
  static const IconData chevronUp = IconData(
    0xe13c,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Opens outside Penny (arrow-square-out).
  static const IconData external = IconData(
    0xe5de,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Show a hidden value, such as a password (eye).
  static const IconData show = IconData(
    0xe220,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Hide a shown value (eye-slash).
  static const IconData hide = IconData(
    0xe224,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Add a teacher or student (user-plus).
  static const IconData addPerson = IconData(
    0xe4d0,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// A list view (list-bullets).
  static const IconData list = IconData(
    0xe2f2,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Waiting on someone, such as a confirmation (hourglass).
  static const IconData pending = IconData(
    0xe2b2,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Checked and confirmed, such as a payee account (shield-check).
  static const IconData verified = IconData(
    0xe40c,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// A bank or PayNow account (bank).
  static const IconData bank = IconData(
    0xe0b4,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// A payment (money).
  static const IconData money = IconData(
    0xe588,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// A reminder (bell).
  static const IconData reminder = IconData(
    0xe0ce,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Reminders turned off (bell-slash).
  static const IconData noReminder = IconData(
    0xe0d4,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// Go to the next step (arrow-right).
  static const IconData forward = IconData(
    0xe06c,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// An unselected option in a single-choice list (circle).
  static const IconData optionOff = IconData(
    0xe18a,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// The selected option in a single-choice list (radio-button).
  static const IconData optionOn = IconData(
    0xeb08,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// A late cancellation (clock-countdown).
  static const IconData lateCancel = IconData(
    0xed2c,
    fontFamily: _regular,
    fontPackage: _package,
  );

  /// A cancellation policy (handshake).
  static const IconData policy = IconData(
    0xe582,
    fontFamily: _regular,
    fontPackage: _package,
  );
}
