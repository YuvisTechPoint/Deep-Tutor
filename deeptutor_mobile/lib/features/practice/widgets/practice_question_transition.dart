import 'package:flutter/material.dart';

import '../../../core/theme/app_animations.dart';
import '../../../core/widgets/flip_transition.dart';
import '../../../data/models/practice.dart';
import 'practice_question_card.dart';

/// Wraps [PracticeQuestionCard] with flip/slide transitions when [questionKey] changes.
class PracticeQuestionTransition extends StatefulWidget {
  const PracticeQuestionTransition({
    super.key,
    required this.questionKey,
    required this.question,
    required this.selectedIndex,
    required this.hint,
    required this.onOptionSelected,
    required this.onHintRequested,
    this.forward = true,
  });

  final Object questionKey;
  final PracticeQuestion question;
  final int? selectedIndex;
  final String? hint;
  final ValueChanged<int> onOptionSelected;
  final VoidCallback onHintRequested;
  final bool forward;

  @override
  State<PracticeQuestionTransition> createState() =>
      _PracticeQuestionTransitionState();
}

class _PracticeQuestionTransitionState
    extends State<PracticeQuestionTransition> {
  bool _forward = true;

  @override
  void didUpdateWidget(PracticeQuestionTransition old) {
    super.didUpdateWidget(old);
    if (old.questionKey != widget.questionKey) {
      _forward = widget.forward;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppAnimations.medium,
      switchInCurve: AppAnimations.enter,
      switchOutCurve: AppAnimations.exit,
      transitionBuilder: (child, animation) {
        if (animation.status == AnimationStatus.reverse) {
          return SlideQuestionTransition(
            animation: animation,
            forward: !_forward,
            child: child,
          );
        }
        return FlipTransition(animation: animation, child: child);
      },
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [
          if (previous != null) ...previous,
          if (current != null) current,
        ],
      ),
      child: PracticeQuestionCard(
        key: ValueKey(widget.questionKey),
        question: widget.question,
        selectedIndex: widget.selectedIndex,
        hint: widget.hint,
        onOptionSelected: widget.onOptionSelected,
        onHintRequested: widget.onHintRequested,
      ),
    );
  }
}
