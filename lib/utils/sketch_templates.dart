import 'package:flutter/material.dart';
import '../providers/settings_provider.dart';

class SketchTemplates {
  static Path getPath(
    String templateName,
    ArtStyleMode mode,
    double x,
    double y,
    double size,
  ) {
    switch (templateName.toLowerCase()) {
      case 'frog':
        return _getFrogPath(mode, x, y, size);
      case 'car':
        return _getCarPath(mode, x, y, size);
      case 'house':
        return _getHousePath(mode, x, y, size);
      case 'tree':
        return _getTreePath(mode, x, y, size);
      default:
        return _getFrogPath(mode, x, y, size); // fallback
    }
  }

  static Path _getFrogPath(ArtStyleMode mode, double x, double y, double size) {
    Path path = Path();
    double s = size / 100.0; // scale factor

    if (mode == ArtStyleMode.cute) {
      // Cute simple round frog
      // Body
      path.addOval(Rect.fromCircle(center: Offset(x, y), radius: 40 * s));
      // Eyes
      path.addOval(
        Rect.fromCircle(center: Offset(x - 20 * s, y - 40 * s), radius: 15 * s),
      );
      path.addOval(
        Rect.fromCircle(center: Offset(x + 20 * s, y - 40 * s), radius: 15 * s),
      );
      // Pupils
      path.addOval(
        Rect.fromCircle(center: Offset(x - 20 * s, y - 40 * s), radius: 5 * s),
      );
      path.addOval(
        Rect.fromCircle(center: Offset(x + 20 * s, y - 40 * s), radius: 5 * s),
      );
      // Mouth (smile)
      path.addArc(
        Rect.fromCircle(center: Offset(x, y), radius: 20 * s),
        0.2,
        2.74,
      );
    } else if (mode == ArtStyleMode.illustration) {
      // Sleek minimal abstract frog
      path.moveTo(x - 20 * s, y + 20 * s);
      path.quadraticBezierTo(x, y - 60 * s, x + 20 * s, y + 20 * s); // sleek arching back
      path.addOval(Rect.fromCircle(center: Offset(x, y - 10 * s), radius: 10 * s)); // large expressive eye
      path.addArc(Rect.fromCircle(center: Offset(x, y), radius: 15 * s), 0, 3.14); // wide smile
    } else {
      // Detailed frog (angular/sketchy)
      path.moveTo(x - 30 * s, y + 20 * s);
      path.quadraticBezierTo(x, y - 50 * s, x + 30 * s, y + 20 * s); // back
      path.lineTo(x + 40 * s, y + 40 * s); // right leg
      path.lineTo(x + 20 * s, y + 40 * s);
      path.quadraticBezierTo(x, y + 30 * s, x - 20 * s, y + 40 * s); // belly
      path.lineTo(x - 40 * s, y + 40 * s); // left leg
      path.close();
      // Eye bulges
      path.addOval(Rect.fromLTWH(x - 25 * s, y - 35 * s, 15 * s, 10 * s));
      path.addOval(Rect.fromLTWH(x + 10 * s, y - 35 * s, 15 * s, 10 * s));
      // Mouth line
      path.moveTo(x - 20 * s, y + 5 * s);
      path.lineTo(x + 20 * s, y + 5 * s);
    }
    return path;
  }

