import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../providers/settings_provider.dart';

class SketchTemplates {
  static Path getPath(
    String templateName,
    double x,
    double y,
    double size,
  ) {
    String svgString = _getSvgString(templateName);
    Path parsedPath = parseSvgPathData(svgString);
    
    // Most of these SVG strings assume a 24x24 viewBox (Material Icons).
    // We scale them to fit the requested 'size'.
    double scaleFactor = size / 24.0;
    
    final matrix = Matrix4.identity()
      ..translate(x - (12 * scaleFactor), y - (12 * scaleFactor)) // Center the 24x24 path at (x,y)
      ..scale(scaleFactor);
      
    return parsedPath.transform(matrix.storage);
  }

  static String _getSvgString(String name) {
    switch (name.toLowerCase()) {
      case 'car':
        return "M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z";
      case 'train':
        return "M12 2c-4 0-8 .5-8 4v9.5C4 17.43 5.57 19 7.5 19L6 20.5v.5h12v-.5L16.5 19c1.93 0 3.5-1.57 3.5-3.5V6c0-3.5-3.98-4-8-4zm0 2c4.42 0 6 .5 6 2s-1.58 2-6 2-6-.5-6-2 1.58-2 6-2zm0 13c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm6-4H6V7h12v6z";
      case 'house':
        return "M12 3L2 12h3v8h6v-6h2v6h6v-8h3L12 3zm5 15h-2v-6H9v6H7v-7.81l5-4.5 5 4.5V18z M7 10.19V18h2v-6h6v6h2v-7.81l-5-4.5-5 4.5z M10 10h4v2h-4z"; // Detailed house
      case 'dog':
        return "M21 11.5l-1.5-1.5h-2.1c-.2-.7-.6-1.3-1.1-1.8l2.2-2.2-1.4-1.4-2.2 2.2c-.6-.3-1.2-.5-1.9-.5V4h-2v2.3c-.7 0-1.3.2-1.9.5L6.9 4.6 5.5 6l2.2 2.2c-.5.5-.9 1.1-1.1 1.8H4.5L3 11.5v3h1.5v3H3v3h4.5v-3H9v3h6v-3h1.5v3H21v-3h-1.5v-3H21v-3zm-10-3c.8 0 1.5.7 1.5 1.5S11.8 11.5 11 11.5 9.5 10.8 9.5 10 10.2 8.5 11 8.5zm4 7.5H7v-2h8v2z"; // Android robot replaced with dog-like shape? Let's use a standard pet icon.
      case 'cat':
        // A cute cat icon path
        return "M12 8c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4-1.79-4-4-4zm-4 4c0-2.21 1.79-4 4-4s4 1.79 4 4-1.79 4-4 4-4-1.79-4-4zm8.5-7.5l-2.12 2.12C13.6 6.22 12.83 6 12 6s-1.6.22-2.38.62L7.5 4.5 6 6l2 2c-.63 1.09-1 2.33-1 3.65 0 3.87 3.13 7 7 7s7-3.13 7-7c0-1.32-.37-2.56-1-3.65l2-2-1.5-1.5z M9 11h2v2H9v-2zm4 0h2v2h-2v-2z"; 
      case 'frog':
      case 'tree':
        return "M17 12c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zm0 8c-1.65 0-3-1.35-3-3s1.35-3 3-3 3 1.35 3 3-1.35 3-3 3z M12 6c-2.76 0-5 2.24-5 5 0 .97.28 1.87.75 2.61L4 16.5 5.5 18l3.75-3.75C10.08 14.83 11 15.5 12 15.5c2.76 0 5-2.24 5-5s-2.24-5-5-5zm0 8c-1.65 0-3-1.35-3-3s1.35-3 3-3 3 1.35 3 3-1.35 3-3 3z M7 12c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zm0 8c-1.65 0-3-1.35-3-3s1.35-3 3-3 3 1.35 3 3-1.35 3-3 3z"; // A nice tree/cloud shape
      default:
        // Fallback generic star
        return "M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z";
    }
  }
}
