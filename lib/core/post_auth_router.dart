import 'package:flutter/material.dart';

import '../main.dart';
import 'api_client.dart';
import 'member_entry_route.dart';

/// Where a member lands once they are authenticated.
///
/// Every door — password, mobile OTP, Google — ends here. The decision is made
/// from the profile the server returns, never from what the door happened to
/// know: a member who signed up with Google months ago and one who just typed a
/// password get the same treatment, because at this point they are the same
/// thing, an authenticated member with or without a profile.
enum PostAuthDestination {
  /// Profile exists — the member goes into the app.
  home,

  /// Authenticated but no profile yet — onboarding.
  onboarding,

  /// Could not tell; the caller shows [failureMessage] and stays put.
  failed,
}

class PostAuthOutcome {
  const PostAuthOutcome(this.destination, {this.route, this.failureMessage});

  final PostAuthDestination destination;

  /// The route to navigate to, set for everything but [PostAuthDestination.failed].
  final String? route;

  final String? failureMessage;
}

/// Asks the server whether this member has a profile, and turns the answer into
/// a destination.
///
/// Deliberately does no navigating and touches no widget state — callers differ
/// in how they report progress, and a helper that grabbed a `BuildContext`
/// would force them all into one shape.
Future<PostAuthOutcome> resolvePostAuthDestination() async {
  final profileResult = await ApiClient.getMyProfile();
  final statusCode = profileResult['statusCode'];

  if (statusCode == 404) {
    return const PostAuthOutcome(
      PostAuthDestination.onboarding,
      route: '/smart-onboarding',
    );
  }

  if (statusCode == 200 && profileResult['success'] == true) {
    return PostAuthOutcome(
      PostAuthDestination.home,
      route: await resolveCompletedMemberRoute(),
    );
  }

  return PostAuthOutcome(
    PostAuthDestination.failed,
    failureMessage: profileResult['message']?.toString(),
  );
}

/// Sends the member to [route], clearing the auth screens behind them.
void navigateAfterAuth(BuildContext context, String route) {
  enterMemberApp(Navigator.of(context), route);
}
