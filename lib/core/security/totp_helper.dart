import "dart:math";
import "dart:typed_data";
import "package:crypto/crypto.dart";

/// RFC 6238 compliant Time-Based One-Time Password (TOTP) generator
/// and RFC 4648 Base32 decoder for 2FA / SSH keyboard-interactive authentication.
class TotpHelper {
  static const String _base32Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

  /// Validates whether the given string is a plausible Base32 TOTP secret.
  static bool isValidSecret(String? secret) {
    if (secret == null) return false;
    final clean = secret.toUpperCase().replaceAll(RegExp(r"[\s-]"), "").replaceAll("=", "");
    if (clean.length < 8) return false;
    for (int i = 0; i < clean.length; i++) {
      if (!_base32Chars.contains(clean[i])) {
        return false;
      }
    }
    return true;
  }

  /// Decodes an RFC 4648 Base32 encoded secret into raw bytes.
  static Uint8List base32Decode(String input) {
    final clean = input.toUpperCase().replaceAll(RegExp(r"[\s-]"), "").replaceAll("=", "");
    if (clean.isEmpty) {
      return Uint8List(0);
    }

    final List<int> bytes = [];
    int buffer = 0;
    int bitsLeft = 0;

    for (int i = 0; i < clean.length; i++) {
      final char = clean[i];
      final val = _base32Chars.indexOf(char);
      if (val < 0) {
        throw FormatException("Invalid Base32 character: $char");
      }

      buffer = (buffer << 5) | val;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        bytes.add((buffer >> bitsLeft) & 0xFF);
      }
    }

    return Uint8List.fromList(bytes);
  }

  /// Generates a 6-digit (or [digits]) TOTP code for the given [base32Secret] and [time].
  static String generateTotp(
    String base32Secret, {
    DateTime? time,
    int period = 30,
    int digits = 6,
  }) {
    if (!isValidSecret(base32Secret)) {
      throw const FormatException("Invalid Base32 secret for TOTP generation");
    }

    final secretBytes = base32Decode(base32Secret);
    final targetTime = time ?? DateTime.now();
    final timeSeconds = targetTime.millisecondsSinceEpoch ~/ 1000;
    final counter = timeSeconds ~/ period;

    // Convert 64-bit integer counter to 8 big-endian bytes
    final counterBytes = Uint8List(8);
    final bdata = ByteData.view(counterBytes.buffer);
    bdata.setUint64(0, counter, Endian.big);

    // Compute HMAC-SHA1
    final hmac = Hmac(sha1, secretBytes);
    final hash = hmac.convert(counterBytes).bytes;

    // Dynamic truncation (RFC 4226)
    final offset = hash[hash.length - 1] & 0x0F;
    final binary = ((hash[offset] & 0x7F) << 24) |
        ((hash[offset + 1] & 0xFF) << 16) |
        ((hash[offset + 2] & 0xFF) << 8) |
        (hash[offset + 3] & 0xFF);

    final modulo = pow(10, digits).toInt();
    final otp = binary % modulo;
    return otp.toString().padLeft(digits, "0");
  }

  /// Calculates remaining seconds before the current TOTP window expires (1 to [period]).
  static int remainingSeconds({DateTime? time, int period = 30}) {
    final now = time ?? DateTime.now();
    final epochSec = now.millisecondsSinceEpoch ~/ 1000;
    final remainder = epochSec % period;
    return period - remainder;
  }

  /// Calculates the fraction of time elapsed in the current window (0.0 to 1.0).
  static double windowProgress({DateTime? time, int period = 30}) {
    final rem = remainingSeconds(time: time, period: period);
    return rem / period;
  }

  /// Formats a 6-digit OTP as "123 456" for enhanced readability.
  static String formatCode(String code) {
    if (code.length == 6) {
      return "${code.substring(0, 3)} ${code.substring(3)}";
    }
    return code;
  }
}
