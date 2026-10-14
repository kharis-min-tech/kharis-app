// On-device end-to-end journeys against the live backends (Content Studio,
// sermon API, R2, YouVersion, Firebase). One `testWidgets` per journey, each
// launching the app from a clean slate, so a failure in one never stops the
// rest. Expectations are read from the live sources at run time.
//
// Run (from app/):   scripts/run_e2e.sh ios|android [journey ...]
// Journeys: onboarding branch_switch events messages player playlists bible
//           giving forms deep_links display account more_menu notifications

import 'package:integration_test/integration_test.dart';

import 'journeys/account_more_notifications.dart';
import 'journeys/bible.dart';
import 'journeys/branch_switch.dart';
import 'journeys/deep_links.dart';
import 'journeys/display.dart';
import 'journeys/events.dart';
import 'journeys/giving_forms.dart';
import 'journeys/messages.dart';
import 'journeys/onboarding.dart';
import 'journeys/player.dart';
import 'journeys/playlists.dart';
import 'support/harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  journey('onboarding', 'fresh install: role path, guest path, branch groups', onboardingJourney);
  journey('branch_switch', 'switch branch from More; Home and events follow', branchSwitchJourney);
  journey('events', 'upcoming / past / RSVPs, detail, directions, calendar, RSVP', eventsJourney);
  journey('messages', 'archive, search, filters, sort, pull to refresh', messagesJourney);
  journey('player', 'play, seek, skip, audio/video, notes, share, mini player, transcript', playerJourney);
  journey('playlists', 'playlist lifecycle and favourites', playlistsJourney);
  journey('bible', 'today, search, browse, book boundary, translation', bibleJourney);
  journey('giving', 'no branch picker, give securely, copy bank details', givingJourney);
  journey('forms', 'new here and testimony validation and stubbed submission', formsJourney);
  journey('deep_links', 'shared /m /e /a links and not-found', deepLinksJourney);
  journey('display', 'light/dark and large text without layout errors', displayJourney);
  journey('account', 'guest has no Delete account; member delete flow (faked)', accountJourney);
  journey('more_menu', 'every More row opens and returns', moreMenuJourney);
  journey('notifications', 'inbox and notification link routing', notificationsJourney);
}
