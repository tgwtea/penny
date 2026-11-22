/// Penny's design system: tokens, theme and components (ADR 016, ADR 020).
///
/// Feature code builds screens from these widgets, `Theme.of(context)` and
/// the token classes. Raw colours, literal spacing and literal font sizes
/// belong here, never in an app (`tools/checks` enforces it).
library;

export 'src/components/avatar.dart';
export 'src/components/button.dart';
export 'src/components/check_row.dart';
export 'src/components/chips.dart';
export 'src/components/date_navigator.dart';
export 'src/components/demo_chip.dart';
export 'src/components/dialog.dart';
export 'src/components/divider.dart';
export 'src/components/empty_state.dart';
export 'src/components/lesson/lesson_block.dart';
export 'src/components/lesson/lesson_row.dart';
export 'src/components/lesson/lesson_view.dart';
export 'src/components/lesson/month_grid.dart';
export 'src/components/lesson/now_line.dart';
export 'src/components/lesson/timetable.dart';
export 'src/components/list_row.dart';
export 'src/components/menu.dart';
export 'src/components/navigation.dart';
export 'src/components/notice.dart';
export 'src/components/option_row.dart';
export 'src/components/page.dart';
export 'src/components/pixel_art.dart';
export 'src/components/section_header.dart';
export 'src/components/segmented.dart';
export 'src/components/select_field.dart';
export 'src/components/sheet.dart';
export 'src/components/skeleton.dart';
export 'src/components/snackbar.dart';
export 'src/components/status_badge.dart';
export 'src/components/text_field.dart';
export 'src/components/toggle_row.dart';
export 'src/foundation/format.dart';
export 'src/foundation/icons.dart';
export 'src/foundation/layout.dart';
export 'src/foundation/motion.dart';
export 'src/foundation/pressable.dart';
export 'src/foundation/theme.dart';
export 'src/tokens.g.dart';
