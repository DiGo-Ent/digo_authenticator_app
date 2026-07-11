import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/security/qr_decoder_service.dart';
import '../../domain/models/otp_account.dart';
import '../providers/authenticator_provider.dart';
import 'screen_snip_overlay.dart';

class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen> {
  final TextEditingController _pasteController = TextEditingController();
  bool _flashOn = false;
  MobileScannerController? _scannerController;
  bool _isScreenScanning = false;

  void _scanDesktopScreen() async {
    setState(() {
      _isScreenScanning = true;
    });

    // Step 1: Capture the screen
    final file = await QrDecoderService.captureScreen();
    if (file == null || !mounted) {
      _showError('Failed to capture desktop screen.');
      setState(() {
        _isScreenScanning = false;
      });
      return;
    }

    setState(() {
      _isScreenScanning = false;
    });

    // Step 2: Open the snipping overlay with the screenshot
    final result = await Navigator.of(context).push<Rect?>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ScreenSnipOverlay(screenshotFile: file);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );

    if (result == null) {
      // User cancelled snipping
      try {
        await file.delete();
      } catch (_) {}
      return;
    }

    // Step 3: Decode QR from the selected region
    final decodedText = QrDecoderService.decodeQrFromImageRegion(
      file,
      x: result.left.toInt(),
      y: result.top.toInt(),
      width: result.width.toInt(),
      height: result.height.toInt(),
    );

    // Cleanup the temp file
    try {
      await file.delete();
    } catch (_) {}

    if (decodedText != null && decodedText.startsWith('otpauth://')) {
      _processUri(decodedText);
    } else {
      _showError('No valid QR code found in the selected area. Try selecting just the QR code.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Only initialize scanner on mobile/macOS platforms where it is supported
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      _scannerController = MobileScannerController();
    }
  }

  @override
  void dispose() {
    _pasteController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final code = barcodes.first.rawValue;
      if (code != null) {
        _processUri(code);
      }
    }
  }

  void _processUri(String uriString) {
    final localizations = AppLocalizations.of(context);
    try {
      final account = OtpAccount.fromUri(uriString);
      ref.read(authenticatorProvider.notifier).addAccount(account);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${account.issuer} added successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.translate('invalid_qr')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Paste URI option
  void _submitPastedUri() {
    _processUri(_pasteController.text);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('scan_qr')),
        actions: [
          if (_scannerController != null)
            IconButton(
              icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
              onPressed: () {
                _scannerController!.toggleTorch();
                setState(() {
                  _flashOn = !_flashOn;
                });
              },
            ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
        child: Column(
          children: [
            if (_scannerController != null && isMobile)
              Container(
                height: 350,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                alignment: Alignment.center,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      'Camera scanner not available on this platform.\nPlease paste the otpauth:// URI below.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

            // Capture Desktop Screen Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _isScreenScanning ? null : _scanDesktopScreen,
                    icon: _isScreenScanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.crop_free_rounded),
                    label: Text(_isScreenScanning ? 'Capturing screen...' : 'Snip & Scan QR from Screen'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Captures your screen, then lets you draw a rectangle around the QR code to scan it.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                  ),
                  const Divider(height: 32),
                ],
              ),
            ),

            // Paste URI Section
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Paste Account URI (otpauth://)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pasteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'otpauth://totp/Issuer:name?secret=BASE32SECRET...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _submitPastedUri,
                    child: Text(localizations.translate('save')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }
}
