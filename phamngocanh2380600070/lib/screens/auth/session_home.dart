import 'package:flutter/material.dart';

import '../child/child_home_screen.dart';
import '../parent/parent_home_screen.dart';

void openSessionHome(BuildContext context, String role) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) =>
          role == 'Parent' ? const ParentHomeScreen() : const ChildHomeScreen(),
    ),
    (route) => false,
  );
}
