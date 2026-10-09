import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reels_mobile/models/workflow_run.dart';

void main() {
  group('WorkflowRun', () {
    Map<String, dynamic> baseRun(Map<String, dynamic> overrides) => {
          'id': 100,
          'name': 'Daily Quran Reel Generator',
          'status': 'completed',
          'conclusion': 'success',
          'created_at': '2025-06-01T11:33:00Z',
          'html_url': 'https://github.com/user/repo/actions/runs/100',
          'display_title': 'Reel #1',
          ...overrides,
        };

    test('marks a completed+successful run as success', () {
      final run = WorkflowRun.fromJson(baseRun({}));
      expect(run.id, 100);
      expect(run.isSuccess, isTrue);
      expect(run.isRunning, isFalse);
      expect(run.isFailed, isFalse);
    });

    test('marks an in_progress run as running', () {
      final run = WorkflowRun.fromJson(baseRun({
        'status': 'in_progress',
        'conclusion': null,
      }));
      expect(run.isRunning, isTrue);
      expect(run.isSuccess, isFalse);
    });

    test('marks a queued run as running', () {
      final run = WorkflowRun.fromJson(baseRun({'status': 'queued'}));
      expect(run.isRunning, isTrue);
    });

    test('marks a failed conclusion as failed', () {
      final run = WorkflowRun.fromJson(baseRun({
        'status': 'completed',
        'conclusion': 'failure',
      }));
      expect(run.isFailed, isTrue);
      expect(run.isSuccess, isFalse);
    });

    test('falls back safely on missing/garbled fields', () {
      final run = WorkflowRun.fromJson({});
      expect(run.id, 0);
      expect(run.status, 'unknown');
      expect(run.conclusion, isNull);
      expect(run.htmlUrl, '');
      // A garbage timestamp must not crash parsing.
      expect(run.createdAt, isNotNull);
    });
  });
}
