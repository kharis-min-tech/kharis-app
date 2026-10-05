# Anti-slop audit: Kharis member app (round 2)

antislop active: after (session override). The user asked for the rules to be applied and fixed in one pass, so the numbered findings below were fixed straight away rather than waiting for item-by-item approval.

Sources: `antislop.md` (R-01 to R-38), plus the `antislop-ui`, `antislop-copywriting`, `antislop-human` and `antislop-layoutmobile` skills. Direction comes from `DESIGN.md` and `PRODUCT.md`.

What was checked: the member screens in code, plus the simulator screenshots in `/tmp/kharis-shots-polish-ios/` and `/tmp/kharis-shots-polish-android/` (Home, reader, Messages, search, player, More, Giving, Events, New here, Testimony, Notes, Playlist, Feedback, onboarding).

Out of scope (other owners): splash, notifications (screen, provider, service), Studio (`features/admin`, `admin/index.html`).

Contrast was calculated with the WCAG 2.x formula against the theme tokens. It was not judged by eye.

## Direction notes (R-37)

- The uppercase, letter-spaced eyebrows ("TODAY'S READING", "GIVING TO", "YOUR BRANCH") are a documented DESIGN.md choice: `ui(11, w700, 1.1)` in `kc.muted`. R-06 flags this kind of label. It is kept as owner direction and is not counted as a finding.
- The serif italic scripture, the dove watermark on the brand cards and the gold CTA are identity motifs. They are kept.

## Findings

Priority follows the rule tier: Hard Gate = HIGH, Purpose-Gate = MEDIUM, Quality Lock = LOW.

