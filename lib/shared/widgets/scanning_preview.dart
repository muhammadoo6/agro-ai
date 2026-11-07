import 'dart:io';

import 'package:flutter/material.dart';

/// Фото с бегущей «лазерной» линией и сеткой — пока идёт анализ.
class ScanningPreview extends StatefulWidget {
  const ScanningPreview({super.key, required this.file, required this.label});

  final File file;
  final String label;

  @override
  State<ScanningPreview> createState() => _ScanningPreviewState();
}

class _ScanningPreviewState extends State<ScanningPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(widget.file, fit: BoxFit.cover, cacheWidth: 800),
            Container(color: Colors.black26),
            CustomPaint(painter: _GridPainter()),
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Align(
                alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_c.value)),
                child: Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    color: Color(0xFF76FF03),
                    boxShadow: [
                      BoxShadow(color: Color(0xAA76FF03), blurRadius: 18, spreadRadius: 6),
                    ],
                  ),
                ),
              ),
            ),
            // Уголки «видоискателя».
            const Positioned.fill(child: CustomPaint(painter: _CornersPainter())),
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(widget.label, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x3376FF03)
      ..strokeWidth = 1;
    const n = 8;
    for (var i = 1; i < n; i++) {
      final x = size.width * i / n, y = size.height * i / n;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const m = 16.0, l = 30.0;
    final w = size.width, h = size.height;
    for (final (x, y, dx, dy) in [
      (m, m, 1.0, 1.0),
      (w - m, m, -1.0, 1.0),
      (m, h - m, 1.0, -1.0),
      (w - m, h - m, -1.0, -1.0),
    ]) {
      canvas.drawLine(Offset(x, y), Offset(x + l * dx, y), p);
      canvas.drawLine(Offset(x, y), Offset(x, y + l * dy), p);
    }
  }

  @override
  bool shouldRepaint(_CornersPainter oldDelegate) => false;
}
