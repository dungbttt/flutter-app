import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:football_project_app/services/tflite_service.dart';
import 'package:football_project_app/utils/image_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TFLiteService _tfliteService = TFLiteService();
  ui.Image? _image;
  Map<String, dynamic>? _result;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModelAndImage();
  }

  // Load model và ảnh thử nghiệm
  Future<void> _loadModelAndImage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load model
      await _tfliteService.loadModel();
      
      // Load ảnh thử nghiệm
      final image = await ImageUtils.loadImageFromAssets('assets/images/ball.png');
      
      // Chạy suy luận
      final result = await _tfliteService.runInference(image);
      
      setState(() {
        _image = image;
        _result = result;
        _isLoading = false;
      });
      
      debugPrint('Model loaded and inference run successfully');
      debugPrint('Result: $result');
    } catch (e) {
      debugPrint('Error loading model or running inference: $e');
      setState(() {
        _isLoading = false;
      });
      
      // Hiển thị thông báo lỗi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YOLO Object Detection'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _buildResultView(),
      ),
    );
  }

  Widget _buildResultView() {
    if (_image == null) {
      return const Text('Failed to load image');
    }

    // Nếu không tìm thấy đối tượng, hiển thị ảnh gốc
    if (_result == null || !_result!['found']) {
      return Image.asset(
        'assets/images/ball.png',
        fit: BoxFit.contain,
      );
    }

    // Nếu tìm thấy đối tượng, vẽ bounding box lên ảnh
    return SizedBox(
      width: _image!.width.toDouble(),
      height: _image!.height.toDouble(),
      child: ImageUtils.drawBoundingBox(
        _image!,
        _result!['rect'],
        _result!['confidence'],
      ),
    );
  }

  @override
  void dispose() {
    _tfliteService.dispose();
    super.dispose();
  }
}