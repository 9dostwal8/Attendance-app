import 'dart:convert';
import 'package:flutter/widgets.dart';

ImageProvider? getAvatarProvider(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) {
    return null;
  }
  if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
    return NetworkImage(avatarUrl);
  }
  try {
    return MemoryImage(base64Decode(avatarUrl));
  } catch (e) {
    debugPrint('Error decoding base64 avatar image: $e');
    return null;
  }
}