| # | Rule | Pri | File | What failed | Fix | Status |
|---|------|-----|------|-------------|-----|--------|
| 1 | R-38 / C-5 | HIGH | `home/data/reading_plan.dart` | When no prayer was written, the app generated one ("Lord, speak to us through 2 Corinthians 13 today.") and showed it as the "Daily prayer". | No written prayer now means no prayer block. The card and the reader already hide an empty prayer. | Fixed |
| 2 | R-25 | HIGH | `core/theme/kharis_colors.dart`, `app_theme.dart` + 10 screens | `AppColors.danger` was used for error text: 4.4:1 on the light background, 4.06:1 on light inputs, 4.2:1 on ink. | Added a `kc.danger` token: #BE123C on light (5.9:1), #FB7185 on dark (7.3:1). `colorScheme.error` and the input error border now use it, and so do the login, register, connect, edit-profile, feedback, playlist, mini-player and More danger texts. Filled destructive backgrounds keep `AppColors.danger` with white text (4.7:1). | Fixed |
| 3 | R-25 | HIGH | `kharis_colors.dart` (`faint`), `calendar_screen.dart` | `kc.faint` was 2.37:1 on the light background and 3.0:1 on the dark surface, and the calendar used it for caption text. | Raised `faint` to #8C867F (light) and #8A8590 (dark), which clears 3:1 on every surface. Documented it as a non-text token. The calendar cap note now uses `muted`. | Fixed |
| 4 | R-25 | HIGH | `reading_screen.dart`, `calendar_screen.dart`, `event_card.dart`, `sermon_notes_sheet.dart` | Raw `AppColors.primary` was used as text or icon colour on dark surfaces: 2.93:1 on ink, 2.37:1 on the dark surface. The screenshots show "TODAY'S READING", the NIV pill and the Events branch name in this colour. | Switched to `kc.onChip` (10.7:1 on ink). Spinners and the input focus border also use it. | Fixed |
| 5 | R-25 | HIGH | `reading_screen.dart` | The "DAILY PRAYER" label and icon used `hqStroke` (2.37:1 on white). The light-mode verse numbers were 2.95:1. | Label and icon now use `kc.accentInk`. Verse numbers are now #8F6440 (4.8:1). | Fixed |
| 6 | R-25 | HIGH | `profile_completion_card.dart`, `feedback_sheet.dart` | Raw gold (`kc.accent`, 1.9:1 on white) was used for an icon, the "Add" text and the filled rating stars. Empty stars at 60% muted were 2.4 to 2.9:1. | Switched to `kc.accentInk` and full `muted`. | Fixed |
| 7 | R-25 | HIGH | `sermon_notes_sheet.dart` | The swipe-to-delete background was the pale `AppColors.error` with a white icon (1.7:1). | Background is now `AppColors.danger` (4.7:1). | Fixed |
| 8 | R-03 | HIGH | `home_screen.dart` (bell 42), `campus_card.dart` ("Change" 36, address links ~22), `todays_reading_card.dart` (Retry/Read pill ~36), `reading_screen.dart` (version pill 30), `settings_screen.dart` (Edit 34, theme options 40), `calendar_screen.dart` (tab chips 35, branch chip), `event_card.dart` (footer 40), `messages_screen.dart` ("Playlists" and "See all" were bare 12 px text, filter chip 31, sort pills 29), `sermon_list_item.dart` (more button 34), `media_player_screen.dart` (close 40), `player_controls.dart` (speed ~32, repeat 40), `player_actions.dart` (~40), `media_mode_toggle.dart` (34), `mini_player.dart` (42), `like_button.dart` (~28), `role_selection_screen.dart` (privacy link ~32), `profile_completion_card.dart` (compact close), `note_anchor_chip.dart` (20), `sermon_notes_sheet.dart` (seek pill 22) | These tap targets were under 44 px. | Each now has at least a 44 px hit area. Where the visual control already passed, only invisible slack was added, so the visual size is unchanged. | Fixed |
| 9 | R-03 | HIGH | `giving_screen.dart` | The bank rows used a fixed-width value next to an `Expanded` label, so a 22-character IBAN at 1.3x text overflowed a 360 px phone. | The value is now `Expanded`, right-aligned and wraps. | Fixed |
| 10 | R-03 | HIGH | `notes_screen.dart` | The footer row of a note card held a 220 px chip plus the date and could not shrink, so it overflowed on 360 px phones. | The chip area is now `Expanded`, and the chip ellipsises. | Fixed |
| 11 | R-27 | HIGH | `calendar_screen.dart` | The Upcoming and My RSVPs empty states were dead ends. | Added the actions "See past events" and "See upcoming events". | Fixed |
| 12 | R-27 | HIGH | `notes_screen.dart` | The error state had no way forward. | It now says what to do and has a Retry that invalidates `notesProvider`. | Fixed |
| 13 | R-32 / human | HIGH | `settings_screen.dart`, `calendar_screen.dart`, `messages_screen.dart`, `home_screen.dart`, `role_card.dart`, `branch_tile.dart`, `notes_screen.dart` | Several selected states were shown only by colour (theme options, event tabs, sort pills). Several controls had no button semantics or label: the bell, Edit, role cards, branch tiles, the Notes FAB and the More menu pill buttons. The unread dot was colour-only. | Added `Semantics(button, selected)`, labels and tooltips. The bell now announces "Notifications, new items" when the dot is lit. | Fixed |
| 14 | R-16 / copy | LOW | `role_selection_screen.dart` | "How do you journey with Kharis?" uses AI vocabulary ("journey"). | Changed to "How are you connected to Kharis?" | Fixed |
| 15 | R-04 | MEDIUM | `role_selection_screen.dart` | The "New here" role used a sparkle icon (`auto_awesome`). | Uses the waving hand, the same icon as "I'm new here" on More. | Fixed |
| 16 | R-04 | MEDIUM | `messages_screen.dart`, `event_card.dart` | A decorative star sat in front of the "FEATURED" and "Featured" labels, which already say it. | Removed the star. The equaliser glyph stays only for the real now-playing state. | Fixed |
| 17 | UI skill: emoji | MEDIUM | `event_card.dart` | The RSVP toast ended with the 🎉 emoji. | Removed. | Fixed |
| 18 | R-19 / status dot | MEDIUM | `live_now_card.dart` | The LIVE NOW dot pulsed forever. | The dot stays, because it marks a real live state, but it is now static. | Fixed |
| 19 | R-01 / R-29 | MEDIUM | `core/utils/artwork_gradient.dart`, `artwork_image.dart` | Artwork placeholders cycled 10 rainbow gradient pairs (emerald, cyan, sky, olive...), and the screenshots showed a blue-indigo gradient playlist cover. None of these are brand colours. | Replaced with `core/utils/artwork_fill.dart`: three flat brand fills (deep purple, magenta, purple). White glyphs on them are at least 6.7:1. | Fixed |
| 20 | R-29 / R-31 | MEDIUM | `calendar_screen.dart`, `event_card.dart` | Event date chips rotated purple, rose, gold and teal. The colours carried no meaning, DESIGN.md bans teal, and the gold step was 2.37:1 on the white plate. | One brand purple chip (6.7:1). The banner without a photo falls back to the deep brand purple. | Fixed |
| 21 | DESIGN.md (one CTA style) / R-11 | LOW | `announcement_detail.dart`, `event_detail_screen.dart`, `calendar_screen.dart` | Purple filled CTAs, where DESIGN.md says CTAs are gold. | Gold `kc.accent` with `onAccent`. | Fixed |
| 22 | R-11 / spacing | LOW | `new_here_screen.dart`, `testimony_screen.dart` | Buttons used radius 12 instead of `AppRadius.button` (15). | Use `AppRadius.buttonBorder`. | Fixed |
| 23 | R-03 / spacing | LOW | `media_player_screen.dart` | The title row was inset 24 px more than the toggle and seek bar (visible in the screenshots). | Removed the extra inset. | Fixed |
| 24 | spacing | LOW | `giving_screen.dart` | The "Giving" title used a 22 px margin while the cards below used 20. | Changed to 20. | Fixed |
| 25 | spacing | LOW | `connect_form_widgets.dart` | The "Branch" dropdown text sat 14 pt in, while the text-field labels sat 20 pt in (measured on the screenshots). The multi-line testimony label floated in the middle of the box. | Left padding is now 20, and `alignLabelWithHint` is set for multi-line fields. | Fixed |
| 26 | Sentence case | LOW | `settings_screen.dart`, `login_screen.dart`, `register_screen.dart`, `new_here_screen.dart`, `testimony_screen.dart`, `role_selection_screen.dart`, `messages_screen.dart`, `live_now_card.dart`, `notifications_settings_screen.dart` | Labels were in Title Case: "Daily Reading", "My Notes", "My Playlists", "Switch Branch", "Rate & Feedback", "Help & Support", "Privacy Policy", "Admin Console", "Sign In" (next to "Sign in"), "Create Account", "Continue as Guest", "New Here?", "Full Name *", "Email Address", "First Visit Date", "Share Your Testimony", "Your Testimony *", "All Messages", "Live Stream", "Service Reminders". | All changed to sentence case. | Fixed |
| 27 | UK spelling (DESIGN.md) | LOW | `settings_screen.dart`, `favorites_screen.dart`, `favorites_tile.dart`, `like_button.dart` | "Favorites" and "No favorites yet". | Changed to "Favourites". The stored playlist name `Favorites` is data and is unchanged. | Fixed |
| 28 | Copywriting | LOW | `home_screen.dart` | The greeting was addressed to the branch ("Good morning, London") and then showed the placeholder name "Guest" in large type. | The small line now shows the branch (or "Kharis Church"). The large line shows "Good morning" plus the first name, and only when a real name exists. | Fixed |
| 29 | R-15 | LOW | `announcement_detail.dart`, `kharis_api_announcement_repository.dart` | The announcement button fell back to "Learn more". | The app's fallback is now "Open link", and the API read no longer injects "Learn more". | Partly fixed (see "Not fixed") |
| 30 | Copywriting | LOW | `messages_screen.dart` | "Sermons & teachings · streamed from Kharis" was filler, and "streamed" is inaccurate for recordings. "Find encouragement" was a vague heading for a topic list. The search showed "0 results for" directly above "No messages match". The footer used a different separator from the rest of the screen. | Changed to "Sermons and teaching from Kharis Church" and "Browse by topic". The 0-results line is hidden. The footer uses the `·` separator. | Fixed |
| 31 | Copywriting | LOW | `feedback_sheet.dart`, `playlists_screen.dart`, `favorites_screen.dart`, `new_here_screen.dart`, `testimony_screen.dart`, `notifications_settings_screen.dart` | Several unverifiable or filler lines: "We read every note. It shapes what we build next.", "Group messages your way... waiting after every relaunch", "Favourites are your quick go-to", "Welcome to the family!", "Your branch team will reach out soon.", "Thank you for sharing!", "Your daily scripture notification". | Rewritten as plain statements. The notification subtitles now state the real schedules from `pushServiceReminders` and `pushDailyReading`: "An hour before your branch's service starts" and "Today's Bible reading at 7am (UK time)". | Fixed |

