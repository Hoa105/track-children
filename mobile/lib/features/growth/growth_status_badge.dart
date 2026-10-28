import 'package:flutter/material.dart';

class GrowthStatusBadge extends StatelessWidget {
  const GrowthStatusBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.angle,
    required this.easyRead,
  });
  final String label;
  final IconData icon;
  final Color foreground, background;
  final double angle;
  final bool easyRead;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: PhysicalShape(
      clipper: const _BookmarkBadgeClipper(),
      color: background,
      shadowColor: foreground.withValues(alpha: .15),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: foreground),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: easyRead ? 18 : 14,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BookmarkBadgeClipper extends CustomClipper<Path> {
  const _BookmarkBadgeClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width - 12, size.height / 2)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant _BookmarkBadgeClipper oldClipper) => false;
}
