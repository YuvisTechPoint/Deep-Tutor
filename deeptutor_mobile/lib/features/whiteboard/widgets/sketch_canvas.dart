import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Simple freehand sketch pad for the whiteboard tutor screen.
class SketchCanvas extends StatefulWidget {
  const SketchCanvas({
    super.key,
    this.height = 160,
    this.onStrokeCountChanged,
  });

  final double height;
  final ValueChanged<int>? onStrokeCountChanged;

  @override
  State<SketchCanvas> createState() => SketchCanvasState();
}

class SketchCanvasState extends State<SketchCanvas> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];
  Color _penColor = AppColors.primary;

  int get strokeCount => _strokes.length;

  void clear() {
    setState(() {
      _strokes.clear();
      _current = [];
    });
    widget.onStrokeCountChanged?.call(0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Sketch',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            _ColorDot(
              color: AppColors.primary,
              selected: _penColor == AppColors.primary,
              onTap: () => setState(() => _penColor = AppColors.primary),
            ),
            _ColorDot(
              color: AppColors.error,
              selected: _penColor == AppColors.error,
              onTap: () => setState(() => _penColor = AppColors.error),
            ),
            _ColorDot(
              color: cs.onSurface,
              selected: _penColor == cs.onSurface,
              onTap: () => setState(() => _penColor = cs.onSurface),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear sketch',
              onPressed: _strokes.isEmpty ? null : clear,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              border: Border.all(color: cs.outlineVariant),
            ),
            child: GestureDetector(
              onPanStart: (d) {
                setState(() => _current = [d.localPosition]);
              },
              onPanUpdate: (d) {
                setState(() => _current.add(d.localPosition));
              },
              onPanEnd: (_) {
                setState(() {
                  if (_current.length > 1) _strokes.add(List.of(_current));
                  _current = [];
                });
                widget.onStrokeCountChanged?.call(_strokes.length);
              },
              child: CustomPaint(
                painter: _SketchPainter(
                  strokes: _strokes,
                  current: _current,
                  color: _penColor,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              width: selected ? 2.5 : 1,
              color: selected ? AppColors.accent : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}

class _SketchPainter extends CustomPainter {
  _SketchPainter({
    required this.strokes,
    required this.current,
    required this.color,
  });

  final List<List<Offset>> strokes;
  final List<Offset> current;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in [...strokes, if (current.length > 1) current]) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => true;
}
