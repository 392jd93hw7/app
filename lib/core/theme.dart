import 'package:flutter/material.dart';

const appBg = Color(0xFF090A12),
    appPanel = Color(0xFF151727),
    appPurple = Color(0xFF9B70FF),
    appCyan = Color(0xFF61DDF5),
    appMuted = Color(0xFF999CB0);
ThemeData buildAniTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: appBg,
  colorScheme: const ColorScheme.dark(
    primary: appPurple,
    secondary: appCyan,
    surface: appPanel,
  ),
  useMaterial3: true,
);
