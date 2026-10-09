/// Serverless mode: the family key that pairs phones, and the pairing code they exchange.
///
/// Every message between paired phones is encrypted and authenticated with the family's
/// 256-bit key (AES-GCM), so only phones that scanned the pairing code can read or send data.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';

class FamilyKey {
  FamilyKey(this.bytes);
  final List<int> bytes;

  static final _aes = AesGcm.with256bits();

  static FamilyKey generate() {
    final r = math.Random.secure();
    return FamilyKey(List<int>.generate(32, (_) => r.nextInt(256)));
  }

  factory FamilyKey.fromBase64(String s) => FamilyKey(base64Url.decode(s));
  String toBase64() => base64Url.encode(bytes);

  /// nonce (12 bytes) + ciphertext + MAC (16 bytes).
  Future<List<int>> encrypt(List<int> clear) async {
    final box = await _aes.encrypt(clear, secretKey: SecretKey(bytes));
    return box.concatenation();
  }

  /// Throws if the data wasn't made with this key or was changed.
  Future<List<int>> decrypt(List<int> data) async {
    final box = SecretBox.fromConcatenation(data, nonceLength: 12, macLength: 16);
    return _aes.decrypt(box, secretKey: SecretKey(bytes));
  }

  /// A short public tag of the key, so phones can recognize their family's announcements on the
  /// network without revealing the key.
  Future<String> tag() async {
    final hash = await Sha256().hash([...utf8.encode('nestling-tag'), ...bytes]);
    return hash.bytes.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// What a new phone needs to join: the family, its key, and where the inviting phone listens.
class PairingCode {
  PairingCode({required this.familyId, required this.key, required this.hosts, required this.port, required this.name});

  final String familyId;
  final FamilyKey key;
  final List<String> hosts;
  final int port;

  /// The inviting caregiver's name (shown before joining).
  final String name;

  static const _prefix = 'NESTLING1:';

  @override
  String toString() =>
      _prefix + base64Url.encode(utf8.encode(jsonEncode({'f': familyId, 'k': key.toBase64(), 'h': hosts, 'p': port, 'n': name})));

  static PairingCode parse(String text) {
    final t = text.trim();
    if (!t.startsWith(_prefix)) throw const FormatException('This isn\'t a Nestling pairing code.');
    try {
      final j = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(t.substring(_prefix.length)))));
      return PairingCode(
        familyId: j['f'],
        key: FamilyKey.fromBase64(j['k']),
        hosts: [for (final h in j['h'] as List) h as String],
        port: j['p'],
        name: j['n'] ?? '',
      );
    } catch (_) {
      throw const FormatException('This pairing code is incomplete. Copy it again.');
    }
  }
}
