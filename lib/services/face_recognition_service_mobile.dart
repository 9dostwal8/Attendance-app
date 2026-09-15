import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FaceRecognitionService {
  FaceDetector? _faceDetector;
  Interpreter? _interpreter;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize Face Detector
    final options = FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);

    // Initialize TFLite Interpreter
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      _isInitialized = true;
      debugPrint('FaceRecognitionService: Initialized successfully');
    } catch (e) {
      debugPrint('FaceRecognitionService Error: Failed to load model - $e');
    }
  }

  Future<List<double>?> getFaceEmbedding(String imagePath) async {
    if (!_isInitialized || _faceDetector == null || _interpreter == null) {
      await initialize();
    }

    final inputImage = InputImage.fromFilePath(imagePath);
    final faces = await _faceDetector!.processImage(inputImage);

    if (faces.isEmpty) {
      debugPrint('FaceRecognitionService: No face detected.');
      return null;
    }

    // Assume the largest face is the target
    final face = faces.first;
    final boundingBox = face.boundingBox;

    // Read the image file using the image package
    final bytes = await File(imagePath).readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage == null) return null;

    // Crop the face using the bounding box
    final x = max(0, boundingBox.left.toInt());
    final y = max(0, boundingBox.top.toInt());
    final width = min(originalImage.width - x, boundingBox.width.toInt());
    final height = min(originalImage.height - y, boundingBox.height.toInt());

    img.Image faceCrop = img.copyCrop(originalImage, x: x, y: y, width: width, height: height);

    // Resize to 112x112 as expected by MobileFaceNet
    img.Image resizedFace = img.copyResize(faceCrop, width: 112, height: 112);

    // Convert the image to a nested List shape [1, 112, 112, 3]
    var inputTensor = _imageToNestedList(resizedFace, 112);
    
    // Prepare output array [1, 192]
    var output = List.generate(1, (i) => List.filled(192, 0.0));

    try {
      _interpreter!.run(inputTensor, output);
      return output[0]; // The 192-dimensional embedding
    } catch (e) {
      debugPrint('FaceRecognitionService: Inference error - $e');
      return null;
    }
  }

  List<List<List<List<double>>>> _imageToNestedList(img.Image image, int size) {
    var nestedList = List.generate(1, (_) => 
      List.generate(size, (y) => 
        List.generate(size, (x) {
          var pixel = image.getPixel(x, y);
          return [
            (pixel.r - 127.5) / 128.0,
            (pixel.g - 127.5) / 128.0,
            (pixel.b - 127.5) / 128.0,
          ];
        })
      )
    );
    return nestedList;
  }

  // Calculate Euclidean Distance
  double calculateEuclideanDistance(List<double> e1, List<double> e2) {
    if (e1.length != e2.length) return 999.0;
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      double diff = e1[i] - e2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  // Close resources
  void dispose() {
    _faceDetector?.close();
    _interpreter?.close();
  }
}
