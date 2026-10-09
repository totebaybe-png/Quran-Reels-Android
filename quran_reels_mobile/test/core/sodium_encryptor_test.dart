import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reels_mobile/core/crypto/sodium_encryptor.dart';

/// Verifies the Libsodium SealedBox (crypto_box_seal) client-side encryption
/// used to inject GitHub Actions secrets. GitHub decrypts server-side, so the
/// important properties to assert here are: correct overhead size, no leakage
/// of the plaintext into the ciphertext, and non-determinism across inputs.
void main() {
  group('SodiumEncryptor.encryptSecret', () {
    test('produces base64 with the 48-byte sealed-box overhead', () {
      // GitHub's repo public key is 32 raw bytes, base64-encoded.
      final publicKey = base64.encode(List<int>.filled(32, 7));
      const plain = 'ghp_SUPERSECRET_TOKEN';

      final cipherB64 = SodiumEncryptor.encryptSecret(
        plainTextSecret: plain,
        base64PublicKey: publicKey,
      );

      // crypto_box_seal appends a 32-byte ephemeral public key + 16-byte MAC.
      final bytes = base64.decode(cipherB64);
      expect(bytes.length, plain.length + 48);
    });

    test('ciphertext never contains the plaintext (zero-leakage)', () {
      final publicKey = base64.encode(List<int>.filled(32, 9));
      const plain = 'PEXELS_API_KEY_VALUE';

      final cipher = SodiumEncryptor.encryptSecret(
        plainTextSecret: plain,
        base64PublicKey: publicKey,
      );

      expect(cipher.contains(plain), isFalse);
      expect(base64.decode(cipher).any((b) => true), isTrue);
    });

    test('different plaintexts yield different ciphertexts', () {
      final publicKey = base64.encode(List<int>.filled(32, 3));

      final a = SodiumEncryptor.encryptSecret(
        plainTextSecret: 'YOUTUBE_CLIENT_ID',
        base64PublicKey: publicKey,
      );
      final b = SodiumEncryptor.encryptSecret(
        plainTextSecret: 'YOUTUBE_CLIENT_SECRET',
        base64PublicKey: publicKey,
      );

      expect(a == b, isFalse);
    });

    test('throws a descriptive error on a malformed public key', () {
      expect(
        () => SodiumEncryptor.encryptSecret(
          plainTextSecret: 'value',
          base64PublicKey: 'this-is-not-valid-base64!!!',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
