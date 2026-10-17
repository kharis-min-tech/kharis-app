import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/connect/data/connect_repository.dart';
import 'package:kharis_app/features/connect/presentation/screens/new_here_screen.dart';
import 'package:kharis_app/features/connect/presentation/screens/testimony_screen.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_screen.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';

import '../support/actions.dart';
import '../support/channels.dart';
import '../support/harness.dart';
import '../support/live_data.dart';

/// (h) Giving: no branch picker; Give securely hands kharis.org to the
/// browser (external mode); Copy bank details fills the clipboard.
Future<void> givingJourney(Journey j) async {
  final t = j.tester;
  final branches = await studioBranches();
  await j.launch(branch: pick(seeded(effectiveSeed, 'giving'), branches).name);
  await tapNav(t, 'Giving');
  await pumpUntilFound(t, find.byType(GivingScreen));
  await pumpFor(t, const Duration(seconds: 1));
  final giving = find.byType(GivingScreen);
  final scroll = find
      .descendant(of: giving, matching: find.byType(Scrollable))
      .first;
  j.check(
    find
            .descendant(of: giving, matching: find.text('YOUR BRANCH'))
            .evaluate()
            .isEmpty &&
        find
            .descendant(of: giving, matching: find.text('GIVING TO'))
            .evaluate()
            .isEmpty,
    'Giving has no branch picker',
  );
  await j.shot('giving');

  final give = find.descendant(
    of: giving,
    matching: find.text('Give securely'),
  );
  await scrollUntilFound(t, give, scrollable: scroll);
  await t.tap(give, warnIfMissed: false);
  await pumpUntil(
    t,
    () => launches.isNotEmpty,
    timeout: const Duration(seconds: 5),
  );
  j.check(
    launches.length == 1 &&
        launches.single.url == kGivingUrl &&
        launches.single.external,
    'Give securely opens $kGivingUrl in the external browser (got $launches)',
  );

  final copy = find.descendant(
    of: giving,
    matching: find.text('Copy bank details'),
  );
  await scrollUntilFound(t, copy, scrollable: scroll);
  await Clipboard.setData(const ClipboardData(text: ''));
  await t.tap(copy, warnIfMissed: false);
  j.check(
    await pumpUntil(
      t,
      () => find.text('Bank details copied').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 5),
      step: const Duration(milliseconds: 100),
    ),
    'copy confirms "Bank details copied"',
  );
  final clip = await Clipboard.getData(Clipboard.kTextPlain);
  // Bank values are SelectableText (EditableText), labels are plain text.
  final shown = <String>{
    ...paintedTexts(within: giving),
    for (final w in t.widgetList<SelectableText>(
      find.descendant(of: giving, matching: find.byType(SelectableText)),
    ))
      w.data ?? '',
  };
  final lines = (clip?.text ?? '')
      .split('\n')
      .where((l) => l.contains(': '))
      .toList();
  final missing = [
    for (final l in lines)
      if (!shown.contains(l.substring(0, l.indexOf(': '))) ||
          !shown.contains(l.substring(l.indexOf(': ') + 2)))
        l,
  ];
  j.check(
    lines.length >= 3 && missing.isEmpty,
    'clipboard holds the ${lines.length} bank rows shown on screen '
    '(${clip?.text?.replaceAll('\n', ' / ')}; not on screen: $missing)',
  );
  await j.shot('copied');
}

// ── Forms ────────────────────────────────────────────────────────────────────

/// Answers every request with 201 and records it; nothing leaves the device.
class _StubAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString('', 201);
  }

  @override
  void close({bool force = false}) {}
}

Finder _field(Finder screen, String hint, [int index = 0]) => find
    .descendant(
      of: screen,
      matching: find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == hint,
      ),
    )
    .at(index);

