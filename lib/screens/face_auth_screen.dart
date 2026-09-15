import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/face_recognition_service.dart';

class FaceAuthScreen extends StatefulWidget {
  final List<double>? targetEmbedding; // If null, we are registering a face. If provided, we are verifying.
  final String title;

  const FaceAuthScreen({
    super.key,
    this.targetEmbedding,
    this.title = 'Face Authentication',
  });

  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen> {
  CameraController? _controller;
  final FaceRecognitionService _faceService = FaceRecognitionService();
  bool _isProcessing = false;
  String _statusMessage = 'Align your face and tap capture.';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    await _faceService.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _captureAndProcess() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Processing...';
    });

    try {
      final XFile file = await _controller!.takePicture();
      final embedding = await _faceService.getFaceEmbedding(file.path);

      if (embedding == null) {
        setState(() {
          _statusMessage = 'No face detected. Please try again.';
          _isProcessing = false;
        });
        return;
      }

      if (widget.targetEmbedding == null) {
        // Registration Mode
        if (!mounted) return;
        Navigator.pop(context, embedding);
      } else {
        // Verification Mode
        double distance = _faceService.calculateEuclideanDistance(widget.targetEmbedding!, embedding);
        debugPrint('Face Distance: $distance');
        
        // Threshold for MobileFaceNet is typically around 1.0 to 1.1
        if (distance < 1.0) {
          if (!mounted) return;
          Navigator.pop(context, true); // Success
        } else {
          setState(() {
            _statusMessage = 'Face does not match. Try again.';
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Camera Preview
          Center(
            child: CameraPreview(_controller!),
          ),
          // Bounding Box / Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00FF87), width: 3),
                borderRadius: BorderRadius.circular(125), // Circular cutout
              ),
            ),
          ),
          // Bottom Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (!_isProcessing)
                  GestureDetector(
                    onTap: _captureAndProcess,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF00FF87), width: 4),
                      ),
                    ),
                  ),
                if (_isProcessing)
                  const CircularProgressIndicator(color: Color(0xFF00FF87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
