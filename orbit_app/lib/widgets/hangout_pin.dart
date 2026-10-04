import 'package:flutter/material.dart';

import '../models/hangout.dart';
import '../theme.dart';

const Size kPinSize = Size(180, 58);

class HangoutPin extends StatelessWidget {
  final Hangout hangout;
  final bool selected;
  final VoidCallback onTap;

  const HangoutPin({
    super.key,
    required this.hangout,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final cat = categoryFor(hangout.category);
    final dim = hangout.isFull && !hangout.isHost;
    final accent = dim ? context.cInkSoft : cat.color;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: selected ? 1.08 : 1.0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
                decoration: BoxDecoration(
                  color: context.cSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected ? accent : accent.withValues(alpha: 0.35),
                    width: selected ? 2 : 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(cat.icon, size: 17, color: accent),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        hangout.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.cInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          CustomPaint(
            size: const Size(16, 9),
            painter: _PointerPainter(accent, context.cSurface),
          ),
        ],
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  final Color color;
  final Color surface;
  _PointerPainter(this.color, this.surface);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = surface
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, fill);

    final edges = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(edges, stroke);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter old) =>
      old.color != color || old.surface != surface;
}
