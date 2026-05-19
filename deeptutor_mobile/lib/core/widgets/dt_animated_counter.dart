import 'package:flutter/material.dart';

/// Animates an integer value from [begin] to [end] using a tween.
///
/// Renders the current value with [textStyle] via a [builder] so callers
/// can format it freely (e.g. add suffix, color partial text).
class DtAnimatedCounter extends StatefulWidget {
  const DtAnimatedCounter({
    super.key,
    required this.value,
    required this.textStyle,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
    this.suffix,
  });

  final int value;
  final TextStyle? textStyle;
  final Duration duration;
  final Curve curve;
  final String? suffix;

  @override
  State<DtAnimatedCounter> createState() => _DtAnimatedCounterState();
}

class _DtAnimatedCounterState extends State<DtAnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _tween;
  int _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _tween = Tween<double>(
      begin: 0,
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(parent: _ctrl, curve: widget.curve));
    _ctrl.forward();
    _oldValue = widget.value;
  }

  @override
  void didUpdateWidget(DtAnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _oldValue = old.value;
      _tween = Tween<double>(
        begin: _oldValue.toDouble(),
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(parent: _ctrl, curve: widget.curve));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _tween,
      builder: (_, __) {
        final display = _tween.value.round();
        return Text(
          widget.suffix != null ? '$display${widget.suffix}' : '$display',
          style: widget.textStyle,
        );
      },
    );
  }
}
