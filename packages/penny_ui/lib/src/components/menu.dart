// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/icons.dart';
import '../tokens.g.dart';
import 'button.dart';

/// One action in a PennyMenuButton's menu.
@immutable
class PennyMenuItem {
  /// Creates an item.
  const PennyMenuItem({
    required this.label,
    required this.onSelected,
    this.icon,
    this.destructive = false,
  });

  /// What happens: "Remove from team".
  final String label;

  /// Runs the action.
  final VoidCallback onSelected;

  /// An icon beside the label.
  final IconData? icon;

  /// Whether the action removes or ends something; shown in `danger`.
  final bool destructive;
}

/// An icon button that opens a short menu of actions on one thing, such as
/// a team member. The menu floats on `surface-float`. Destructive items
/// still confirm what will happen before acting.
class PennyMenuButton extends StatelessWidget {
  /// Creates a menu button.
  const PennyMenuButton({
    super.key,
    required this.tooltip,
    required this.items,
    this.icon = PennyIcons.more,
  });

  /// Names the button for assistive technology: "Actions for Mei Lin Tan".
  final String tooltip;

  /// The actions, in order.
  final List<PennyMenuItem> items;

  /// The button's icon.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PennyIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: items.isEmpty ? null : () => _open(context),
    );
  }

  Future<void> _open(BuildContext context) async {
    final c = PennyColors.of(context);
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final chosen = await showMenu<int>(
      context: context,
      position: position,
      items: [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                if (items[i].icon != null) ...[
                  Icon(
                    items[i].icon,
                    size: PennyIconSize.standard,
                    color: items[i].destructive ? c.danger : c.textSecondary,
                  ),
                  const SizedBox(width: PennySpace.s3),
                ],
                Text(
                  items[i].label,
                  style: PennyText.body.copyWith(
                    color: items[i].destructive ? c.danger : c.text,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (chosen != null) items[chosen].onSelected();
  }
}