/// Closes the keyboard (it shrinks the viewport and swallows the tap while
/// it animates away), then taps the submit button.
Future<void> _submit(WidgetTester t, Finder screen, String label) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(t, const Duration(milliseconds: 700));
  final button = find.descendant(of: screen, matching: find.text(label));
  await tapVisible(t, button);
  await pumpFor(t, const Duration(milliseconds: 900));
}

/// Focuses [field] first: after the keyboard was closed, entering text
/// straight away can reach the previously attached field.
Future<void> _type(WidgetTester t, Finder field, String text) async {
  await t.ensureVisible(field);
  await t.tap(field, warnIfMissed: false);
  await pumpFor(t, const Duration(milliseconds: 500));
  await t.enterText(field, text);
  await pumpFor(t, const Duration(milliseconds: 300));
}

bool _shows(Finder screen, String text) => find
    .descendant(of: screen, matching: find.text(text, skipOffstage: false))
    .evaluate()
    .isNotEmpty;

/// "hint=text!error" for every text field, for failure messages.
List<String> _fieldStates(WidgetTester t, Finder screen) => [
  for (final w in t.widgetList<TextField>(
    find.descendant(
      of: screen,
      matching: find.byType(TextField, skipOffstage: false),
    ),
  ))
    '${w.decoration?.hintText}="${w.controller?.text}"!${w.decoration?.errorText}',
];

Future<void> _choose(
  WidgetTester t,
  Finder screen,
  String hint,
  String item,
) async {
  await tapVisible(t, find.descendant(of: screen, matching: find.text(hint)));
  await pumpFor(t, const Duration(milliseconds: 800));
  final entry = find.text(item);
  await pumpUntilFound(t, entry);
  await t.tap(entry.last, warnIfMissed: false);
  await pumpFor(t, const Duration(milliseconds: 800));
}

