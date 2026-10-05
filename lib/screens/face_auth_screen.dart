import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../models/hr_models.dart';
import '../services/face_recognition_service.dart';

class FaceAuthScreen extends StatefulWidget {
  final List<double>? targetEmbedding; // If provided, verify against this single embedding
  final List<CompanyEmployee>? matchEmployees; // If provided, identify and match against enrolled employees
  final String title;

  const FaceAuthScreen({
    super.key,
    this.targetEmbedding,
    this.matchEmployees,
    this.title = 'Face Authentication',
  });

  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen> {
  CameraController? _controller;
  List<CameraDescription> _availableCameras = [];
  int _currentCameraIndex = 0;
  final FaceRecognitionService _faceService = FaceRecognitionService();
  bool _isProcessing = false;
  String? _initError;
  String _statusMessage = 'Align your face inside the circle and tap capture.';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _initError = null;
        _statusMessage = 'Initializing camera...';
      });

      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _initError = 'No camera found on this device.';
          _statusMessage = 'Please select a photo from gallery.';
        });
        return;
      }

      // Default to front camera if available
      int frontIdx = _availableCameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _currentCameraIndex = frontIdx != -1 ? frontIdx : 0;

      await _setupCameraController(_availableCameras[_currentCameraIndex]);
      await _faceService.initialize();

      if (mounted) {
        setState(() {
          _statusMessage = 'Align your face inside the circle and tap capture.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = 'Camera error: $e';
          _statusMessage = 'You can still pick a photo from gallery.';
        });
      }
    }
  }

  Future<void> _setupCameraController(CameraDescription camera) async {
    await _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller!.initialize();
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2 || _isProcessing) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _availableCameras.length;
    setState(() => _isProcessing = true);
    try {
      await _setupCameraController(_availableCameras[_currentCameraIndex]);
    } catch (e) {
      debugPrint('Failed to switch camera: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (image != null) {
        await _processImagePath(image.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to pick image: $e';
        });
      }
    }
  }

  Future<void> _captureAndProcess() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Detecting & processing face...';
    });

    try {
      final XFile file = await _controller!.takePicture();
      await _processImagePath(file.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error taking photo: $e';
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processImagePath(String imagePath) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Analyzing facial biometric features...';
    });

    try {
      final embedding = await _faceService.getFaceEmbedding(imagePath);

      if (embedding == null) {
        if (mounted) {
          setState(() {
            _statusMessage = 'No face detected. Please ensure your face is well-lit and clearly visible.';
            _isProcessing = false;
          });
        }
        return;
      }

      // Case 1: Identification / Login Mode (Match against multiple enrolled employees)
      if (widget.matchEmployees != null && widget.matchEmployees!.isNotEmpty) {
        CompanyEmployee? bestMatch;
        double minDistance = 999.0;

        for (final emp in widget.matchEmployees!) {
          if (emp.faceEmbedding == null || emp.faceEmbedding!.isEmpty) continue;
          final dist = _faceService.calculateEuclideanDistance(emp.faceEmbedding!, embedding);
          debugPrint('Matching against ${emp.name}: distance = $dist');
          if (dist < minDistance) {
            minDistance = dist;
            bestMatch = emp;
          }
        }

        // Threshold for MobileFaceNet is ~1.0
        if (bestMatch != null && minDistance < 1.05) {
          if (!mounted) return;
          Navigator.pop(context, bestMatch);
          return;
        } else {
          if (mounted) {
            setState(() {
              _statusMessage = 'Face not recognized. Try again or sign in with your password.';
              _isProcessing = false;
            });
          }
          return;
        }
      }

      // Case 2: Verification Mode (Verify against target embedding)
      if (widget.targetEmbedding != null) {
        final double distance = _faceService.calculateEuclideanDistance(
          widget.targetEmbedding!,
          embedding,
        );
        debugPrint('Face verification distance: $distance');

        if (distance < 1.05) {
          if (!mounted) return;
          Navigator.pop(context, true); // Verified successfully
          return;
        } else {
          if (mounted) {
            setState(() {
              _statusMessage = 'Face did not match. Please try again.';
              _isProcessing = false;
            });
          }
          return;
        }
      }

      // Case 3: Registration / Enrollment Mode (targetEmbedding == null and matchEmployees == null)
      if (!mounted) return;
      Navigator.pop(context, embedding); // Return the List<double> face embedding
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Authentication error: $e';
          _isProcessing = false;
        });
      }
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_availableCameras.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
              tooltip: 'Switch Camera',
              onPressed: _switchCamera,
            ),
          IconButton(
            icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
            tooltip: 'Pick from Gallery',
            onPressed: _pickFromGallery,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 54),
              ),
              const SizedBox(height: 20),
              Text(
                _initError!,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _statusMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Select Photo from Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5CE),
                  foregroundColor: const Color(0xFF0A2342),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _initializeCamera,
                child: const Text('Retry Camera', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E5CE)),
      );
    }

    return Stack(
      children: [
        // Camera Preview
        Center(
          child: AspectRatio(
            aspectRatio: 1 / _controller!.value.aspectRatio,
            child: CameraPreview(_controller!),
          ),
        ),

        // Darkened Mask with Oval Cutout
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.55),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: 270,
                    height: 340,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(160),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Glowing Scanner Border
        Center(
          child: Container(
            width: 270,
            height: 340,
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF00E5CE),
                width: 3.5,
              ),
              borderRadius: BorderRadius.circular(160),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5CE).withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),

        // Bottom Controls & Instruction
        Positioned(
          bottom: 30,
          left: 20,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 22),
              if (!_isProcessing)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery pick button
                    IconButton(
                      icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 28),
                      tooltip: 'Choose photo from gallery',
                      onPressed: _pickFromGallery,
                    ),
                    // Capture button
                    GestureDetector(
                      onTap: _captureAndProcess,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00F0D8), Color(0xFF00BD96)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00F0D8).withValues(alpha: 0.5),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 62,
                            height: 62,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Color(0xFF0A2342),
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Flip camera button
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 28),
                      tooltip: 'Switch Camera',
                      onPressed: _availableCameras.length > 1 ? _switchCamera : null,
                    ),
                  ],
                ),
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: Color(0xFF00E5CE)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
