import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'home_screen_mobile.dart';
import 'home_screen_web.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const HomeScreenWeb();
    } else {
      return const HomeScreenMobile();
    }
  }
}
