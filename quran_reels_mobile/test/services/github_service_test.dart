import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_reels_mobile/models/github_user.dart';
import 'package:quran_reels_mobile/models/workflow_run.dart';
import 'package:quran_reels_mobile/services/github_service.dart';

void main() {
  const token = 'ghp_testtoken123';
  const owner = 'testuser';
  const repo = 'quran-reels';

  /// Helper: a MockClient that answers every request with [status] / [body].
  http.Client always(int status, [String body = '{}']) =>
      MockClient((request) async => http.Response(body, status));

  /// Captured raw body of the last request, for assertions on payloads.
  String? lastBody;

  group('verifyTokenAndGetUser', () {
    test('returns parsed user on 200', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://api.github.com/user');
        expect(request.headers['Authorization'], 'Bearer $token');
        return http.Response(
          json.encode({
            'login': owner,
            'name': 'Test User',
            'avatar_url': 'https://avatars.githubusercontent.com/u/1',
            'public_repos': 7,
          }),
          200,
        );
      });

      final user = await GithubService.verifyTokenAndGetUser(token, client: client);

      expect(user.login, owner);
      expect(user.name, 'Test User');
      expect(user.publicRepos, 7);
    });

    test('throws friendly Arabic message on 401', () async {
      final client = always(401, '{"message":"Bad credentials"}');

      expect(
        () => GithubService.verifyTokenAndGetUser(token, client: client),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('رمز الوصول غير صحيح'),
        )),
      );
    });

    test('includes raw status code on unexpected errors', () async {
      final client = always(500, 'server boom');
      expect(
        () => GithubService.verifyTokenAndGetUser(token, client: client),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('500'),
        )),
      );
    });
  });

  group('createRepoFromTemplate — fast path (template repo flagged)', () {
    test('returns repo name on 201 and marks the repo public', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path,
            '/repos/kpmbfi-sudo/Quran-Reels-Generator-open-source-/generate');
        lastBody = request.body;
        return http.Response(json.encode({'name': repo, 'id': 42}), 201);
      });

      final name = await GithubService.createRepoFromTemplate(
        token: token,
        templateOwner: 'kpmbfi-sudo',
        templateRepo: 'Quran-Reels-Generator-open-source-',
        targetRepoName: repo,
        client: client,
      );

      expect(name, repo);
      final sent = json.decode(lastBody!) as Map<String, dynamic>;
      // Public repos get unlimited free Actions minutes — must stay false.
      expect(sent['private'], false);
      expect(sent['name'], repo);
    });

    test('throws actionable Arabic message on 422 (repo already exists)',
        () async {
      final client = always(422, '{"errors":[{"code":"already_exists"}]}');

      expect(
        () => GithubService.createRepoFromTemplate(
          token: token,
          templateOwner: 'kpmbfi-sudo',
          templateRepo: 'Quran-Reels-Generator-open-source-',
          targetRepoName: repo,
          client: client,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          allOf(contains('يوجد مستودع باسم'), contains(repo)),
        )),
      );
    });
  });

  group('createRepoFromTemplate — fallback path (is_template = false)', () {
    /// Builds a MockClient implementing the whole Git Data copy sequence.
    http.Client fallbackClient() {
      final requestedUrls = <String>[];
      return MockClient((request) async {
        final path = request.url.path;
        requestedUrls.add('${request.method} $path');

        if (path == '/repos/kpmbfi-sudo/Quran-Reels-Generator-open-source-/generate') {
          // Not flagged as a template -> this is exactly the real-world bug we
          // defend against. GitHub answers 403 here.
          return http.Response('{"message":"must be a template repository"}', 403);
        }
        if (path == '/user/repos' && request.method == 'POST') {
          return http.Response(
            json.encode({
              'name': repo,
              'owner': {'login': owner},
            }),
            201,
          );
        }
        if (path == '/repos/kpmbfi-sudo/Quran-Reels-Generator-open-source-') {
          return http.Response(json.encode({'default_branch': 'main'}), 200);
        }
        if (path.contains('/git/trees/main')) {
          return http.Response(
            json.encode({
              'tree': [
                {'type': 'blob', 'path': 'auto_generate.py', 'sha': 'sha1'},
                {'type': 'blob', 'path': 'state.json', 'sha': 'shaState'},
                {'type': 'tree', 'path': '.github', 'sha': 'shaTree'},
              ],
            }),
            200,
          );
        }
        if (path.contains('/git/blobs/sha1')) {
          return http.Response(
            json.encode({'content': base64.encode(utf8.encode('print(1)'))}),
            200,
          );
        }
        if (path == '/repos/$owner/$repo/git/blobs' && request.method == 'POST') {
          return http.Response(
            json.encode({'sha': 'newSha${requestedUrls.length}'}),
            201,
          );
        }
        if (path == '/repos/$owner/$repo/git/trees' && request.method == 'POST') {
          return http.Response(json.encode({'sha': 'treeSha'}), 201);
        }
        if (path == '/repos/$owner/$repo/git/commits' && request.method == 'POST') {
          return http.Response(json.encode({'sha': 'commitSha'}), 201);
        }
        if (path == '/repos/$owner/$repo/git/refs' && request.method == 'POST') {
          // Must create the main branch pointing at the new commit.
          final body = json.decode(request.body) as Map<String, dynamic>;
          expect(body['ref'], 'refs/heads/main');
          expect(body['sha'], 'commitSha');
          return http.Response(json.encode({'ref': 'refs/heads/main'}), 201);
        }
        return http.Response('not found', 404);
      });
    }

    test('deploys via Git Data copy when /generate returns 403', () async {
      final client = fallbackClient();

      final name = await GithubService.createRepoFromTemplate(
        token: token,
        templateOwner: 'kpmbfi-sudo',
        templateRepo: 'Quran-Reels-Generator-open-source-',
        targetRepoName: repo,
        client: client,
      );

      expect(name, repo);
    });

    test('injects a clean fresh state.json (no history inherited)', () async {
      String? treePayload;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/repos/kpmbfi-sudo/Quran-Reels-Generator-open-source-/generate') {
          return http.Response('not a template', 403);
        }
        if (path == '/user/repos' && request.method == 'POST') {
          return http.Response(
            json.encode({'name': repo, 'owner': {'login': owner}}),
            201,
          );
        }
        if (path == '/repos/kpmbfi-sudo/Quran-Reels-Generator-open-source-') {
          return http.Response(json.encode({'default_branch': 'main'}), 200);
        }
        if (path.contains('/git/trees/main')) {
          return http.Response(
            json.encode({
              'tree': [
                {'type': 'blob', 'path': 'state.json', 'sha': 'shaState'},
              ],
            }),
            200,
          );
        }
        if (path == '/repos/$owner/$repo/git/blobs' && request.method == 'POST') {
          final body = json.decode(request.body) as Map<String, dynamic>;
          if (body['encoding'] == 'base64' && (body['content'] as String).isNotEmpty) {
            // This is the fresh state blob (the template blob fetch is a GET).
            final decoded = utf8.decode(base64.decode(body['content'] as String));
            final state = json.decode(decoded) as Map<String, dynamic>;
            expect(state['total_generated'], 0);
            expect(state['history'], isEmpty);
          }
          return http.Response(json.encode({'sha': 'blobSha'}), 201);
        }
        if (path == '/repos/$owner/$repo/git/trees' && request.method == 'POST') {
          treePayload = request.body;
          return http.Response(json.encode({'sha': 'treeSha'}), 201);
        }
        if (path == '/repos/$owner/$repo/git/commits') {
          return http.Response(json.encode({'sha': 'commitSha'}), 201);
        }
        if (path == '/repos/$owner/$repo/git/refs') {
          return http.Response(json.encode({'ref': 'refs/heads/main'}), 201);
        }
        return http.Response('not found', 404);
      });

      final name = await GithubService.createRepoFromTemplate(
        token: token,
        templateOwner: 'kpmbfi-sudo',
        templateRepo: 'Quran-Reels-Generator-open-source-',
        targetRepoName: repo,
        client: client,
      );

      expect(name, repo);
      // The committed tree contains exactly one state.json, freshly generated.
      final tree = json.decode(treePayload!)['tree'] as List;
      final stateEntry = tree.where((e) => e['path'] == 'state.json');
      expect(stateEntry, hasLength(1));
    });

    test('surfaces a clear error when the template tree fetch fails', () async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/repos/kpmbfi-sudo/Quran-Reels-Generator-open-source-/generate') {
          return http.Response('not a template', 403);
        }
        if (path == '/user/repos' && request.method == 'POST') {
          return http.Response(
            json.encode({'name': repo, 'owner': {'login': owner}}),
            201,
          );
        }
        return http.Response('boom', 500);
      });

      expect(
        () => GithubService.createRepoFromTemplate(
          token: token,
          templateOwner: 'kpmbfi-sudo',
          templateRepo: 'Quran-Reels-Generator-open-source-',
          targetRepoName: repo,
          client: client,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          anyOf(contains('تعذّر'), contains('فشل')),
        )),
      );
    });
  });

  group('getRepoDefaultBranch', () {
    test('returns the reported default branch', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/repos/$owner/$repo');
        return http.Response(json.encode({'default_branch': 'master'}), 200);
      });

      final branch = await GithubService.getRepoDefaultBranch(
        token: token,
        owner: owner,
        repo: repo,
        client: client,
      );
      expect(branch, 'master');
    });

    test('falls back to main when the field is missing', () async {
      final client = always(200, '{"full_name":"$owner/$repo"}');
      final branch = await GithubService.getRepoDefaultBranch(
        token: token,
        owner: owner,
        repo: repo,
        client: client,
      );
      expect(branch, 'main');
    });

    test('throws on non-200', () async {
      final client = always(404, '{"message":"Not Found"}');
      expect(
        () => GithubService.getRepoDefaultBranch(
          token: token,
          owner: owner,
          repo: repo,
          client: client,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('isActionsEnabled', () {
    test('returns false only on an explicit enabled:false', () async {
      final off = always(200, '{"enabled":false,"allowed_actions":"none"}');
      expect(
        await GithubService.isActionsEnabled(
            token: token, owner: owner, repo: repo, client: off),
        isFalse,
      );

      final on = always(200, '{"enabled":true,"allowed_actions":"all"}');
      expect(
        await GithubService.isActionsEnabled(
            token: token, owner: owner, repo: repo, client: on),
        isTrue,
      );
    });

    test('assumes enabled when the endpoint is unreachable', () async {
      final client = always(403, '{}');
      expect(
        await GithubService.isActionsEnabled(
            token: token, owner: owner, repo: repo, client: client),
        isTrue,
      );
    });
  });

  group('getRepoPublicKey', () {
    test('returns key_id and key on 200', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/repos/$owner/$repo/actions/secrets/public-key');
        return http.Response(
          json.encode({
            'key_id': '5353674',
            'key': 'RN6aJ4z7Qeyd+CLyAAAAAA',
          }),
          200,
        );
      });

      final key = await GithubService.getRepoPublicKey(
        token: token,
        owner: owner,
        repo: repo,
        client: client,
      );
      expect(key['key_id'], '5353674');
      expect(key['key'], 'RN6aJ4z7Qeyd+CLyAAAAAA');
    });

    test('throws on failure', () async {
      final client = always(404, '{}');
      expect(
        () => GithubService.getRepoPublicKey(
          token: token,
          owner: owner,
          repo: repo,
          client: client,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('المفتاح العام'),
        )),
      );
    });
  });

  group('triggerWorkflowDispatch', () {
    test('returns true on 204 and posts the branch ref', () async {
      late String capturedBody;
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/repos/$owner/$repo/actions/workflows/daily_quran_reel.yml/dispatches',
        );
        capturedBody = request.body;
        return http.Response('', 204);
      });

      final ok = await GithubService.triggerWorkflowDispatch(
        token: token,
        owner: owner,
        repo: repo,
        workflowFileName: 'daily_quran_reel.yml',
        client: client,
      );

      expect(ok, isTrue);
      expect(json.decode(capturedBody), {'ref': 'main'});
    });

    test('returns false on any other status', () async {
      final client = always(422, '{"message":"workflow not found"}');
      expect(
        await GithubService.triggerWorkflowDispatch(
          token: token,
          owner: owner,
          repo: repo,
          workflowFileName: 'daily_quran_reel.yml',
          client: client,
        ),
        isFalse,
      );
    });
  });

  group('getLatestRuns', () {
    test('parses workflow_runs list', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/repos/$owner/$repo/actions/runs');
        return http.Response(
          json.encode({
            'workflow_runs': [
              {
                'id': 101,
                'name': 'daily_quran_reel',
                'status': 'completed',
                'conclusion': 'success',
                'created_at': '2026-10-08T10:00:00Z',
                'html_url': 'https://github.com/$owner/$repo/actions/runs/101',
                'display_title': 'سورة العصر',
              },
              {
                'id': 102,
                'name': 'daily_quran_reel',
                'status': 'in_progress',
                'conclusion': null,
                'created_at': '2026-10-08T14:00:00Z',
                'html_url': 'https://github.com/$owner/$repo/actions/runs/102',
                'display_title': 'سورة التين',
              },
            ],
          }),
          200,
          // Arabic titles need UTF-8; the default Latin1 codec rejects them.
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final runs = await GithubService.getLatestRuns(
        token: token,
        owner: owner,
        repo: repo,
        client: client,
      );

      expect(runs, hasLength(2));
      expect(runs.first, isA<WorkflowRun>());
      expect(runs.first.id, 101);
      expect(runs.first.isSuccess, isTrue);
      expect(runs.first.displayTitle, 'سورة العصر');
      expect(runs.last.isRunning, isTrue);
      expect(runs.last.conclusion, isNull);
    });

    test('returns empty list on error instead of throwing', () async {
      final client = always(401, '{"message":"Bad credentials"}');
      expect(
        await GithubService.getLatestRuns(
          token: token,
          owner: owner,
          repo: repo,
          client: client,
        ),
        isEmpty,
      );
    });
  });

  group('models', () {
    test('GithubUser.fromJson tolerates missing fields', () {
      final user = GithubUser.fromJson({'login': 'someone'});
      expect(user.login, 'someone');
      expect(user.name, isNull);
      expect(user.publicRepos, 0);
    });

    test('WorkflowRun derives state getters', () {
      final failed = WorkflowRun.fromJson({
        'id': 1,
        'name': 'n',
        'status': 'completed',
        'conclusion': 'failure',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(failed.isFailed, isTrue);
      expect(failed.isSuccess, isFalse);

      final queued = WorkflowRun.fromJson({
        'id': 2,
        'name': 'n',
        'status': 'queued',
        'created_at': 'not-a-date',
      });
      expect(queued.isRunning, isTrue);
      // Invalid date falls back to "now" instead of crashing.
      expect(queued.createdAt, isA<DateTime>());
    });
  });

  test('route helper sanity: distinguishes GET from POST', () async {
    final client = MockClient((request) async {
      if (request.method == 'POST') return http.Response('posted', 201);
      return http.Response('fetched', 200);
    });
    expect(await client.read(Uri.parse('https://example.com')), 'fetched');
  });
}
