import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Uri googleSearchUri(String query) {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) {
    throw ArgumentError.value(query, 'query', 'Search query cannot be empty.');
  }
  return Uri.https('www.google.com', '/search', {'q': trimmedQuery});
}

Future<void> openGoogleSearchInBrave(String query) async {
  final searchUri = googleSearchUri(query);

  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      await AndroidIntent(
        action: 'action_view',
        data: searchUri.toString(),
        package: 'com.brave.browser',
      ).launch();
      return;
    } on PlatformException {
      // Fall back to the user's default browser if Brave is not installed.
    }
  }

  if (!await launchUrl(searchUri, mode: LaunchMode.externalApplication)) {
    throw StateError('No browser could open Google Search.');
  }
}
