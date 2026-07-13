import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A thin [Focus] layer wrapping a [TextField] (or any single-line text
/// input). In an Android TV / D-pad context the vertical arrow keys
/// (UP/DOWN) are turned into focus traversal before they reach the
/// [EditableText], so fields can be navigated with the remote.
///
/// Why it's needed: in Flutter EditableText consumes the arrow keys itself
/// for caret movement. In a single-line field vertical movement has no
/// meaning, so the event counts as "handled" but does nothing; the focus
/// ends up stuck in the same field and the remote can't reach the next one.
///
/// Solution: vertical axis = focus change, horizontal axis = caret movement.
/// LEFT/RIGHT keys are left to the [TextField] (cursor movement within text).
class DpadTextField extends StatelessWidget {
  const DpadTextField({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      // This wrapper must NOT be a stop in traversal; it only exists to
      // filter the keys going down to the child. canRequestFocus=false →
      // the TextField's own FocusNode takes focus, the wrapper stays transparent.
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        switch (event.logicalKey) {
          case LogicalKeyboardKey.arrowDown:
            return node.focusInDirection(TraversalDirection.down)
                ? KeyEventResult.handled
                : KeyEventResult.ignored;
          case LogicalKeyboardKey.arrowUp:
            return node.focusInDirection(TraversalDirection.up)
                ? KeyEventResult.handled
                : KeyEventResult.ignored;
          default:
            // LEFT/RIGHT and other keys go to the TextField (caret/text).
            return KeyEventResult.ignored;
        }
      },
      child: child,
    );
  }
}
