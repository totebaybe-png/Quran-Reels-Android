import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/crypto/sodium_encryptor.dart';
import '../models/github_user.dart';
import '../models/workflow_run.dart';

/// Thin wrapper around the GitHub REST API.
///
/// Every method accepts an optional [http.Client] purely as a **test seam**:
/// production call sites omit it and a fresh real client is created per call,
/// while tests inject a `MockClient` to assert on traffic without hitting the
/// network. No other behavior changes when a client is supplied.
class GithubService {
  static const String _apiBase = 'https://api.github.com';

  static Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer ${token.trim()}',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'Content-Type': 'application/json',
      };

  /// Runs [fn] with either the injected [client] or a fresh real client that is
  /// closed afterwards. Keeps every call site zero-touch and leak-free.
  static Future<T> _withClient<T>(
    http.Client? client,
    Future<T> Function(http.Client) fn,
  ) async {
    if (client != null) return fn(client);
    final ownClient = http.Client();
    try {
      return await fn(ownClient);
    } finally {
      ownClient.close();
    }
  }

  /// Verifies personal access token and retrieves user metadata
  static Future<GithubUser> verifyTokenAndGetUser(
    String token, {
    http.Client? client,
  }) async {
    return _withClient(client, (c) async {
      final response = await c.get(
        Uri.parse('$_apiBase/user'),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return GithubUser.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception(
            'رمز الوصول غير صحيح (Invalid Token). تأكد من صحة المفتاح.');
      } else {
        throw Exception(
            'خطأ في الاتصال بـ GitHub: ${response.statusCode} ${response.body}');
      }
    });
  }

  /// Creates a new public repository containing the automation engine.
  ///
  /// Primary path: the GitHub "Template Repository" generate endpoint (one call,
  /// preserves full git history). Fallback path: if the source repository is not
  /// flagged as a Template Repository (HTTP 403/404), we create a fresh public
  /// repo and copy every file through the Git Data API. This guarantees the
  /// launch button works in both cases instead of failing silently.
  ///
  /// The repo is intentionally public: public repositories get unlimited free
  /// GitHub Actions minutes forever, and every secret is encrypted client-side
  /// with Libsodium SealedBox before injection, so nothing sensitive is exposed.
  static Future<String> createRepoFromTemplate({
    required String token,
    required String templateOwner,
    required String templateRepo,
    required String targetRepoName,
    http.Client? client,
  }) async {
    const description = 'مولد ريلز القرآن الكريم السحابي تلقائياً 24/7 - صدقة جارية';

    return _withClient(client, (c) async {
      // --- Fast path: template generate endpoint ---
      final genUrl =
          '$_apiBase/repos/$templateOwner/$templateRepo/generate';
      final genResponse = await c.post(
        Uri.parse(genUrl),
        headers: _headers(token),
        body: json.encode({
          'name': targetRepoName,
          'description': description,
          // Public repos get UNLIMITED free GitHub Actions minutes.
          'private': false,
          'include_all_branches': false,
        }),
      );

      if (genResponse.statusCode == 201) {
        final data = json.decode(genResponse.body);
        return data['name'] ?? targetRepoName;
      }

      // Repo with the same name already exists -> guide the user, do not guess.
      if (genResponse.statusCode == 422) {
        throw Exception(
          'يوجد مستودع باسم "$targetRepoName" في حسابك بالفعل. '
          'غيّر اسم المستودع في خطوة الإطلاق، أو احذف المستودع القديم من GitHub ثم أعد المحاولة.',
        );
      }

      // --- Fallback path: source repo is not flagged as a Template Repository ---
      // Manual copy via Git Data API keeps the launch fully functional.
      if (genResponse.statusCode == 403 || genResponse.statusCode == 404) {
        return _createRepoByGitCopy(
          client: c,
          token: token,
          templateOwner: templateOwner,
          templateRepo: templateRepo,
          targetRepoName: targetRepoName,
          description: description,
        );
      }

      // 401 means the token itself is bad; 403 on /user/repos would be quota.
      String hint = '';
      if (genResponse.statusCode == 401) {
        hint =
            ' السبب الأرجح: التوكن غير صالح أو منتهي الصلاحية. أنشئ توكن جديد بصلاحيات repo و workflow.';
      }
      throw Exception(
          'فشل إنشاء المستودع من القالب (كود ${genResponse.statusCode}).$hint');
    });
  }

  /// Fallback deploy: create an empty public repo, then copy the template's
  /// complete file tree through the Git Data API (blobs -> tree -> commit -> ref).
  /// Used only when the source repository is not a flagged Template Repository.
  static Future<String> _createRepoByGitCopy({
    required http.Client client,
    required String token,
    required String templateOwner,
    required String templateRepo,
    required String targetRepoName,
    required String description,
  }) async {
    final headers = _headers(token);

    // 1) Create the target empty public repository.
    final createResp = await client.post(
      Uri.parse('$_apiBase/user/repos'),
      headers: headers,
      body: json.encode({
        'name': targetRepoName,
        'description': description,
        'private': false,
        'auto_init': false,
      }),
    );

    if (createResp.statusCode != 201) {
      if (createResp.statusCode == 422) {
        throw Exception(
          'يوجد مستودع باسم "$targetRepoName" في حسابك بالفعل. '
          'غيّر اسم المستودع في خطوة الإطلاق، أو احذف المستودع القديم من GitHub ثم أعد المحاولة.',
        );
      }
      throw Exception(
          'فشل إنشاء المستودع الجديد (كود ${createResp.statusCode}). ${createResp.body}');
    }

    final created = json.decode(createResp.body);
    final owner = (created['owner']?['login'] ?? '').toString();
    final repoName = (created['name'] ?? targetRepoName).toString();
    if (owner.isEmpty) {
      throw Exception('تعذّر تحديد مالك المستودع الجديد. حاول مرة أخرى.');
    }

    // 2) Discover the template's real default branch.
    String templateBranch = 'main';
    try {
      final infoResp = await client.get(
        Uri.parse('$_apiBase/repos/$templateOwner/$templateRepo'),
        headers: headers,
      );
      if (infoResp.statusCode == 200) {
        final branch = json.decode(infoResp.body)['default_branch'];
        if (branch is String && branch.isNotEmpty) templateBranch = branch;
      }
    } catch (_) {
      // Keep the 'main' default; a wrong guess only affects the tree fetch below.
    }

    // 3) Fetch the template's full file tree (recursive).
    final treeResp = await client.get(
      Uri.parse(
          '$_apiBase/repos/$templateOwner/$templateRepo/git/trees/$templateBranch?recursive=1'),
      headers: headers,
    );
    if (treeResp.statusCode != 200) {
      throw Exception(
        'تعذّر جلب ملفات القالب (كود ${treeResp.statusCode}). '
        'تأكد من أن المستودع المصدر عام وموجود.',
      );
    }

    final List treeEntries = json.decode(treeResp.body)['tree'] ?? [];
    if (treeEntries.isEmpty) {
      throw Exception('المستودع القالب فارغ — لا توجد ملفات لنسخها.');
    }

    // 4) Copy every blob into the new repo, building a fresh tree.
    final List<Map<String, dynamic>> newTreeEntries = [];

    for (final entry in treeEntries) {
      if (entry['type'] != 'blob') continue;
      final path = entry['path'].toString();
      // Start the new channel from a clean state instead of inheriting the
      // template channel's generation history.
      if (path == 'state.json') continue;

      final sourceSha = entry['sha'].toString();
      final blobResp = await client.get(
        Uri.parse(
            '$_apiBase/repos/$templateOwner/$templateRepo/git/blobs/$sourceSha'),
        headers: headers,
      );
      if (blobResp.statusCode != 200) {
        throw Exception('تعذّر جلب محتوى الملف "$path" من القالب.');
      }

      final blobContent = json.decode(blobResp.body)['content'];

      final newBlobResp = await client.post(
        Uri.parse('$_apiBase/repos/$owner/$repoName/git/blobs'),
        headers: headers,
        body: json.encode({'content': blobContent, 'encoding': 'base64'}),
      );
      if (newBlobResp.statusCode != 201) {
        throw Exception('فشل نسخ الملف "$path" إلى المستودع الجديد.');
      }

      newTreeEntries.add({
        'path': path,
        'mode': '100644',
        'type': 'blob',
        'sha': json.decode(newBlobResp.body)['sha'],
      });
    }

    // Fresh tracking state for the brand-new channel.
    const freshState =
        '{"total_generated":0,"last_reciter_idx":0,"last_surah":1,"last_ayah":0,"last_generated":null,"history":[]}';
    final stateBlobResp = await client.post(
      Uri.parse('$_apiBase/repos/$owner/$repoName/git/blobs'),
      headers: headers,
      body: json.encode({
        'content': base64.encode(utf8.encode(freshState)),
        'encoding': 'base64',
      }),
    );
    if (stateBlobResp.statusCode == 201) {
      newTreeEntries.add({
        'path': 'state.json',
        'mode': '100644',
        'type': 'blob',
        'sha': json.decode(stateBlobResp.body)['sha'],
      });
    }

    if (newTreeEntries.isEmpty) {
      throw Exception('لا توجد ملفات صالحة لنقلها إلى المستودع الجديد.');
    }

    // 5) Create the root tree from all copied blobs.
    final treeCreateResp = await client.post(
      Uri.parse('$_apiBase/repos/$owner/$repoName/git/trees'),
      headers: headers,
      body: json.encode({'tree': newTreeEntries}),
    );
    if (treeCreateResp.statusCode != 201) {
      throw Exception(
          'فشل بناء شجرة الملفات للمستودع الجديد (كود ${treeCreateResp.statusCode}).');
    }
    final treeSha = json.decode(treeCreateResp.body)['sha'].toString();

    // 6) Create the initial commit on top of the new tree.
    final commitResp = await client.post(
      Uri.parse('$_apiBase/repos/$owner/$repoName/git/commits'),
      headers: headers,
      body: json.encode({
        'message': '🌿 Initial deployment: Quran Reels automation engine (صدقة جارية)',
        'tree': treeSha,
      }),
    );
    if (commitResp.statusCode != 201) {
      throw Exception(
          'فشل إنشاء أول commit في المستودع الجديد (كود ${commitResp.statusCode}).');
    }
    final commitSha = json.decode(commitResp.body)['sha'].toString();

    // 7) Point the default branch at the new commit so the repo is live.
    final refResp = await client.post(
      Uri.parse('$_apiBase/repos/$owner/$repoName/git/refs'),
      headers: headers,
      body: json.encode({'ref': 'refs/heads/main', 'sha': commitSha}),
    );
    if (refResp.statusCode != 201) {
      throw Exception(
          'فشل تفعيل الفرع الرئيسي للمستودع الجديد (كود ${refResp.statusCode}).');
    }

    return repoName;
  }

  /// Fetches the repository's real default branch (usually "main", sometimes
  /// "master"). Workflow dispatches and state commits must target this branch
  /// instead of hardcoding "main", otherwise the dispatch silently 404s.
  static Future<String> getRepoDefaultBranch({
    required String token,
    required String owner,
    required String repo,
    http.Client? client,
  }) async {
    return _withClient(client, (c) async {
      final url = '$_apiBase/repos/$owner/$repo';
      final response = await c.get(
        Uri.parse(url),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['default_branch']?.toString() ?? 'main';
      }
      throw Exception(
          'فشل جلب معلومات المستودع ($repo): ${response.statusCode}');
    });
  }

  /// Checks whether GitHub Actions is enabled on the repository. New repos
  /// created from a template have it enabled by default; this lets the app warn
  /// the user (with exact remediation steps) if it ever comes back disabled.
  static Future<bool> isActionsEnabled({
    required String token,
    required String owner,
    required String repo,
    http.Client? client,
  }) async {
    return _withClient(client, (c) async {
      final url = '$_apiBase/repos/$owner/$repo/actions/permissions';
      final response = await c.get(
        Uri.parse(url),
        headers: _headers(token),
      );

      // Assume enabled when the endpoint is unreachable; only an explicit
      // `enabled: false` should block the deployment.
      if (response.statusCode != 200) return true;
      final data = json.decode(response.body);
      return data['enabled'] != false;
    });
  }

  /// Retrieves the public key of the repository for encrypting Actions secrets
  static Future<Map<String, String>> getRepoPublicKey({
    required String token,
    required String owner,
    required String repo,
    http.Client? client,
  }) async {
    return _withClient(client, (c) async {
      final url = '$_apiBase/repos/$owner/$repo/actions/secrets/public-key';
      final response = await c.get(
        Uri.parse(url),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'key_id': data['key_id'].toString(),
          'key': data['key'].toString(),
        };
      } else {
        throw Exception(
            'فشل جلب المفتاح العام لتشفير الأسرار: ${response.statusCode}');
      }
    });
  }

  /// Encrypts and injects a single secret into the repository
  static Future<void> injectSecret({
    required String token,
    required String owner,
    required String repo,
    required String secretName,
    required String secretValue,
    required String keyId,
    required String base64PublicKey,
    http.Client? client,
  }) async {
    final encryptedValue = SodiumEncryptor.encryptSecret(
      plainTextSecret: secretValue,
      base64PublicKey: base64PublicKey,
    );

    return _withClient(client, (c) async {
      final url = '$_apiBase/repos/$owner/$repo/actions/secrets/$secretName';
      final body = json.encode({
        'encrypted_value': encryptedValue,
        'key_id': keyId,
      });

      final response = await c.put(
        Uri.parse(url),
        headers: _headers(token),
        body: body,
      );

      if (response.statusCode != 201 && response.statusCode != 204) {
        throw Exception(
            'فشل حقن السر $secretName: ${response.statusCode} ${response.body}');
      }
    });
  }

  /// Triggers a manual workflow dispatch run (Creates a test reel now)
  static Future<bool> triggerWorkflowDispatch({
    required String token,
    required String owner,
    required String repo,
    required String workflowFileName,
    String branch = 'main',
    http.Client? client,
  }) async {
    return _withClient(client, (c) async {
      final url =
          '$_apiBase/repos/$owner/$repo/actions/workflows/$workflowFileName/dispatches';
      final body = json.encode({'ref': branch});

      final response = await c.post(
        Uri.parse(url),
        headers: _headers(token),
        body: body,
      );

      return response.statusCode == 204;
    });
  }

  /// Fetches the latest workflow runs for the repository
  static Future<List<WorkflowRun>> getLatestRuns({
    required String token,
    required String owner,
    required String repo,
    http.Client? client,
  }) async {
    return _withClient(client, (c) async {
      final url = '$_apiBase/repos/$owner/$repo/actions/runs?per_page=10';
      final response = await c.get(
        Uri.parse(url),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List runs = data['workflow_runs'] ?? [];
        return runs.map((e) => WorkflowRun.fromJson(e)).toList();
      }
      return [];
    });
  }
}
