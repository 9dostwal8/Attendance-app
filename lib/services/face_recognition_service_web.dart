import 'dart:math';
import 'package:flutter/foundation.dart';

class FaceRecognitionService {
  Future<void> initialize() async {
    debugPrint('FaceRecognitionService: Web platform not supported');
  }

  Future<List<double>?> getFaceEmbedding(String imagePath) async {
    throw Exception('Face authentication is not supported on the Web platform.');
  }

  double calculateEuclideanDistance(List<double> e1, List<double> e2) {
    if (e1.length != e2.length) return 999.0;
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      double diff = e1[i] - e2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  void dispose() {
    // No-op on web
  }
}
