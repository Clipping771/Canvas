import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:vinci_board/core/models/stroke.dart';
import 'package:vinci_board/presentation/screens/canvas/drawing_painter.dart';

class ExportService {
  /// Renders a list of strokes to a PNG byte array
  static Future<Uint8List> exportToPng(
    List<Stroke> strokes,
    Size canvasSize,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw white background
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      paint,
    );

    // Use the existing DrawingPainter logic to render strokes
    final painter = DrawingCanvasPainter(strokes: strokes);

    painter.paint(canvas, canvasSize);

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      canvasSize.width.toInt(),
      canvasSize.height.toInt(),
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// Exports the canvas as a PDF document and returns the file path
  static Future<String> exportToPdf(
    List<Stroke> strokes,
    Size canvasSize,
    String filename,
  ) async {
    final pngBytes = await exportToPng(strokes, canvasSize);

    final pdf = pw.Document();

    final image = pw.MemoryImage(pngBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(canvasSize.width, canvasSize.height),
        build: (pw.Context context) {
          return pw.Center(child: pw.Image(image));
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename.pdf');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }
}
