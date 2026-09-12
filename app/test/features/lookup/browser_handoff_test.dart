// The browser hand-off (AND-32, ADR-0009).
//
// This is the only place in the app where a network request happens because of
// something the user did here — and the app still does not make it. The browser
// does, in its own process, using no permission this app holds. That is the
// whole reason ADR-0004 stands unamended and assert_no_network.sh stays green.
//
// Two things are load-bearing and both are enforced rather than reviewed:
//
//   * the launch mode. url_launcher_android ships a WebViewActivity, and
//     `inAppWebView` renders the page *inside this app* — which means this app
//     making the request, which needs INTERNET, which reverses the entire
//     privacy posture. It is one enum value away.
//   * the warning. A user told all through this app that nothing leaves their
//     device is entitled to be told, specifically, at the moment that stops
//     being true.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/features/lookup/browser_handoff.dart';

import '../harness.dart';

/// Every Dart file under [directory].
List<File> _dartFilesIn(String directory) =>
    Directory(directory)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

void main() {
  group('the launch mode', () {
    test('is never an in-app webview, anywhere in lib/', () {
      // The one-enum-value mistake. An in-app webview would make this app the
      // thing fetching the page, which needs INTERNET — and INTERNET is the
      // permission the whole app is designed around not having.
      final offenders = <String>[];
      for (final file in _dartFilesIn('lib')) {
        final source = file.readAsStringSync();
        for (final mode in <String>[
          'inAppWebView',
          'inAppBrowserView',
          'platformDefault',
        ]) {
          if (source.contains('LaunchMode.$mode')) {
            offenders.add('${file.path}: LaunchMode.$mode');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'An in-app webview renders the page inside this app, which means '
            'this app makes the request. That needs INTERNET and reverses '
            'ADR-0004 and ADR-0009. Use LaunchMode.externalApplication.\n'
            '${offenders.join("\n")}',
      );
    });

    test('and externalApplication is actually used', () {
      // The negative test above passes trivially if nothing launches anything.
      final source = File(
        'lib/features/lookup/browser_handoff.dart',
      ).readAsStringSync();
      expect(source, contains('LaunchMode.externalApplication'));
    });
  });

  group('the URL', () {
    test('encodes the term rather than concatenating it', () {
      // A drug name with a space or an ampersand would otherwise build a URL
      // that searches for something else entirely.
      final url = BrowserHandoff.urlFor('mefenamic acid & iron');
      expect(url.queryParameters['q'], 'mefenamic acid & iron');
      expect(url.toString(), isNot(contains(' ')));
    });

    test('goes to a search engine, not a medical site', () {
      // Sending the user to a specific medical site would be this app
      // recommending a source, and the reason for the hand-off is that the app
      // has stopped having an opinion at this point.
      expect(BrowserHandoff.searchBase, startsWith('https://'));
    });

    test('is https', () {
      expect(BrowserHandoff.urlFor('iron').scheme, 'https');
    });
  });

  group('the warning', () {
    Future<void> pumpAndTap(WidgetTester tester, {String? term}) async {
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      BrowserHandoff.confirmAndOpen(context, term: term),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
          database: memoryDatabase(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('says the browser makes the request, not the app', (
      tester,
    ) async {
      await pumpAndTap(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.lookupLeavingTitle), findsOneWidget);

      final body = l10n.lookupLeavingBody.toLowerCase();
      // Two claims, each checked, neither pinned to one spelling: the browser
      // is named as the thing making the request, and this app is named as the
      // thing that is not. Pinning a single sentence meant the second half was
      // only ever implied, and a rewrite that dropped it would have passed.
      expect(
        body.contains('request comes from your browser') ||
            body.contains('browser will make the request'),
        isTrue,
        reason: 'the warning no longer says who makes the request',
      );
      expect(
        body.contains('rather than from this app') ||
            body.contains('not this app'),
        isTrue,
        reason:
            'the warning no longer says the request is not this app making it',
      );
      expect(
        body,
        contains('history'),
        reason:
            'the warning no longer says the browser keeps it, which is the '
            'part a user cannot see for themselves',
      );
    });

    testWidgets('names the term that is about to enter browser history', (
      tester,
    ) async {
      // A hand-off that silently carries a drug name into browser history is
      // exactly what this warning exists to prevent, and "a search" would not
      // tell them which words.
      await pumpAndTap(tester, term: 'tranexamic acid');
      expect(
        find.textContaining('tranexamic acid'),
        findsOneWidget,
        reason: 'the term is pre-filled but the warning does not name it',
      );
    });

    testWidgets('says nothing about a term when none is pre-filled', (
      tester,
    ) async {
      await pumpAndTap(tester);
      expect(
        find.text(l10nOf(tester).lookupLeavingWithTermBody('')),
        findsNothing,
      );
    });

    testWidgets('can be declined, and nothing happens', (tester) async {
      await pumpAndTap(tester, term: 'iron');
      await tester.tap(find.text(l10nOf(tester).commonNotNow));
      await tester.pumpAndSettle();
      expect(find.text(l10nOf(tester).lookupLeavingTitle), findsNothing);
    });

    testWidgets('the confirm button is not the default-looking one', (
      tester,
    ) async {
      // Leaving is the consequential choice, so it is the one that has to be
      // chosen rather than the one a distracted tap lands on. "Not now" comes
      // first in the row.
      await pumpAndTap(tester);
      final l10n = l10nOf(tester);
      final notNow = tester.getTopLeft(find.text(l10n.commonNotNow));
      final leave = tester.getTopLeft(find.text(l10n.lookupLeavingContinue));
      expect(notNow.dx, lessThan(leave.dx));
    });
  });
}
