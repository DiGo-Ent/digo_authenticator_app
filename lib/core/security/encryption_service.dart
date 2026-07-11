import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';

class EncryptionService {
  final String _masterKeyHex;

  EncryptionService(this._masterKeyHex);

  // Encrypt a plaintext string using the master key.
  // Returns a base64 encoded string containing IV + encrypted data.
  String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    
    // Convert hex master key back to 32 bytes (256-bit key)
    final keyBytes = _hexToBytes(_masterKeyHex);
    final key = enc.Key(keyBytes);
    
    // Generate a random 16-byte IV
    final iv = enc.IV.fromSecureRandom(16);
    
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    
    // Combined bytes: IV + encrypted data
    final combinedBytes = [...iv.bytes, ...encrypted.bytes];
    return base64.encode(combinedBytes);
  }

  // Decrypt a base64 encoded string (IV + encrypted data) using the master key.
  String decrypt(String cipherTextBase64) {
    if (cipherTextBase64.isEmpty) return '';
    
    final keyBytes = _hexToBytes(_masterKeyHex);
    final key = enc.Key(keyBytes);
    
    final combinedBytes = base64.decode(cipherTextBase64);
    if (combinedBytes.length < 16) {
      throw Exception('Invalid cipher text: too short');
    }
    
    // Extract the first 16 bytes as IV
    final ivBytes = combinedBytes.sublist(0, 16);
    final encryptedBytes = combinedBytes.sublist(16);
    
    final iv = enc.IV(Uint8List.fromList(ivBytes));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    
    final decrypted = encrypter.decrypt(enc.Encrypted(Uint8List.fromList(encryptedBytes)), iv: iv);
    return decrypted;
  }

  // Key derivation using HMAC-SHA-256 password stretching
  static Uint8List deriveKey(String password, String salt, int iterations) {
    final passwordBytes = utf8.encode(password);
    List<int> hash = utf8.encode(salt);
    final hmac = Hmac(sha256, passwordBytes);
    
    for (var i = 0; i < iterations; i++) {
      hash = hmac.convert(hash).bytes;
    }
    return Uint8List.fromList(hash);
  }

  // Encrypt backup data using a custom password key derivation
  static String encryptWithPassword(String plainText, String password, String salt) {
    final keyBytes = deriveKey(password, salt, 2048); // 2048 iterations
    final key = enc.Key(keyBytes);
    final iv = enc.IV.fromSecureRandom(16);
    
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    
    final combinedBytes = [...iv.bytes, ...encrypted.bytes];
    return base64.encode(combinedBytes);
  }

  // Decrypt backup data using a custom password key derivation
  static String decryptWithPassword(String cipherTextBase64, String password, String salt) {
    final keyBytes = deriveKey(password, salt, 2048);
    final key = enc.Key(keyBytes);
    
    final combinedBytes = base64.decode(cipherTextBase64);
    if (combinedBytes.length < 16) {
      throw Exception('Invalid cipher text: too short');
    }
    
    final ivBytes = combinedBytes.sublist(0, 16);
    final encryptedBytes = combinedBytes.sublist(16);
    
    final iv = enc.IV(Uint8List.fromList(ivBytes));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    
    final decrypted = encrypter.decrypt(enc.Encrypted(Uint8List.fromList(encryptedBytes)), iv: iv);
    return decrypted;
  }

  // Helper to convert hex string to Uint8List
  Uint8List _hexToBytes(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }
}