/// (i) New here and testimony forms: required fields, bad email, length
/// limits, then a submission with the network layer stubbed (Dio adapter):
/// nothing is posted to the live Studio.
Future<void> formsJourney(Journey j) async {
  final t = j.tester;
  final stub = _StubAdapter();
  final dio = Dio()..httpClientAdapter = stub;
  final branches = await studioBranches();
  final branch = pick(seeded(effectiveSeed, 'forms'), branches);
  await j.launch(
    overrides: [
      connectRepositoryProvider.overrideWithValue(ConnectRepository(dio: dio)),
    ],
  );
  j.note(
    'submissions go to a stubbed Dio adapter; the live insert (and its '
    'RLS policy) is not exercised here',
  );

  // ── New here ─────────────────────────────────────────────────────────────
  await openMoreRow(t, "I'm new here");
  final newHere = find.byType(NewHereScreen);
  await pumpUntilFound(t, newHere);
  await _submit(t, newHere, 'Connect with us');
  j.check(_shows(newHere, 'Name is required'), 'new here: name required');
  j.check(_shows(newHere, 'Email is required'), 'new here: email required');
  j.check(stub.requests.isEmpty, 'new here: invalid form sends nothing');
  await j.shot('new-here-required');
  await _type(t, _field(newHere, 'Your name'), 'E2E Visitor');
  await _type(t, _field(newHere, 'you@example.com'), 'not-an-email');
  await _submit(t, newHere, 'Connect with us');
  j.check(
    _shows(newHere, 'Enter a valid email'),
    'new here: bad email rejected',
  );
  j.check(!_shows(newHere, 'Name is required'), 'new here: name error clears');
  j.check(stub.requests.isEmpty, 'new here: bad email sends nothing');
  await _type(t, _field(newHere, 'you@example.com'), 'e2e@example.invalid');
  await _choose(t, newHere, 'Choose your branch', branch.name);
  await _submit(t, newHere, 'Connect with us');
  j.check(
    await pumpUntil(
      t,
      () => find.text('Welcome to Kharis').evaluate().isNotEmpty,
    ),
    'new here: success screen',
  );
  final visitor = stub.requests.isEmpty ? null : stub.requests.last;
  final visitorBody = visitor?.data is String
      ? jsonDecode(visitor!.data as String)
      : visitor?.data;
  j.check(
    visitor != null &&
        visitor.method == 'POST' &&
        visitor.uri.path.endsWith('/rest/v1/visitors') &&
        visitorBody is Map &&
        visitorBody['name'] == 'E2E Visitor' &&
        visitorBody['email'] == 'e2e@example.invalid' &&
        visitorBody['branch_name'] == branch.name,
    'new here: posts the visitor row (${visitor?.uri} $visitorBody)',
  );
  await j.shot('new-here-sent');
  await t.tap(find.text('Done').last, warnIfMissed: false);
  await pumpFor(t, const Duration(seconds: 1));
  await j.resetTo('/more');

  // ── Testimony ────────────────────────────────────────────────────────────
  stub.requests.clear();
  await openMoreRow(t, 'Share a testimony');
  final testimony = find.byType(TestimonyScreen);
  await pumpUntilFound(t, testimony);
  await _submit(t, testimony, 'Share testimony');
  for (final msg in const [
    'Name is required',
    'Branch is required',
    'Add a short title',
    'Please share your testimony',
    'Please confirm we may share your testimony',
  ]) {
    j.check(_shows(testimony, msg), 'testimony: "$msg"');
  }
  j.check(stub.requests.isEmpty, 'testimony: invalid form sends nothing');
  await j.shot('testimony-required');
  await _type(t, _field(testimony, 'Your name'), 'E2E Member');
  await _type(t, _field(testimony, 'Optional', 0), 'bad@');
  await _submit(t, testimony, 'Share testimony');
  j.check(
    _shows(testimony, 'Enter a valid email'),
    'testimony: bad email rejected (fields: ${_fieldStates(t, testimony)})',
  );
  await _type(t, _field(testimony, 'Optional', 0), '');

  final summary = _field(testimony, 'e.g. Healed after surgery');
  await _type(t, summary, 'S' * (kTestimonySummaryMaxLength + 30));
  await pumpFor(t, const Duration(milliseconds: 400));
  final summaryLen = t.widget<TextField>(summary).controller?.text.length;
  j.check(
    summaryLen == kTestimonySummaryMaxLength,
    'summary stops at $kTestimonySummaryMaxLength characters (got $summaryLen)',
  );
  final story = _field(testimony, 'Tell us what God has done');
  await _type(t, story, 'T' * (kTestimonyMaxLength + 100));
  await pumpFor(t, const Duration(milliseconds: 400));
  final storyLen = t.widget<TextField>(story).controller?.text.length;
  j.check(
    storyLen == kTestimonyMaxLength,
    'testimony stops at $kTestimonyMaxLength characters (got $storyLen)',
  );
  await _type(t, summary, 'E2E summary');
  await _type(t, story, 'E2E testimony text, never posted.');
  await _choose(t, testimony, 'Choose your branch', branch.name);
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(t, const Duration(milliseconds: 700));
  await tapVisible(
    t,
    find.descendant(
      of: testimony,
      matching: find.text('I am happy for Kharis to share my testimony'),
    ),
  );
  await pumpFor(t, const Duration(milliseconds: 400));
  await _submit(t, testimony, 'Share testimony');
  j.check(
    await pumpUntil(
      t,
      () => find.text('Thank you for sharing').evaluate().isNotEmpty,
    ),
    'testimony: success screen',
  );
  final sent = stub.requests.isEmpty ? null : stub.requests.last;
  final body = sent?.data is String
      ? jsonDecode(sent!.data as String)
      : sent?.data;
  j.check(
    sent != null &&
        sent.uri.path.endsWith('/rest/v1/testimonies') &&
        body is Map &&
        body['name'] == 'E2E Member' &&
        body['branch_name'] == branch.name &&
        body['short_description'] == 'E2E summary' &&
        body['is_published'] == false,
    'testimony: posts an unpublished row (${sent?.uri} $body)',
  );
  await j.shot('testimony-sent');
}
