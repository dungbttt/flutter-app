import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImageUtils {
  // Load ảnh từ assets
  static Future<ui.Image> loadImageFromAssets(String path) async {
    final ByteData data = await rootBundle.load(path);
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(data.buffer.asUint8List(), (ui.Image img) {
      completer.complete(img);
    });
    return completer.future;
  }

  // Load ảnh từ file
  static Future<ui.Image> loadImageFromFile(File file) async {
    final Uint8List bytes = await file.readAsBytes();
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(bytes, (ui.Image img) {
      completer.complete(img);
    });
    return completer.future;
  }

  // Custom painter để vẽ bounding box
  static CustomPaint drawBoundingBox(ui.Image image, Rect rect, double confidence) {
    return CustomPaint(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      painter: BoundingBoxPainter(image, rect, confidence),
    );
  }
}

// Custom painter để vẽ ảnh và bounding box
class BoundingBoxPainter extends CustomPainter {
  final ui.Image image;
  final Rect rect;
  final double confidence;

  BoundingBoxPainter(this.image, this.rect, this.confidence);

  @override
  void paint(Canvas canvas, Size size) {
    // Vẽ ảnh
    canvas.drawImage(
      image,
      Offset.zero,
      Paint(),
    );

    // Vẽ bounding box
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRect(rect, paint);

    // Vẽ nhãn và confidence
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Ball: ${(confidence * 100).toStringAsFixed(1)}%',
        style: const TextStyle(
          color: Colors.red,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, rect.topLeft.translate(0, -20));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}