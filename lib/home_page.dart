import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'kyc_liveness_capture_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  PermissionStatus? _cameraPermission;
  bool _checkingPermission = true;
  bool _startingVerification = false;
  KycVerificationResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _refreshPermissionStatus();
  }

  Future<void> _refreshPermissionStatus() async {
    final status = await Permission.camera.status;
    if (!mounted) {
      return;
    }
    setState(() {
      _cameraPermission = status;
      _checkingPermission = false;
    });
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) {
      return;
    }
    setState(() {
      _cameraPermission = status;
    });
    if (status.isGranted) {
      await _startVerification();
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
    await _refreshPermissionStatus();
  }

  Future<void> _startVerification() async {
    final permission = _cameraPermission ?? await Permission.camera.status;
    if (!permission.isGranted) {
      await _requestPermission();
      return;
    }

    if (_startingVerification) {
      return;
    }

    if (!mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    setState(() {
      _startingVerification = true;
    });

    try {
      final result = await navigator.push<KycVerificationResult>(
        MaterialPageRoute(builder: (_) => const KycLivenessCapturePage()),
      );

      if (!mounted || result == null) {
        return;
      }

      setState(() {
        _lastResult = result;
      });
    } finally {
      if (mounted) {
        setState(() {
          _startingVerification = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final permission = _cameraPermission;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _BackgroundDecoration()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderCard(
                    title: 'KYC onboarding',
                    subtitle:
                        'Capture a live selfie, verify liveness, and prepare the user for secure account onboarding.',
                    badge: 'Flutter + ML Kit',
                    onTap: _startVerification,
                    isBusy: _startingVerification,
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(
                    title: 'Verification steps',
                    subtitle:
                        'The flow is designed to confirm that the person in front of the device is physically present.',
                  ),
                  const SizedBox(height: 12),
                  const _StepGrid(),
                  const SizedBox(height: 18),
                  _PermissionCard(
                    status: permission,
                    isChecking: _checkingPermission,
                    onRequestPermission: _requestPermission,
                    onOpenSettings: _openSettings,
                  ),
                  const SizedBox(height: 18),
                  if (_lastResult != null) ...[
                    _SectionTitle(
                      title: 'Latest verification',
                      subtitle:
                          'The most recent completed session is shown below for quick QA during development.',
                    ),
                    const SizedBox(height: 12),
                    _ResultCard(result: _lastResult!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFF3F7FB),
            Color(0xFFE8F6F7),
            Color(0xFFF8FAFC),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
    required this.isBusy,
  });

  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0B3D44), Color(0xFF118AB2)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0B3D44).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isBusy ? null : onTap,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0B3D44),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                isBusy ? 'Starting...' : 'Start verification',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF5B6473),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _StepGrid extends StatelessWidget {
  const _StepGrid();

  @override
  Widget build(BuildContext context) {
    const steps = <_StepInfo>[
      _StepInfo(
        icon: Icons.face_retouching_natural_outlined,
        title: 'Live face',
        description: 'Center your face in the frame.',
      ),
      _StepInfo(
        icon: Icons.emoji_emotions_outlined,
        title: 'Smile',
        description: 'Trigger an expression check.',
      ),
      _StepInfo(
        icon: Icons.visibility_off_outlined,
        title: 'Blink',
        description: 'Prove the image is live.',
      ),
      _StepInfo(
        icon: Icons.keyboard_arrow_left,
        title: 'Turn left',
        description: 'Rotate your head slightly.',
      ),
      _StepInfo(
        icon: Icons.keyboard_arrow_right,
        title: 'Turn right',
        description: 'Rotate the opposite way.',
      ),
      _StepInfo(
        icon: Icons.center_focus_strong,
        title: 'Look straight',
        description: 'Finish with a neutral pose.',
      ),
    ];

    return GridView.builder(
      itemCount: steps.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 150,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final step = steps[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE4E8EF)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F6F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(step.icon, color: const Color(0xFF0F8B8D)),
              ),
              const SizedBox(height: 12),
              Text(
                step.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step.description,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF5B6473),
                  height: 1.35,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepInfo {
  const _StepInfo({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.status,
    required this.isChecking,
    required this.onRequestPermission,
    required this.onOpenSettings,
  });

  final PermissionStatus? status;
  final bool isChecking;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final isGranted = status?.isGranted ?? false;
    final isPermanentlyDenied = status?.isPermanentlyDenied ?? false;
    final label = isChecking
        ? 'Checking camera permission...'
        : isGranted
        ? 'Camera permission granted'
        : isPermanentlyDenied
        ? 'Camera permission blocked'
        : 'Camera permission needed';
    final message = isChecking
        ? 'We need to confirm whether the camera is available before starting the KYC flow.'
        : isGranted
        ? 'You are ready to start liveness verification.'
        : isPermanentlyDenied
        ? 'Open system settings, allow camera access, and come back to continue the verification.'
        : 'Grant camera access to continue with face capture and liveness checks.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4E8EF)),
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
                  color: isGranted
                      ? const Color(0xFFE6F8F0)
                      : const Color(0xFFFFF2E8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isGranted ? Icons.verified_outlined : Icons.videocam_outlined,
                  color: isGranted
                      ? const Color(0xFF15803D)
                      : const Color(0xFFB45309),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF5B6473),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: isGranted ? null : onRequestPermission,
                  child: Text(
                    isGranted ? 'Permission ready' : 'Grant camera access',
                  ),
                ),
              ),
              if (isPermanentlyDenied) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onOpenSettings,
                  child: const Text('Open settings'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final KycVerificationResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(result.selfiePath),
                  width: 88,
                  height: 110,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verification complete',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Finished at ${result.completedAt.toLocal()}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF5B6473),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: result.completedSteps
                          .map(
                            (step) => Chip(
                              label: Text(step.label),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
