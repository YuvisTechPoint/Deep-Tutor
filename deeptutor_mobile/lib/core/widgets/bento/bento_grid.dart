import 'package:flutter/material.dart';

import '../../layout/responsive.dart';
import '../../theme/app_spacing.dart';
import '../../theme/feature_identity.dart';

// ── Types ────────────────────────────────────────────────────────────────────

/// Layout density for bento module cards.
enum BentoDensity {
  compact,
  standard,
  hero,
}

/// One tile in the adaptive bento grid.
class BentoTileSpec {
  const BentoTileSpec({
    required this.featureId,
    required this.crossAxisSpan,
    this.density = BentoDensity.standard,
    this.priority = 0,
    this.isHero = false,
  });

  final FeatureId featureId;
  final int crossAxisSpan;
  final BentoDensity density;
  final int priority;
  final bool isHero;

  BentoTileSpec copyWith({int? priority}) => BentoTileSpec(
        featureId: featureId,
        crossAxisSpan: crossAxisSpan,
        density: density,
        priority: priority ?? this.priority,
        isHero: isHero,
      );
}

// ── Layout ───────────────────────────────────────────────────────────────────

/// Fluid bento grid with intrinsic row heights and responsive column spans.
class AdaptiveBentoLayout extends StatelessWidget {
  const AdaptiveBentoLayout({
    super.key,
    required this.tiles,
    required this.tileBuilder,
  });

  final List<BentoTileSpec> tiles;
  final Widget Function(BuildContext context, BentoTileSpec spec) tileBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cap = ResponsiveLayout.contentMaxWidth(context);
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(0.0, cap)
            : cap;
        final gap = AppSpacing.bentoGap(context);
        final columns = _effectiveColumns(width);
        final rows = _packRows(tiles, columns, width);

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var r = 0; r < rows.length; r++) ...[
                  if (r > 0) SizedBox(height: gap),
                  _BentoRow(
                    width: width,
                    gap: gap,
                    columns: columns,
                    cells: rows[r],
                    tileBuilder: tileBuilder,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static int _effectiveColumns(double width) {
    if (width < AppSpacing.phoneBreakpoint) return 1;
    return AppSpacing.bentoColumnCount(width);
  }

  static int _scaledSpan(BentoTileSpec spec, int columns, double width) {
    if (width < AppSpacing.phoneBreakpoint) return 1;
    final scaled = (spec.crossAxisSpan * columns / 6).round();
    return scaled.clamp(1, columns);
  }

  static List<List<_RowCell>> _packRows(
    List<BentoTileSpec> tiles,
    int columns,
    double width,
  ) {
    final rows = <List<_RowCell>>[];
    var current = <_RowCell>[];
    var used = 0;

    void flush() {
      if (current.isNotEmpty) {
        rows.add(List.from(current));
        current = [];
        used = 0;
      }
    }

    for (final spec in tiles) {
      var span = _scaledSpan(spec, columns, width);
      if (span > columns) span = columns;
      if (used + span > columns) flush();
      if (span == columns && current.isNotEmpty) flush();
      current.add(_RowCell(spec: spec, span: span));
      used += span;
      if (used >= columns) flush();
    }
    flush();
    return rows;
  }
}

class _RowCell {
  const _RowCell({required this.spec, required this.span});
  final BentoTileSpec spec;
  final int span;
}

class _BentoRow extends StatelessWidget {
  const _BentoRow({
    required this.width,
    required this.gap,
    required this.columns,
    required this.cells,
    required this.tileBuilder,
  });

  final double width;
  final double gap;
  final int columns;
  final List<_RowCell> cells;
  final Widget Function(BuildContext, BentoTileSpec) tileBuilder;

  @override
  Widget build(BuildContext context) {
    final unit = (width - gap * (columns - 1)) / columns;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            SizedBox(
              width: unit * cells[i].span + gap * (cells[i].span - 1),
              child: tileBuilder(context, cells[i].spec),
            ),
          ],
        ],
      ),
    );
  }
}
