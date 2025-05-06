import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:ui' as ui;

class TFLiteService {
  static const String modelPath = 'assets/models/yolov8_3.tflite';
  late Interpreter _interpreter;
  bool _isLoaded = false;

  // Singleton pattern
  static final TFLiteService _instance = TFLiteService._internal();
  factory TFLiteService() => _instance;
  TFLiteService._internal();

  bool get isLoaded => _isLoaded;

  Future<void> loadModel() async {
    try {
      // Load model từ assets
      final interpreterOptions = InterpreterOptions();
      
      // Đối với thiết bị có GPU, có thể bật tính năng này
      // interpreterOptions.addDelegate(GpuDelegate());
      
      _interpreter = await Interpreter.fromAsset(
        modelPath,
        options: interpreterOptions,
      );
      
      _isLoaded = true;
      debugPrint('Model loaded successfully');
      
      // In ra thông tin shape của model
      final inputShape = _interpreter.getInputTensor(0).shape;
      final outputShape = _interpreter.getOutputTensor(0).shape;
      
      debugPrint('Input shape: $inputShape');
      debugPrint('Output shape: $outputShape');
    } catch (e) {
      debugPrint('Error loading model: $e');
      _isLoaded = false;
    }
  }

  // Chuyển đổi ảnh từ flutter sang định dạng phù hợp cho TFLite
  Future<Uint8List> _imageToByteListFloat32(img.Image image, int inputSize) async {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = img.getRed(pixel) / 255.0;
        buffer[pixelIndex++] = img.getGreen(pixel) / 255.0;
        buffer[pixelIndex++] = img.getBlue(pixel) / 255.0;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  // Chạy model với ảnh đầu vào
  Future<Map<String, dynamic>> runInference(ui.Image uiImage) async {
    if (!_isLoaded) {
      await loadModel();
    }

    // Chuyển đổi ui.Image sang img.Image
    final inputSize = 640; // Kích thước đầu vào của YOLO
    final imageWidth = uiImage.width;
    final imageHeight = uiImage.height;
    
    final imageBytes = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    final imageData = imageBytes!.buffer.asUint8List();
    
    img.Image inputImage = img.Image.fromBytes(
      width: imageWidth,
      height: imageHeight,
      bytes: imageData.buffer,
      order: img.ChannelOrder.rgba,
    );
    
    // Resize ảnh về kích thước 640x640
    inputImage = img.copyResize(inputImage, width: inputSize, height: inputSize);
    
    // Chuyển đổi ảnh sang định dạng cho TFLite
    final inputBytes = await _imageToByteListFloat32(inputImage, inputSize);
    
    // Chuẩn bị input và output tensors
    final inputShape = [1, inputSize, inputSize, 3]; // NHWC format
    final outputShape = [4, 5, 8400]; // Shape [4, 5, 8400]
    
    // Tạo output buffer với kích thước phù hợp
    final outputBuffer = Float32List(4 * 5 * 8400);
    
    // Chạy suy luận
    final inputs = [inputBytes];
    final outputs = {0: outputBuffer};
    
    try {
      _interpreter.runForMultipleInputs([inputs], {0: outputs});
      
      // Xử lý kết quả
      // Tạo một mảng 3 chiều từ outputBuffer
      List<List<List<double>>> resultArray = List.generate(
        4, // dim1
        (i) => List.generate(
          5, // dim2
          (j) => List.generate(
            8400, // dim3
            (k) => outputBuffer[i * 5 * 8400 + j * 8400 + k],
          ),
        ),
      );
      
      // Tìm box có confidence cao nhất
      double highestScore = 0;
      double bestX1 = 0, bestY1 = 0, bestX2 = 0, bestY2 = 0;
      bool foundBox = false;
      
      // Giả sử định dạng đầu ra là:
      // outputShape[0][0..3] = bounding boxes (x, y, w, h)
      // outputShape[0][4] = confidence
      for (int i = 0; i < 8400; i++) {
        final confidence = resultArray[0][4][i];
        
        if (confidence > 0.5 && confidence > highestScore) { // Thêm ngưỡng 0.5
          highestScore = confidence;
          
          // Lấy tọa độ của box - giả định các giá trị được chuẩn hóa từ 0-1
          final xCenter = resultArray[0][0][i] * imageWidth;
          final yCenter = resultArray[0][1][i] * imageHeight;
          final width = resultArray[0][2][i] * imageWidth;
          final height = resultArray[0][3][i] * imageHeight;
          
          // Chuyển đổi từ 'xywh' sang 'xyxy'
          bestX1 = xCenter - width / 2;
          bestY1 = yCenter - height / 2;
          bestX2 = xCenter + width / 2;
          bestY2 = yCenter + height / 2;
          
          foundBox = true;
        }
      }
      
      return {
        'found': foundBox,
        'confidence': highestScore,
        'rect': foundBox ? Rect.fromLTRB(bestX1, bestY1, bestX2, bestY2) : null,
      };
    } catch (e) {
      debugPrint('Error running inference: $e');
      return {'found': false, 'error': e.toString()};
    }
  }

  // Phương thức để giải phóng tài nguyên
  void dispose() {
    if (_isLoaded) {
      _interpreter.close();
      _isLoaded = false;
    }
  }
}