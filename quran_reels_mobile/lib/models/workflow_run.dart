class WorkflowRun {
  final int id;
  final String name;
  final String status; // queued, in_progress, completed
  final String? conclusion; // success, failure, cancelled
  final DateTime createdAt;
  final String htmlUrl;
  final String displayTitle;

  WorkflowRun({
    required this.id,
    required this.name,
    required this.status,
    this.conclusion,
    required this.createdAt,
    required this.htmlUrl,
    required this.displayTitle,
  });

  bool get isSuccess => conclusion == 'success';
  bool get isRunning => status == 'in_progress' || status == 'queued';
  bool get isFailed => conclusion == 'failure';

  factory WorkflowRun.fromJson(Map<String, dynamic> json) {
    return WorkflowRun(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      status: json['status'] ?? 'unknown',
      conclusion: json['conclusion'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      htmlUrl: json['html_url'] ?? '',
      displayTitle: json['display_title'] ?? '',
    );
  }
}
