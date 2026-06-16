import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum KycStepType {
  faceCentered,
  smile,
  blink,
  turnLeft,
  turnRight,
  lookStraight,
}

extension KycStepTypeLabel on KycStepType {
  String get label {
    switch (this) {
      case KycStepType.faceCentered:
        return 'Live face';
      case KycStepType.smile:
        return 'Smile';
      case KycStepType.blink:
        return 'Blink';
      case KycStepType.turnLeft:
        return 'Turn left';
      case KycStepType.turnRight:
        return 'Turn right';
      case KycStepType.lookStraight:
        return 'Look straight';
    }
  }

  String get instruction {
    switch (this) {
      case KycStepType.faceCentered:
        return 'Center your face inside the frame.';
      case KycStepType.smile:
        return 'Smile clearly for the camera.';
      case KycStepType.blink:
        return 'Blink once to prove liveness.';
      case KycStepType.turnLeft:
        return 'Turn your head slightly to the left.';
      case KycStepType.turnRight:
        return 'Turn your head slightly to the right.';
      case KycStepType.lookStraight:
        return 'Hold a neutral, forward-facing pose.';
    }
  }

  IconData get icon {
    switch (this) {
      case KycStepType.faceCentered:
        return Icons.face_retouching_natural_outlined;
      case KycStepType.smile:
        return Icons.emoji_emotions_outlined;
      case KycStepType.blink:
        return Icons.visibility_off_outlined;
      case KycStepType.turnLeft:
        return Icons.keyboard_arrow_left;
      case KycStepType.turnRight:
        return Icons.keyboard_arrow_right;
      case KycStepType.lookStraight:
        return Icons.center_focus_strong;
    }
  }
}

class KycVerificationResult {
  const KycVerificationResult({
    required this.selfiePath,
    required this.completedSteps,
    required this.completedAt,
  });

  final String selfiePath;
  final List<KycStepType> completedSteps;
  final DateTime completedAt;
}

class KycLivenessCapturePage extends StatefulWidget {
  const KycLivenessCapturePage({super.key});

  @override
  State<KycLivenessCapturePage> createState() => _KycLivenessCapturePageState();
}

class _KycLivenessCapturePageState extends State<KycLivenessCapturePage> {
  static const double _neutralYawDegrees = 8;
  static const double _turnYawDegrees = 22;
  static const Duration _poseHoldDuration = Duration(milliseconds: 600);
  static const List<KycStepType> _steps = <KycStepType>[
    KycStepType.faceCentered,
    KycStepType.smile,
    KycStepType.blink,
    KycStepType.turnLeft,
    KycStepType.turnRight,
    KycStepType.lookStraight,
  ];

