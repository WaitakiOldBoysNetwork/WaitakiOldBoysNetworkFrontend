import 'package:flutter/widgets.dart';

enum ScreenLayout { mobile, tablet, desktop }

/// Centralized responsive breakpoints for Waitaki Old Boys' Network.
///
/// - Mobile (`< 680px`): bottom navigation bar, mobile app bar, full-screen dialogs,
///   bottom sheets, stacked form fields, and single-column cards.
/// - Tablet (`680px..959px`): compact 76px navigation rail and medium density.
/// - Desktop (`>= 960px`): full 260px collapsible sidebar and multi-column layouts.
class Responsive {
  static const double mobileBreakpoint = 680.0;
  static const double tabletBreakpoint = 960.0;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isMobileWidth(double width) => width < mobileBreakpoint;

  static bool isTabletWidth(double width) =>
      width >= mobileBreakpoint && width < tabletBreakpoint;

  static bool isDesktopWidth(double width) => width >= tabletBreakpoint;

  static bool isMobile(BuildContext context) =>
      isMobileWidth(widthOf(context));

  static bool isTablet(BuildContext context) =>
      isTabletWidth(widthOf(context));

  static bool isDesktop(BuildContext context) =>
      isDesktopWidth(widthOf(context));

  static ScreenLayout layoutOf(BuildContext context) {
    final w = widthOf(context);
    if (isMobileWidth(w)) return ScreenLayout.mobile;
    if (isTabletWidth(w)) return ScreenLayout.tablet;
    return ScreenLayout.desktop;
  }
}
