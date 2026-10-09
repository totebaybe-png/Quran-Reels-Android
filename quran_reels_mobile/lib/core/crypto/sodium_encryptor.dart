import 'dart:convert';
import 'package:pinenacl/x25519.dart';

/// Handles client-side encryption of GitHub repository secrets using
/// Libsodium SealedBox (crypto_box_seal) with pure Dart (PineNaCl).
/// Zero plaintext leaks - values are encrypted on device before reaching GitHub REST API.
class SodiumEncryptor {
  /// Encrypts a plaintext secret value with GitHub's base64-encoded public key.
  /// Returns the base64-encoded encrypted payload suitable for PUT /actions/secrets/{SECRET_NAME}
  static String encryptSecret({
    required String plainTextSecret,
    required String base64PublicKey,
  }) {
    try {
      // 1. Decode base64 public key from GitHub (32 bytes)
      final publicKeyBytes = base64.decode(base64PublicKey.trim());

      // 2. Convert secret string to UTF-8 bytes
      final secretBytes = utf8.encode(plainTextSecret);

      // 3. Construct SealedBox with public key
      final sealedBox = SealedBox(PublicKey(publicKeyBytes));

      // 4. Encrypt message (adds 48 bytes ephemeral public key + MAC overhead)
      final encryptedBytes = sealedBox.encrypt(secretBytes);

      // 5. Return base64 string
      return base64.encode(encryptedBytes);
    } catch (e) {
      throw Exception('فشل تشفير السر عبر خوارزمية Libsodium SealedBox: $e');
    }
  }
}
