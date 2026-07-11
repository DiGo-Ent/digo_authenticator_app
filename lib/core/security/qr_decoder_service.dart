import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:zxing2/qrcode.dart';

class QrDecoderService {
  // Capture the desktop screen and save to a temporary file
  static Future<File?> captureScreen() async {
    if (kIsWeb) return null;
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/temp_screen_capture.png';
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      if (Platform.isWindows) {
        // Run PowerShell script to capture screen
        final psCommand = '''
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        \$screen = [System.Windows.Forms.Screen]::PrimaryScreen
        \$bounds = \$screen.Bounds
        \$bitmap = New-Object System.Drawing.Bitmap(\$bounds.Width, \$bounds.Height)
        \$graphics = [System.Drawing.Graphics]::FromImage(\$bitmap)
        \$graphics.CopyFromScreen(\$bounds.X, \$bounds.Y, 0, 0, \$bounds.Size)
        \$bitmap.Save("$filePath", [System.Drawing.Imaging.ImageFormat]::Png)
        \$graphics.Dispose()
        \$bitmap.Dispose()
        ''';
        
        final result = await Process.run('powershell', ['-Command', psCommand]);
        if (result.exitCode == 0 && await file.exists()) {
          return file;
        }
      } else if (Platform.isMacOS) {
        final result = await Process.run('screencapture', ['-x', filePath]);
        if (result.exitCode == 0 && await file.exists()) {
          return file;
        }
      } else if (Platform.isLinux) {
        var result = await Process.run('gnome-screenshot', ['-f', filePath]);
        if (result.exitCode != 0) {
          result = await Process.run('scrot', [filePath]);
        }
        if (await file.exists()) {
          return file;
        }
      }
    } catch (e) {
      // Fallback or silent log
    }
    return null;
  }

  // Decode QR code from a file
  static String? decodeQrFromImage(File imageFile) {
    try {
      final bytes = imageFile.readAsBytesSync();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Convert image to LuminanceSource
      final lSource = RGBLuminanceSource(
        image.width,
        image.height,
        image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.abgr).buffer.asInt32List(),
      );

      final bitmap = BinaryBitmap(HybridBinarizer(lSource));
      final reader = QRCodeReader();
      final result = reader.decode(bitmap);
      return result.text;
    } catch (_) {
      // Fallback to GlobalHistogramBinarizer if HybridBinarizer fails
      try {
        final bytes = imageFile.readAsBytesSync();
        final image = img.decodeImage(bytes);
        if (image == null) return null;

        final lSource = RGBLuminanceSource(
          image.width,
          image.height,
          image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.abgr).buffer.asInt32List(),
        );

        final bitmap = BinaryBitmap(GlobalHistogramBinarizer(lSource));
        final reader = QRCodeReader();
        final result = reader.decode(bitmap);
        return result.text;
      } catch (_) {
        // Silent fail
      }
    }
    return null;
  }
}
