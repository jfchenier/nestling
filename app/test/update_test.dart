import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nestling/update/update.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> release(String tag, {bool apk = true, bool prerelease = false}) => {
  'tag_name': tag,
  'draft': false,
  'prerelease': prerelease,
  'html_url': 'https://github.com/jfchenier/nestling/releases/tag/$tag',
  'body': 'Lots of release notes',
  'assets': [
    if (apk) {'name': 'nestling-${tag.substring(1)}.apk', 'browser_download_url': 'https://example.com/n.apk', 'size': 1},
    {'name': 'SHA256SUMS.txt', 'browser_download_url': 'https://example.com/SHA256SUMS.txt'},
  ],
};

void main() {
  test('versions compare part by part, a release after its pre-releases', () {
    expect(compareVersions('0.10.0', '0.9.9'), 1);
    expect(compareVersions('v1.0.0', '1.0.0'), 0);
    expect(compareVersions('1.0', '1.0.0'), 0);
    expect(compareVersions('1.0.1', '1.0'), 1);
    expect(compareVersions('0.9.0', '0.9.0-dev.12'), 1);
    expect(compareVersions('0.9.0-dev.2', '0.9.0-dev.12'), -1);
    expect(compareVersions('0.9.0+5', '0.9.0+7'), 0);
  });

  test('a GitHub release with its APK and checksums', () {
    final r = Release.fromGitHub(release('v0.3.0'))!;
    expect(r.version, '0.3.0');
    expect(r.apkName, 'nestling-0.3.0.apk');
    expect(r.checksums.toString(), 'https://example.com/SHA256SUMS.txt');
    expect(Release.fromGitHub(release('v0.3.0', apk: false)), isNull);
    expect(Release.fromGitHub(release('v0.3.0', prerelease: true)), isNull);
  });

  test('checksum of one file from SHA256SUMS.txt', () {
    final a = 'a' * 64, b = 'B' * 64;
    final sums = '$a  nestling-0.3.0.apk\n$b *nestling-web-0.3.0.zip\n';
    expect(checksumFor(sums, 'nestling-0.3.0.apk'), a);
    expect(checksumFor(sums, 'nestling-web-0.3.0.zip'), 'b' * 64);
    expect(checksumFor(sums, 'other.apk'), isNull);
  });

  group('checks', () {
    late SharedPreferences prefs;
    var calls = 0;
    var latest = 'v0.3.0';
    final client = MockClient((req) async {
      calls++;
      expect(req.url.toString(), releasesApi);
      return http.Response(jsonEncode(release(latest)), 200);
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      calls = 0;
      latest = 'v0.3.0';
    });

    test('a newer release is offered, then not looked for again within the hour', () async {
      final u = AppUpdates(prefs, client: client, current: '0.2.1');
      expect(u.supported, isTrue);
      expect((await u.check())?.version, '0.3.0');
      expect(calls, 1);
      // The next start uses the saved answer.
      final again = AppUpdates(prefs, client: client, current: '0.2.1');
      expect((await again.check())?.version, '0.3.0');
      expect(calls, 1);
      expect(prefs.getString('update_latest'), isNot(contains('release notes')));
    });

    test('a release published after the last check shows once the hour is up', () async {
      // Installed 0.3.0; its first check found 0.3.0 itself. 0.3.1 comes out a little later.
      await AppUpdates(prefs, client: client, current: '0.3.0').check();
      latest = 'v0.3.1';
      await prefs.setString('update_checked_at', DateTime.now().toUtc().subtract(const Duration(minutes: 61)).toIso8601String());
      expect((await AppUpdates(prefs, client: client, current: '0.3.0').check())?.version, '0.3.1');
      expect(calls, 2);
    });

    test('the same or an older release is not offered', () async {
      final u = AppUpdates(prefs, client: client, current: '0.3.0');
      expect(await u.check(), isNull);
      expect(u.latest?.version, '0.3.0');
    });

    test('not now hides that version until a later one or Check now', () async {
      final u = AppUpdates(prefs, client: client, current: '0.2.1');
      await u.check();
      u.dismiss();
      expect(u.available, isNull);
      expect(await AppUpdates(prefs, client: client, current: '0.2.1').check(), isNull);
      latest = 'v0.4.0';
      expect((await u.check(force: true))?.version, '0.4.0');
      latest = 'v0.3.0';
      u.dismiss();
      expect((await u.check(force: true))?.version, '0.3.0');
    });

    test('turned off or a development build: no check', () async {
      final dev = AppUpdates(prefs, client: client, current: '');
      expect(dev.supported, isFalse);
      expect(await dev.check(force: true), isNull);
      final u = AppUpdates(prefs, client: client, current: '0.2.1');
      await u.setEnabled(false);
      expect(await u.check(), isNull);
      expect(calls, 0);
    });

    test('GitHub unreachable: no notice, the error is kept', () async {
      final u = AppUpdates(prefs, client: MockClient((_) async => http.Response('limit', 403)), current: '0.2.1');
      expect(await u.check(), isNull);
      expect(u.error, contains('403'));
      expect(u.lastCheck, isNull);
    });
  });
}
