import 'package:flutter/material.dart';

import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// List tile with a spring-scale celebration when [completed] flips to true.
class SpringCheckTile extends StatefulWidget {
  const SpringCheckTile({
    super.key,
    required this.title,
    required this.completed,
    required this.onToggle,
    this.subtitle,
    this.leadingLabel,
  });

  final String title;
  final String? subtitle;
  final String? leadingLabel;
  final bool completed;
  final ValueChanged<bool> onToggle;

  @override
  State<SpringCheckTile> createState() => _SpringCheckTileState();
}

class _SpringCheckTileState extends State<SpringCheckTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  late final Animation<double> _scale;
  bool _wasCompleted = false;

  @override
  void initState() {
    super.initState();
    _wasCompleted = widget.completed;
    _bounce = AnimationController(
      vsync: this,
      duration: AppAnimations.medium,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _bounce, curve: AppAnimations.spring));
  }

  @override
  void didUpdateWidget(SpringCheckTile old) {
    super.didUpdateWidget(old);
    if (widget.completed && !_wasCompleted) {
      _bounce.forward(from: 0);
    }
    _wasCompleted = widget.completed;
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: ListTile(
        leading: ScaleTransition(
          scale: _scale,
          child: CircleAvatar(
            backgroundColor: widget.completed
                ? AppColors.success.withValues(alpha: 0.2)
                : cs.primaryContainer,
            child: widget.completed
                ? const Icon(Icons.check_rounded, color: AppColors.success)
                : Text(
                    widget.leadingLabel ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
          ),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            decoration:
                widget.completed ? TextDecoration.lineThrough : null,
            color: widget.completed
                ? cs.onSurface.withValues(alpha: 0.55)
                : null,
          ),
        ),
        subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
        trailing: Switch(
          value: widget.completed,
          onChanged: widget.onToggle,
        ),
      ),
    );
  }
}
