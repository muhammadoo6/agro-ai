import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Кольцевая диаграмма (доли), с анимацией появления.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    this.center,
    this.size = 160,
    this.thickness = 22,
  });

  final List<double> values;
  final List<Color> colors;
  final Widget? center;
  final double size;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DonutPainter(
            values,
            colors,
            t,
            thickness,
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Center(child: child),
        ),
      ),
      child: center,
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.colors, this.t, this.thickness, this.track);

  final List<double> values;
  final List<Color> colors;
  final double t;
  final double thickness;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(thickness / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = track;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    var start = -math.pi / 2;
    const gap = 0.025;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2 * t;
      if (sweep <= gap) {
        start += sweep;
        continue;
      }
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.butt
        ..color = colors[i % colors.length];
      canvas.drawArc(r, start, sweep - gap, false, p);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.t != t || old.values != values || old.track != track;
}

/// Столбики «доход/расход» по месяцам, с анимацией роста.
class IncomeExpenseBars extends StatelessWidget {
  const IncomeExpenseBars({
    super.key,
    required this.labels,
    required this.income,
    required this.expense,
    required this.incomeColor,
    required this.expenseColor,
    this.height = 150,
  });

  final List<String> labels;
  final List<double> income;
  final List<double> expense;
  final Color incomeColor;
  final Color expenseColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => SizedBox(
        height: height + 20,
        child: Column(
          children: [
            SizedBox(
              height: height,
              child: CustomPaint(
                size: Size.infinite,
                painter: _BarsPainter(income, expense, incomeColor, expenseColor, t,
                    Theme.of(context).colorScheme.outlineVariant),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final l in labels)
                  Expanded(child: Text(l, textAlign: TextAlign.center, style: style)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.inc, this.exp, this.ci, this.ce, this.t, this.grid);

  final List<double> inc, exp;
  final Color ci, ce, grid;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final n = inc.length;
    if (n == 0) return;
    final maxV = [...inc, ...exp, 1.0].reduce(math.max);
    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), g);
    }
    final slot = size.width / n;
    final bw = math.min(14.0, slot / 3.2);
    for (var i = 0; i < n; i++) {
      final cx = slot * i + slot / 2;
      void bar(double v, double dx, Color c) {
        final h = v / maxV * size.height * t;
        final r = RRect.fromRectAndCorners(
          Rect.fromLTWH(cx + dx, size.height - h, bw, h),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(r, Paint()..color = c);
      }

      bar(inc[i], -bw - 1, ci);
      bar(exp[i], 1, ce);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.t != t || old.inc != inc || old.exp != exp;
}

/// Полукруглый индикатор уверенности (для результата скана).
class ConfidenceGauge extends StatelessWidget {
  const ConfidenceGauge({super.key, required this.value, required this.color, this.size = 120});

  final double value;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutBack,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size * 0.62,
        child: CustomPaint(
          painter: _GaugePainter(v, color, Theme.of(context).colorScheme.surfaceContainerHighest),
          child: Align(
            alignment: const Alignment(0, 0.9),
            child: Text(
              '${(v * 100).round()}%',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.v, this.color, this.track);

  final double v;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final r = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.width - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(r, math.pi, math.pi, false, base);
    canvas.drawArc(r, math.pi, math.pi * v.clamp(0, 1), false, base..color = color);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.v != v || old.color != color;
}
