import 'dart:typed_data';

/// Non-web platforms: open the app in Chrome/web for PDF export, or extend with platform save.
Future<void> downloadPdfBytes(Uint8List bytes, String filename) async {
  throw UnsupportedError(
    'PDF download is available when running on web (Chrome). Filename: $filename',
  );
}
