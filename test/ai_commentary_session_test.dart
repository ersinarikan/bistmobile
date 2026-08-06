import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotlotnet_mobile/core/api/api_client.dart';
import 'package:lotlotnet_mobile/core/storage/token_storage.dart';
import 'package:lotlotnet_mobile/features/stock/ai_commentary_session.dart';

ApiClient _api(MockClientHandler handler) {
  FlutterSecureStorage.setMockInitialValues({
    'lotlot_access_token': 'test-access-token',
    'lotlot_refresh_token': 'test-refresh-token',
  });
  return ApiClient(
    tokenStorage: TokenStorage(storage: const FlutterSecureStorage()),
    httpClient: MockClient(handler),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiCommentarySession', () {
    test('cache hit → ready with text', () async {
      final session = AiCommentarySession(
        apiClient: _api((request) async {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['async'], isTrue);
          return http.Response(
            jsonEncode({
              'status': 'success',
              'text': 'Kisa yorum',
              'cached': true,
              'model_public': 'lotlotLLMv16',
              'duration_s': 0.1,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
        pollDelayOverride: Duration.zero,
      );

      await session.start('THYAO');
      expect(session.phase, AiCommentaryPhase.ready);
      expect(session.text, 'Kisa yorum');
      expect(session.jobId, isNull);
      expect(session.metaLine, contains('cache'));
      expect(session.metaLine, contains('lotlotLLMv16'));
      session.dispose();
    });

    test('202 accepted → poll running → success', () async {
      var polls = 0;
      final session = AiCommentarySession(
        apiClient: _api((request) async {
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'status': 'accepted',
                'job_id': 'job-abc',
                'poll_after_ms': 1,
                'model_public': 'lotlotLLMv16',
              }),
              202,
            );
          }
          polls++;
          if (polls == 1) {
            return http.Response(
              jsonEncode({'status': 'running', 'job_id': 'job-abc'}),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'status': 'success',
              'text': 'Hazir yorum',
              'model_public': 'lotlotLLMv16',
              'duration_s': 12.5,
            }),
            200,
          );
        }),
        pollDelayOverride: Duration.zero,
      );

      await session.start('GARAN');
      // POST returned; poll loop is async — wait for ready
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 40 && session.phase == AiCommentaryPhase.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(session.phase, AiCommentaryPhase.ready);
      expect(session.jobId, 'job-abc');
      expect(session.text, 'Hazir yorum');
      expect(polls, greaterThanOrEqualTo(2));
      session.dispose();
    });

    test('poll failed → failed phase', () async {
      final session = AiCommentarySession(
        apiClient: _api((request) async {
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'status': 'accepted',
                'job_id': 'job-fail',
                'poll_after_ms': 1,
              }),
              202,
            );
          }
          return http.Response(
            jsonEncode({
              'status': 'failed',
              'error': 'commentary_failed',
              'message': 'Uretim hatasi',
            }),
            200,
          );
        }),
        pollDelayOverride: Duration.zero,
      );

      await session.start('EREGL');
      for (var i = 0; i < 40 && session.phase == AiCommentaryPhase.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(session.phase, AiCommentaryPhase.failed);
      expect(session.errorMessage, 'Uretim hatasi');
      session.dispose();
    });

    test('poll 404 → failed', () async {
      final session = AiCommentarySession(
        apiClient: _api((request) async {
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'status': 'accepted',
                'job_id': 'gone',
                'poll_after_ms': 1,
              }),
              202,
            );
          }
          return http.Response(
            jsonEncode({'status': 'error', 'error': 'not_found'}),
            404,
          );
        }),
        pollDelayOverride: Duration.zero,
      );

      await session.start('ASELS');
      for (var i = 0; i < 20 && session.phase == AiCommentaryPhase.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(session.phase, AiCommentaryPhase.failed);
      expect(session.lastErrorStatus, 404);
      session.dispose();
    });

    test('second start same symbol while loading → no extra POST', () async {
      var posts = 0;
      final session = AiCommentarySession(
        apiClient: _api((request) async {
          if (request.method == 'POST') {
            posts++;
            await Future<void>.delayed(const Duration(milliseconds: 40));
            return http.Response(
              jsonEncode({
                'status': 'accepted',
                'job_id': 'job-1',
                'poll_after_ms': 50,
              }),
              202,
            );
          }
          return http.Response(
            jsonEncode({'status': 'running', 'job_id': 'job-1'}),
            200,
          );
        }),
        pollDelayOverride: const Duration(milliseconds: 50),
      );

      final first = session.start('THYAO');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await session.start('THYAO');
      await first;
      expect(posts, 1);
      session.clear();
      session.dispose();
    });
  });

  group('buildMetaLine', () {
    test('uses model_public', () {
      final line = buildMetaLine('thyAO', {
        'model_public': 'lotlotLLMv16',
        'cached': true,
      }, null);
      expect(line, 'THYAO • lotlotLLMv16 • cache');
    });
  });
}
