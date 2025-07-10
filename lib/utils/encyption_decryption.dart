class VigenereCipher {
  static const String _key = "aswanth_ajmal_sagar"; // Key for encryption

  static String encrypt(String text) {
    StringBuffer encryptedText = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      int charCode = text.codeUnitAt(i);
      int keyCharCode = _key.codeUnitAt(i % _key.length);
      int encryptedCharCode = (charCode + keyCharCode) % 256;
      encryptedText.writeCharCode(encryptedCharCode);
    }
    return encryptedText.toString();
  }

  static String decrypt(String encryptedText) {
    StringBuffer decryptedText = StringBuffer();
    for (int i = 0; i < encryptedText.length; i++) {
      int encryptedCharCode = encryptedText.codeUnitAt(i);
      int keyCharCode = _key.codeUnitAt(i % _key.length);
      int charCode = (encryptedCharCode - keyCharCode) % 256;
      if (charCode < 0) charCode += 256; // Ensure within ASCII range
      decryptedText.writeCharCode(charCode);
    }
    return decryptedText.toString();
  }
}

void main() {
  String original = "Hello0000000000000000, Dart!";
  String encrypted = VigenereCipher.encrypt(original);
  String decrypted = VigenereCipher.decrypt(encrypted);

  print("Original: $original");
  print("Encrypted: $encrypted");
  print("Decrypted: $decrypted");
}
