import 'package:flutter/material.dart';

import '../foundation/icons.dart';
import '../foundation/pressable.dart';
import '../tokens.g.dart';
import 'avatar.dart';

/// One place the main navigation can go. The bottom navigation and the
/// sidebar show the same destinations, filtered by what the person may see.
@immutable
class PennyDestination {
  /// Creates a destination.
  const PennyDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.count,
  });

  /// One word: "Today".
  final String label;

  /// Regular-weight icon.
  final IconData icon;

  /// Fill-weight icon, shown when this destination is active.
  final IconData activeIcon;

  /// A short count shown in the sidebar only, such as "3 overdue". Never a
  /// coloured dot.
  final String? count;
}

/// Main navigation on phone (under 600 px).
class PennyBottomNav extends StatelessWidget {
  /// Creates a bottom navigation bar.
  const PennyBottomNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// The destinations the session's capabilities allow, in order.
  final List<PennyDestination> destinations;

  /// The active destination, or -1 when none is (for example on a detail
  /// page reached from elsewhere).
  final int selectedIndex;

  /// Called with the index of the tapped destination.
  final ValueChanged<int> onSelected;

  static const double _pillWidth = 56;
  static const double _pillHeight = 32;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: PennySize.bottomNavHeight,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _item(
                    c,
                    destinations[i],
                    i == selectedIndex,
                    () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
    PennyColors c,
    PennyDestination d,
    bool active,
    VoidCallback onTap,
  ) {
    return PennyPressable(
      onPressed: onTap,
      contentColor: c.text,
      selected: active,
      borderRadius: BorderRadius.circular(PennyRadius.md),
      child: SizedBox(
        height: PennySize.bottomNavHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: _pillWidth,
              height: _pillHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? c.inkSubtle : Colors.transparent,
                borderRadius: BorderRadius.circular(PennyRadius.full),
              ),
              child: Icon(
                active ? d.activeIcon : d.icon,
                size: PennyIconSize.navigation,
                color: active ? c.text : c.textSecondary,
              ),
            ),
            const SizedBox(height: PennySpace.s1),
            Text(
              d.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PennyText.caption.copyWith(
                color: active ? c.text : c.textSecondary,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Main navigation from 600 px wide: the team at the top, destinations, and
/// the signed-in person at the bottom.
class PennySidebar extends StatelessWidget {
  /// Creates a sidebar.
  const PennySidebar({
    super.key,
    required this.teamName,
    required this.roleLabel,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.personName,
    this.onSwitchTeam,
    this.onOpenAccount,
    this.footer,
  });

  /// The active team's name.
  final String teamName;

  /// The person's role in it, in words: "Owner", "Teacher".
  final String roleLabel;

  /// The destinations the session's capabilities allow, in order.
  final List<PennyDestination> destinations;

  /// The active destination, or -1.
  final int selectedIndex;

  /// Called with the index of the chosen destination.
  final ValueChanged<int> onSelected;

  /// The signed-in person's name.
  final String personName;

  /// Opens the team menu. Null when the person belongs to one team only,
  /// which also hides the chevron.
  final VoidCallback? onSwitchTeam;

  /// Opens account settings.
  final VoidCallback? onOpenAccount;

  /// Pinned at the very bottom; the demo build puts its persona switcher here.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return Container(
      width: PennySize.sidebarWidth,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.hairline)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(PennySpace.s3),
              child: _teamSwitcher(c),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: PennySpace.s3),
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    _item(
                      c,
                      destinations[i],
                      i == selectedIndex,
                      () => onSelected(i),
                    ),
                ],
              ),
            ),
            Divider(color: c.hairline, height: 1),
            Padding(
              padding: const EdgeInsets.all(PennySpace.s3),
              child: _person(c),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PennySpace.s3,
                  0,
                  PennySpace.s3,
                  PennySpace.s3,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }

  Widget _teamSwitcher(PennyColors c) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PennySpace.s2,
        vertical: PennySpace.s2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teamName,
                  style: PennyText.bodyStrong.copyWith(color: c.text),
                  maxLines: 2,
                ),
                Text(
                  roleLabel,
                  style: PennyText.small.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          if (onSwitchTeam != null)
            Icon(
              PennyIcons.chevronDown,
              size: PennyIconSize.standard,
              color: c.textSecondary,
            ),
        ],
      ),
    );
    if (onSwitchTeam == null) return content;
    return PennyPressable(
      onPressed: onSwitchTeam,
      contentColor: c.text,
      child: content,
    );
  }

  Widget _item(
    PennyColors c,
    PennyDestination d,
    bool active,
    VoidCallback onTap,
  ) {
    return PennyPressable(
      onPressed: onTap,
      contentColor: c.text,
      selected: active,
      child: Container(
        constraints: const BoxConstraints(minHeight: PennySize.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: PennySpace.s3),
        decoration: BoxDecoration(
          color: active ? c.inkSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(PennyRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              active ? d.activeIcon : d.icon,
              size: PennyIconSize.standard,
              color: active ? c.text : c.textSecondary,
            ),
            const SizedBox(width: PennySpace.s3),
            Expanded(
              child: Text(
                d.label,
                style: PennyText.body.copyWith(
                  color: c.text,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (d.count != null)
              Text(
                d.count!,
                style: PennyText.small.copyWith(color: c.textTertiary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _person(PennyColors c) {
    final content = Padding(
      padding: const EdgeInsets.all(PennySpace.s1),
      child: Row(
        children: [
          PennyAvatar(name: personName, size: PennyAvatarSize.medium),
          const SizedBox(width: PennySpace.s3),
          Expanded(
            child: Text(
              personName,
              style: PennyText.body.copyWith(color: c.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    if (onOpenAccount == null) return content;
    return PennyPressable(
      onPressed: onOpenAccount,
      contentColor: c.text,
      child: content,
    );
  }
}

/// The top bar on phone: the screen title and the account avatar.
class PennyTopBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a top bar.
  const PennyTopBar({
    super.key,
    required this.title,
    required this.personName,
    this.onOpenAccount,
    this.leading,
    this.trailing,
  });

  /// The screen title.
  final String title;

  /// The signed-in person, shown as the account avatar.
  final String personName;

  /// Opens account settings.
  final VoidCallback? onOpenAccount;

  /// Shown before the title, such as a back button.
  final Widget? leading;

  /// Shown before the avatar, such as the demo persona chip.
  final Widget? trailing;

  static const double _height = 56;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return Material(
      color: c.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: _height,
          padding: const EdgeInsets.only(
            left: PennySpace.s4,
            right: PennySpace.s2,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.hairline)),
          ),
          child: Row(
            children: [
              ?leading,
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: PennyText.title.copyWith(color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              ?trailing,
              PennyPressable(
                onPressed: onOpenAccount,
                contentColor: c.text,
                semanticLabel: 'Account: $personName',
                borderRadius: BorderRadius.circular(PennyRadius.full),
                child: PennyAvatar(
                  name: personName,
                  size: PennyAvatarSize.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
