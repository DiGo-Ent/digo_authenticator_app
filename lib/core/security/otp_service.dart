import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:base32/base32.dart';

class OtpService {
  // Validate if a string is a valid base32 encoded string
  static bool isValidBase32(String secret) {
    final cleaned = secret.toUpperCase().replaceAll(RegExp(r'\s+|-'), '');
    if (cleaned.isEmpty) return false;
    try {
      base32.decode(cleaned);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Generate TOTP code
  static String generateTotp({
    required String secret,
    required int timeMs,
    int timeOffsetMs = 0,
    int period = 30,
    int digits = 6,
    String algorithm = 'SHA1',
  }) {
    final correctedTimeMs = timeMs + timeOffsetMs;
    final counter = (correctedTimeMs ~/ 1000) ~/ period;
    return generateOtp(
      secret: secret,
      counter: counter,
      digits: digits,
      algorithm: algorithm,
    );
  }

  // Generate HOTP code
  static String generateHotp({
    required String secret,
    required int counter,
    int digits = 6,
    String algorithm = 'SHA1',
  }) {
    return generateOtp(
      secret: secret,
      counter: counter,
      digits: digits,
      algorithm: algorithm,
    );
  }

  // General OTP calculation
  static String generateOtp({
    required String secret,
    required int counter,
    required int digits,
    required String algorithm,
  }) {
    final cleanedSecret = secret.toUpperCase().replaceAll(RegExp(r'\s+|-'), '');
    if (cleanedSecret.isEmpty) {
      throw ArgumentError('Secret key cannot be empty');
    }

    Uint8List secretBytes;
    try {
      secretBytes = base32.decode(cleanedSecret);
    } catch (e) {
      throw ArgumentError('Invalid base32 secret: $e');
    }

    // Convert counter to 8-byte big-endian array
    final counterBytes = Uint8List(8);
    var temp = counter;
    for (var i = 7; i >= 0; i--) {
      counterBytes[i] = temp & 0xFF;
      temp = temp >> 8;
    }

    // Map algorithm name to Hash instance
    Hash hash;
    switch (algorithm.toUpperCase()) {
      case 'SHA256':
        hash = sha256;
        break;
      case 'SHA512':
        hash = sha512;
        break;
      case 'SHA1':
      default:
        hash = sha1;
        break;
    }

    // Compute HMAC
    final hmac = Hmac(hash, secretBytes);
    final signature = hmac.convert(counterBytes).bytes;

    // Dynamic truncation
    final offset = signature[signature.length - 1] & 0x0F;
    final binary = ((signature[offset] & 0x7F) << 24) |
                   ((signature[offset + 1] & 0xFF) << 16) |
                   ((signature[offset + 2] & 0xFF) << 8) |
                   (signature[offset + 3] & 0xFF);

    final otpValue = binary % pow(10, digits).toInt();
    return otpValue.toString().padLeft(digits, '0');
  }
}
