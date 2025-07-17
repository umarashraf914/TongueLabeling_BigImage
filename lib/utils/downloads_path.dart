import 'package:flutter/services.dart';

class DownloadsPath {
  static const MethodChannel _channel = MethodChannel('custom_downloads_path');

  static Future<String?> getDownloadsDirectory() async {
    final String? path = await _channel.invokeMethod('getDownloadsDirectory');
    return path;
  }
}
