import 'package:flutter/material.dart';

enum ScreenType { mobile, tablet, desktop }

ScreenType getScreenType(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < 600) return ScreenType.mobile;
  if (width < 1200) return ScreenType.tablet;
  return ScreenType.desktop;
}

bool isMobile(BuildContext context) =>
    getScreenType(context) == ScreenType.mobile;
bool isTablet(BuildContext context) =>
    getScreenType(context) == ScreenType.tablet;
bool isDesktop(BuildContext context) =>
    getScreenType(context) == ScreenType.desktop;