  CameraController? _controller;
  CameraDescription? _camera;
  FaceDetector? _faceDetector;
  bool _initializing = true;
  bool _processingFrame = false;
  bool _takingPicture = false;
  int _currentStepIndex = 0;
  bool _waitForNeutral = false;
  bool _blinkArmed = false;
  DateTime? _neutralSince;
  DateTime? _poseSince;
  String _statusText = 'Initializing camera...';
  double? _smileProbability;
  double? _leftEyeProbability;
  double? _rightEyeProbability;
  double? _headEulerY;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No cameras were found on this device.');
      }
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );
      await controller.initialize();

      final faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableTracking: true,
          performanceMode: FaceDetectorMode.fast,
          minFaceSize: 0.2,
        ),
      );

      _controller = controller;
      _camera = frontCamera;
      _faceDetector = faceDetector;

      if (!mounted) {
        await controller.dispose();
        await faceDetector.close();
        return;
      }

      setState(() {
        _initializing = false;
        _statusText = _steps.first.instruction;
      });

      await controller.startImageStream(_processCameraImage);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
        _statusText = 'Unable to start camera: $error';
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_processingFrame || _takingPicture) {
      return;
    }

    final controller = _controller;
    final faceDetector = _faceDetector;
    if (controller == null || faceDetector == null) {
      return;
    }

    _processingFrame = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        return;
      }

      final faces = await faceDetector.processImage(inputImage);
      if (!mounted) {
        return;
      }

      final face = faces.isNotEmpty ? faces.first : null;
      _updateLiveMetrics(face);
      _evaluateCurrentStep(face);
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusText = 'Face detection paused: $error';
        });
      }
    } finally {
      _processingFrame = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _camera;
    if (_controller == null || camera == null) {
      return null;
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.first;

    final size = Size(image.width.toDouble(), image.height.toDouble());
    final rotation = Platform.isIOS
        ? InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
              InputImageRotation.rotation0deg
        : InputImageRotation.rotation270deg;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: size,
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _updateLiveMetrics(Face? face) {
    if (!mounted) {
      return;
    }

    setState(() {
      _smileProbability = face?.smilingProbability;
      _leftEyeProbability = face?.leftEyeOpenProbability;
      _rightEyeProbability = face?.rightEyeOpenProbability;
      _headEulerY = face?.headEulerAngleY;
    });
  }

  void _evaluateCurrentStep(Face? face) {
    if (face == null) {
      _neutralSince = null;
      _poseSince = null;
      return;
    }

    if (_waitForNeutral) {
      if (_isNeutral(face)) {
        _waitForNeutral = false;
      } else {
        return;
      }
    }

    final currentStep = _steps[_currentStepIndex];
    final completed = switch (currentStep) {
      KycStepType.faceCentered => _completeWhenNeutral(
        face,
        holdFor: const Duration(milliseconds: 900),
      ),
      KycStepType.smile => (face.smilingProbability ?? 0) > 0.75,
      KycStepType.blink => _blinkDetected(face),
      KycStepType.turnLeft => _completeWhenTurned(
        face,
        isMatch: (face.headEulerAngleY ?? 0) > _turnYawDegrees,
      ),
      KycStepType.turnRight => _completeWhenTurned(
        face,
        isMatch: (face.headEulerAngleY ?? 0) < -_turnYawDegrees,
      ),
      KycStepType.lookStraight => _completeWhenNeutral(
        face,
        holdFor: const Duration(milliseconds: 900),
      ),
    };

    if (completed) {
      _advanceStep();
    }
  }

  bool _completeWhenNeutral(Face face, {required Duration holdFor}) {
    if (!_isNeutral(face)) {
      _neutralSince = null;
      _poseSince = null;
      return false;
    }

    _neutralSince ??= DateTime.now();
    return DateTime.now().difference(_neutralSince!) >= holdFor;
  }

  bool _completeWhenTurned(Face face, {required bool isMatch}) {
    if (_isNeutral(face)) {
      _poseSince = null;
      return false;
    }

    if (!isMatch) {
      _poseSince = null;
      return false;
    }

    _poseSince ??= DateTime.now();
    return DateTime.now().difference(_poseSince!) >= _poseHoldDuration;
  }

  bool _isNeutral(Face face) {
    final smile = face.smilingProbability ?? 0;
    final leftEye = face.leftEyeOpenProbability ?? 1;
    final rightEye = face.rightEyeOpenProbability ?? 1;
    final headY = face.headEulerAngleY ?? 0;

    return smile < 0.15 &&
        leftEye > 0.7 &&
        rightEye > 0.7 &&
        headY.abs() < _neutralYawDegrees;
  }

  bool _blinkDetected(Face face) {
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;
    final eyesOpen = (leftEye ?? 1) > 0.7 && (rightEye ?? 1) > 0.7;
    final eyesClosed = (leftEye ?? 1) < 0.25 && (rightEye ?? 1) < 0.25;

    if (eyesOpen) {
      _blinkArmed = true;
      return false;
    }

    if (_blinkArmed && eyesClosed) {
      _blinkArmed = false;
      return true;
    }

    return false;
  }

  Future<void> _advanceStep() async {
    if (_takingPicture) {
      return;
    }

    final isLastStep = _currentStepIndex == _steps.length - 1;
    if (isLastStep) {
      await _captureAndFinish();
      return;
    }

    final completedStep = _steps[_currentStepIndex];
    setState(() {
      _statusText =
          '${completedStep.label} complete. Continue with ${_steps[_currentStepIndex + 1].instruction}';
      _currentStepIndex += 1;
      _waitForNeutral = true;
      _neutralSince = null;
    });

    await HapticFeedback.mediumImpact();
  }

  Future<void> _captureAndFinish() async {
    final controller = _controller;
    if (controller == null || _takingPicture) {
      return;
    }

    final navigator = Navigator.of(context);
    setState(() {
      _takingPicture = true;
      _statusText = 'Capturing final selfie...';
    });

    try {
      await controller.stopImageStream();
      final selfie = await controller.takePicture();
      if (!mounted) {
        return;
      }

      await HapticFeedback.heavyImpact();
      navigator.pop(
        KycVerificationResult(
          selfiePath: selfie.path,
          completedSteps: List<KycStepType>.from(_steps),
          completedAt: DateTime.now(),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _takingPicture = false;
          _statusText = 'Could not complete capture: $error';
        });
      }
    }
  }

  @override
  void dispose() {
    _faceDetector?.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final currentStep = _steps[_currentStepIndex];
    final progress = (_currentStepIndex + 1) / _steps.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _initializing || controller == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 18),
                      Text(
                        _statusText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(controller),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.55),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const <double>[0, 0.35, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    left: 18,
                    right: 18,
                    child: _CaptureTopBar(
                      title: 'Identity check',
                      progress: progress,
                      progressLabel:
                          '${_currentStepIndex + 1}/${_steps.length}',
                      onCancel: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: CustomPaint(
                        painter: _FaceFramePainter(),
                        child: const SizedBox(width: 300, height: 390),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 22,
                    child: _CaptureInstructionCard(
                      currentStep: currentStep,
                      statusText: _statusText,
                      smileProbability: _smileProbability,
                      leftEyeProbability: _leftEyeProbability,
                      rightEyeProbability: _rightEyeProbability,
                      headEulerY: _headEulerY,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CaptureTopBar extends StatelessWidget {
  const _CaptureTopBar({
    required this.title,
    required this.progress,
    required this.progressLabel,
    required this.onCancel,
  });

  final String title;
  final double progress;
  final String progressLabel;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                progressLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF2DD4BF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureInstructionCard extends StatelessWidget {
  const _CaptureInstructionCard({
    required this.currentStep,
    required this.statusText,
    required this.smileProbability,
    required this.leftEyeProbability,
    required this.rightEyeProbability,
    required this.headEulerY,
  });

  final KycStepType currentStep;
  final String statusText;
  final double? smileProbability;
  final double? leftEyeProbability;
  final double? rightEyeProbability;
  final double? headEulerY;

  @override
  Widget build(BuildContext context) {
    final confidenceLine = <String>[
      if (smileProbability != null)
        'Smile ${(smileProbability! * 100).toStringAsFixed(0)}%',
      if (leftEyeProbability != null && rightEyeProbability != null)
        'Eyes ${(((leftEyeProbability! + rightEyeProbability!) / 2) * 100).toStringAsFixed(0)}%',
      if (headEulerY != null) 'Pose ${headEulerY!.toStringAsFixed(0)}°',
    ].join('   ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(currentStep.icon, color: const Color(0xFF2DD4BF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentStep.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentStep.instruction,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
            ),
          ),
          if (confidenceLine.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              confidenceLine,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FaceFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    final cutout = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: size.width * 0.72,
            height: size.height * 0.76,
          ),
          const Radius.circular(30),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(cutout, overlayPaint);

    final framePaint = Paint()
      ..color = const Color(0xFF2DD4BF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: size.width * 0.72,
          height: size.height * 0.76,
        ),
        const Radius.circular(30),
      ),
      framePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