  static Path _getCarPath(ArtStyleMode mode, double x, double y, double size) {
    Path path = Path();
    double s = size / 100.0;

    if (mode == ArtStyleMode.cute) {
      // Cute simple car
      path.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 40 * s, y - 10 * s, 80 * s, 30 * s),
          Radius.circular(10 * s),
        ),
      ); // body
      path.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 20 * s, y - 30 * s, 40 * s, 20 * s),
          Radius.circular(8 * s),
        ),
      ); // top
      path.addOval(
        Rect.fromCircle(center: Offset(x - 25 * s, y + 20 * s), radius: 12 * s),
      ); // left wheel
      path.addOval(
        Rect.fromCircle(center: Offset(x + 25 * s, y + 20 * s), radius: 12 * s),
      ); // right wheel
    } else if (mode == ArtStyleMode.illustration) {
      // Sleek modern electric vehicle silhouette
      path.moveTo(x - 60 * s, y + 10 * s);
      path.quadraticBezierTo(x - 50 * s, y - 20 * s, x, y - 20 * s);
      path.quadraticBezierTo(x + 50 * s, y - 20 * s, x + 60 * s, y + 10 * s);
      path.lineTo(x - 60 * s, y + 10 * s);
      // Minimal wheels
      path.addArc(Rect.fromCircle(center: Offset(x - 30 * s, y + 10 * s), radius: 12 * s), 3.14, 3.14);
      path.addArc(Rect.fromCircle(center: Offset(x + 30 * s, y + 10 * s), radius: 12 * s), 3.14, 3.14);
    } else {
      // Detailed car (sports car silhouette)
      path.moveTo(x - 50 * s, y + 10 * s);
      path.lineTo(x - 50 * s, y);
      path.quadraticBezierTo(
        x - 40 * s,
        y - 10 * s,
        x - 20 * s,
        y - 15 * s,
      ); // hood
      path.quadraticBezierTo(x, y - 35 * s, x + 20 * s, y - 25 * s); // roof
      path.lineTo(x + 45 * s, y - 10 * s); // trunk
      path.lineTo(x + 50 * s, y + 10 * s);
      path.lineTo(x - 50 * s, y + 10 * s);
      // Wheels
      path.addOval(
        Rect.fromCircle(center: Offset(x - 30 * s, y + 10 * s), radius: 10 * s),
      );
      path.addOval(
        Rect.fromCircle(center: Offset(x + 30 * s, y + 10 * s), radius: 10 * s),
      );
      // Window line
      path.moveTo(x - 15 * s, y - 15 * s);
      path.lineTo(x + 10 * s, y - 20 * s);
      path.lineTo(x + 15 * s, y - 10 * s);
    }
    return path;
  }

  static Path _getHousePath(
    ArtStyleMode mode,
    double x,
    double y,
    double size,
  ) {
    Path path = Path();
    double s = size / 100.0;

    if (mode == ArtStyleMode.cute) {
      // Simple square house with triangle roof
      path.addRect(
        Rect.fromLTWH(x - 30 * s, y - 10 * s, 60 * s, 50 * s),
      ); // body
      path.moveTo(x - 40 * s, y - 10 * s); // roof
      path.lineTo(x, y - 50 * s);
      path.lineTo(x + 40 * s, y - 10 * s);
      path.close();
      path.addRect(
        Rect.fromLTWH(x - 10 * s, y + 15 * s, 20 * s, 25 * s),
      ); // door
      path.addRect(Rect.fromLTWH(x - 20 * s, y, 10 * s, 10 * s)); // window
      path.addRect(Rect.fromLTWH(x + 10 * s, y, 10 * s, 10 * s)); // window
    } else if (mode == ArtStyleMode.illustration) {
      // Modern A-Frame cabin
      path.moveTo(x, y - 60 * s);
      path.lineTo(x - 40 * s, y + 20 * s);
      path.lineTo(x + 40 * s, y + 20 * s);
      path.close();
      // Triangle window
      path.moveTo(x, y - 30 * s);
      path.lineTo(x - 15 * s, y);
      path.lineTo(x + 15 * s, y);
      path.close();
    } else {
      // Detailed house (suburban)
      path.addRect(
        Rect.fromLTWH(x - 40 * s, y - 10 * s, 80 * s, 50 * s),
      ); // body
      path.moveTo(x - 45 * s, y - 10 * s);
      path.lineTo(x - 20 * s, y - 35 * s);
      path.lineTo(x + 45 * s, y - 10 * s);
      // Chimney
      path.addRect(Rect.fromLTWH(x + 15 * s, y - 45 * s, 10 * s, 20 * s));
      // Detailed door
      path.addRect(Rect.fromLTWH(x - 5 * s, y + 10 * s, 20 * s, 30 * s));
      path.addOval(
        Rect.fromCircle(center: Offset(x + 10 * s, y + 25 * s), radius: 2 * s),
      ); // doorknob
      // Multi-pane windows
      path.addRect(Rect.fromLTWH(x - 30 * s, y, 15 * s, 20 * s));
      path.moveTo(x - 22.5 * s, y);
      path.lineTo(x - 22.5 * s, y + 20 * s);
      path.moveTo(x - 30 * s, y + 10 * s);
      path.lineTo(x - 15 * s, y + 10 * s);
    }
    return path;
  }

  static Path _getTreePath(ArtStyleMode mode, double x, double y, double size) {
    Path path = Path();
    double s = size / 100.0;

    if (mode == ArtStyleMode.cute) {
      // Simple cloud-like tree
      path.addRect(Rect.fromLTWH(x - 10 * s, y, 20 * s, 50 * s)); // trunk
      path.addOval(
        Rect.fromCircle(center: Offset(x, y - 10 * s), radius: 30 * s),
      ); // leaves
      path.addOval(
        Rect.fromCircle(center: Offset(x - 20 * s, y - 20 * s), radius: 20 * s),
      );
      path.addOval(
        Rect.fromCircle(center: Offset(x + 20 * s, y - 20 * s), radius: 20 * s),
      );
      path.addOval(
        Rect.fromCircle(center: Offset(x, y - 40 * s), radius: 25 * s),
      );
    } else if (mode == ArtStyleMode.illustration) {
      // Stylized weeping willow / minimal swooping tree
      path.moveTo(x, y + 40 * s);
      path.quadraticBezierTo(x + 10 * s, y, x, y - 40 * s); // Curved slender trunk
      path.quadraticBezierTo(x + 50 * s, y - 10 * s, x + 30 * s, y + 30 * s); // sweeping branch right
      path.moveTo(x, y - 30 * s);
      path.quadraticBezierTo(x - 40 * s, y, x - 20 * s, y + 20 * s); // sweeping branch left
    } else {
      // Detailed tree (pine/organic)
      path.moveTo(x - 5 * s, y + 50 * s); // trunk base
      path.lineTo(x - 5 * s, y);
      path.lineTo(x + 5 * s, y);
      path.lineTo(x + 5 * s, y + 50 * s);

      // Jagged branches
      path.moveTo(x, y - 60 * s);
      path.lineTo(x - 30 * s, y - 20 * s);
      path.lineTo(x - 15 * s, y - 20 * s);
      path.lineTo(x - 40 * s, y + 10 * s);
      path.lineTo(x - 20 * s, y + 10 * s);
      path.lineTo(x - 45 * s, y + 40 * s);

      path.lineTo(x + 45 * s, y + 40 * s);
      path.lineTo(x + 20 * s, y + 10 * s);
      path.lineTo(x + 40 * s, y + 10 * s);
      path.lineTo(x + 15 * s, y - 20 * s);
      path.lineTo(x + 30 * s, y - 20 * s);
      path.lineTo(x, y - 60 * s);
      path.close();
    }
    return path;
  }
}
