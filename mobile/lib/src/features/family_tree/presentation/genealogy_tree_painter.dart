import 'package:family_digital_heritage_vault/src/core/theme/app_theme.dart';
import 'package:family_digital_heritage_vault/src/features/family_tree/layout/genealogy_layout_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class GenealogyTreePainter extends CustomPainter {
  final List<GenealogyLine> lines;

  GenealogyTreePainter({required this.lines});

  @override
  void paint(Canvas canvas, Size size) {
    final spousePaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final treePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final line in lines) {
      final paint = line.kind == GenealogyLineKind.spouse ? spousePaint : treePaint;
      if (line.kind == GenealogyLineKind.spouse) {
        canvas.drawLine(line.from, line.to, paint);
      } else {
        _drawOrthogonal(canvas, line.from, line.to, paint);
      }
    }
  }

  void _drawOrthogonal(Canvas canvas, Offset from, Offset to, Paint paint) {
    // Nearly vertical or horizontal — draw direct.
    if ((from.dx - to.dx).abs() < 0.5) {
      canvas.drawLine(from, to, paint);
      return;
    }
    if ((from.dy - to.dy).abs() < 0.5) {
      canvas.drawLine(from, to, paint);
      return;
    }
    // L-shape: vertical stub down then horizontal.
    final mid = Offset(from.dx, to.dy);
    canvas.drawLine(from, mid, paint);
    canvas.drawLine(mid, to, paint);
  }

  @override
  bool shouldRepaint(covariant GenealogyTreePainter oldDelegate) {
    // Use deep equality so we don't repaint when the list contents are identical.
    return !listEquals(oldDelegate.lines, lines);
  }
}
