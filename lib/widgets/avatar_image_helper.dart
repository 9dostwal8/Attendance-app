import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart';

ImageProvider? getAvatarProvider(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.trim().isEmpty) {
    return null;
  }
  final clean = avatarUrl.trim();
  if (clean.startsWith('http://') || clean.startsWith('https://')) {
    return NetworkImage(clean);
  }

  // Local file path support (desktop / mobile non-web)
  if (!kIsWeb && (clean.startsWith('/') || clean.contains(':\\') || clean.contains(':/'))) {
    try {
      final file = File(clean);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (_) {}
  }

  // Base64 image decoding (supports raw base64 and data URLs)
  try {
    String base64Str = clean;
    if (base64Str.contains(',')) {
      base64Str = base64Str.split(',').last;
    }
    base64Str = base64Str.replaceAll(RegExp(r'\s+'), '');
    return MemoryImage(base64Decode(base64Str));
  } catch (e) {
    debugPrint('Error decoding base64 avatar image: $e');
    return null;
  }
}
