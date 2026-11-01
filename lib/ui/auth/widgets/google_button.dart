import 'dart:math' as math;

import 'package:flutter/material.dart';

/// "Continue with Google" with the divider that separates it from the email form.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
          onPressed: onPressed,
          icon: const SizedBox.square(
            dimension: 20,
            child: CustomPaint(painter: _GoogleLogoPainter()),
          ),
          label: const Text('Continue with Google'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or with email',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
        ),
      ],
    );
  }
}

/// The four-color "G": a ring of colored arcs with a blue crossbar.
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);
  static const _blue = Color(0xFF4285F4);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final ring = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    double radians(double degrees) => degrees * math.pi / 180;
    void arc(Color color, double start, double sweep) => canvas.drawArc(
      ring,
      radians(start),
      radians(sweep),
      false,
      paint..color = color,
    );

    arc(_blue, -35, 35);
    arc(_green, 0, 135);
    arc(_yellow, 135, 90);
    arc(_red, 225, 100);
    canvas.drawRect(
      Rect.fromLTRB(
        size.width / 2,
        size.height / 2 - stroke / 2,
        size.width,
        size.height / 2 + stroke / 2,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}
