/// App-wide constants that aren't tied to theme (see theme/app_theme.dart)
/// or a specific screen. Change a value once here and every place that
/// reads it picks up the change.
class AppConstants {
  AppConstants._();

  // Display name for this (customer-facing) app — the companion
  // professional-facing app is a separate build with its own name.
  static const String appName = 'AI Double';

  // Simulated AI response timings, used by ConvoRepository — tune once here
  // to make the AI feel snappier/slower across every intake and chat flow.
  static const Duration aiTypingDelay = Duration(milliseconds: 850);
  static const Duration aiReplyDelay = Duration(milliseconds: 400);
  static const Duration aiFollowupDelay = Duration(milliseconds: 300);
  static const Duration proGreetDelay = Duration(milliseconds: 700);
}
