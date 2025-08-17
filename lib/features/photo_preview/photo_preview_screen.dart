// lib/screens/photo_preview_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:dvapp/core/services/photo_validator_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/photo_error_card.dart';
import '../widgets/compliance_meter.dart';
import '../widgets/photo_guide_overlay.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

class PhotoPreviewScreen extends StatefulWidget {
  final String imagePath;
  final bool isBabyMode;

  const PhotoPreviewScreen({
    Key? key,
    required this.imagePath,
    this.isBabyMode = false,
  }) : super(key: key);

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen>
    with SingleTickerProviderStateMixin {
  bool _isValidating = true;
  PhotoValidationResult? _validationResult;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showGuideLines = true;
  bool _showErrors = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _validatePhoto();
  }

  Future<void> _validatePhoto() async {
    setState(() => _isValidating = true);

    final result = await PhotoValidatorService.validatePhoto(
      widget.imagePath,
      isBabyMode: widget.isBabyMode,
    );

    setState(() {
      _validationResult = result;
      _isValidating = false;
    });

    _animationController.forward();

    // Vibrate if errors found
    if (result.errors.isNotEmpty) {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _saveToGallery() async {
    try {
      // Request permissions
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }

      // Save to gallery using gal package
      await Gal.putImage(widget.imagePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo saved to gallery'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _retakePhoto() {
    Navigator.pop(context, 'retake');
  }

  void _acceptPhoto() {
    if (_validationResult?.isValid ?? false) {
      Navigator.pop(context, 'accept');
    } else {
      _showConfirmationDialog();
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Photo Has Issues'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your photo has ${_validationResult?.errors.length ?? 0} issue(s) that may cause rejection.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to continue with this photo?',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, 'accept');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Continue Anyway'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Photo with overlay
            Expanded(
              child: Stack(
                children: [
                  // Photo
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Original photo
                        Container(
                          margin: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(widget.imagePath),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        // Guide overlay
                        if (_showGuideLines && !_isValidating)
                          PhotoGuideOverlay(
                            showGuides: _showGuideLines,
                            validationResult: _validationResult,
                            isBabyMode: widget.isBabyMode,
                          ),
                      ],
                    ),
                  ),

                  // Loading overlay
                  if (_isValidating)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                            SizedBox(height: 20),
                            Text(
                              'Analyzing photo...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Validation results
            if (!_isValidating && _validationResult != null)
              _buildValidationResults(),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: Text(
              'DV Photo Tool',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() => _showGuideLines = !_showGuideLines);
                },
                icon: Icon(
                  _showGuideLines ? Icons.grid_on : Icons.grid_off,
                  color: Colors.white,
                ),
                tooltip: 'Toggle guide lines',
              ),
              IconButton(
                onPressed: _saveToGallery,
                icon: const Icon(Icons.save_alt, color: Colors.white),
                tooltip: 'Save to gallery',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValidationResults() {
    if (_validationResult == null) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.35,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Status header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    _validationResult!.isValid
                        ? Icons.check_circle
                        : Icons.warning_amber,
                    color: _validationResult!.isValid
                        ? Colors.green
                        : Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _validationResult!.isValid
                              ? 'Photo Looks Good!'
                              : 'Photo Needs Improvement',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!_validationResult!.isValid)
                          Text(
                            'Please fix the issues below and retake',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Compliance meter
            if (!_validationResult!.isValid)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ComplianceMeter(
                  score: _validationResult!.complianceScore,
                  animate: true,
                ),
              ),

            // Error list
            if (_validationResult!.errors.isNotEmpty && _showErrors)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  itemCount: _validationResult!.errors.length,
                  itemBuilder: (context, index) {
                    return PhotoErrorCard(
                      error: _validationResult!.errors[index],
                      index: index,
                    );
                  },
                ),
              ),

            // Success message
            if (_validationResult!.isValid)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your photo meets all DV requirements!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Compliance Score: ${_validationResult!.complianceScore.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final hasErrors = _validationResult?.errors.isNotEmpty ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _retakePhoto,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: hasErrors ? Colors.blue : Colors.grey,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Retake',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: hasErrors ? Colors.blue : Colors.grey[700],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isValidating ? null : _acceptPhoto,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: hasErrors ? Colors.orange : Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              child: Text(
                hasErrors ? 'Accept' : 'Accept',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