### Checked and passing (left alone)

- No em dashes in visible strings. They appear only in code comments and debug logs.
- No visible "Campus".
- No invented statistics. The archive count on the Messages screen ("1,489 messages") comes from the library.
- Giving: "secure" is backed by the giving URL being https-only (`GivingDetails.url`), and the scripture citation is real.
- The Watch, Continue-listening and Live CTAs were already 44 px.
- `muted` text passes everywhere: 4.56 to 6.8:1.

## Not fixed (with reason)

- "Learn more" stored on existing announcements. The Studio web form (`admin/index.html`), `news_repository.toMap` (the Studio write path) and `backend/functions/src/announcements.ts` all write "Learn more" as the default button label. They belong to other owners, so stored labels still read "Learn more".
- DESIGN.md is out of date. It still lists `muted` #8A8580 and `faint` #A8A29B, and it has no `danger` token. It is not in this agent's ownership, so it needs updating to match `kharis_colors.dart`.
- Studio still passes `gradientIndex` to `ArtworkImage`. The parameter name is kept because Studio files call it; it now selects a flat fill.
- Swipe-to-delete on notes has no confirmation, undo or non-swipe alternative. Adding an undo needs a repository restore path, which is a feature change.
- The edit-profile "Avatar image URL" field is functional. Replacing it with an upload flow is a feature change.
- The reading-plan prayer fallback mirrors `planReading` in `backend/functions/src/reading-plans.ts`. The backend may still generate the sentence for pushes; this was not checked or changed (not owned).
- R-35: no device click-through was run this round. The changes are covered by widget tests and analysis, plus the screenshots taken before the changes.

## Verification

- `dart format` on the 55 touched files.
- `flutter analyze lib test integration_test`: No issues found.
- `flutter test` on `test/no_glow_test.dart`, `announcements_home_pipeline_test.dart`, `home_events_navigation_test.dart`, `messages_screen_test.dart`, `tester_round_fixes_test.dart`, `more_giving_onboarding_test.dart`, `favorites_test.dart`, `player_ui_test.dart`, `reading_plan_bounds_test.dart`, `branch_tile_test.dart`, `notifications_settings_test.dart`: all passed. The only failure was "a guest gets Sign in", caused by the sentence-case change making two "Sign in" labels; the test was updated and passes.
- The integration tests (`integration_test/*`) had their text assertions updated but were not run, because they need a device.
