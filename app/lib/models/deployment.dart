/// Deployment model for ORCHON API data
class Deployment {
  final String id;
  final String serviceId;
  final String provider; // 'github' | 'cloudflare' | 'flyio' | 'gcp'
  final String status; // 'queued' | 'in_progress' | 'success' | 'failure'
  final String? commitSha;
  final String? branch;
  final String? runUrl;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String projectId;
  final String projectName;
  final String projectDisplayName;

  Deployment({
    required this.id,
    required this.serviceId,
    required this.provider,
    required this.status,
    this.commitSha,
    this.branch,
    this.runUrl,
    this.startedAt,
    this.completedAt,
    required this.projectId,
    required this.projectName,
    required this.projectDisplayName,
  });

  factory Deployment.fromJson(Map<String, dynamic> json) {
    return Deployment(
      id: json['id'] as String,
      serviceId: json['serviceId'] as String? ?? '',
      provider: json['provider'] as String? ?? 'unknown',
      status: json['status'] as String? ?? 'unknown',
      commitSha: json['commitSha'] as String?,
      branch: json['branch'] as String?,
      runUrl: json['runUrl'] as String?,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      projectId: json['projectId'] as String? ?? '',
      projectName: json['projectName'] as String? ?? '',
      projectDisplayName: json['projectDisplayName'] as String? ?? json['projectName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serviceId': serviceId,
      'provider': provider,
      'status': status,
      'commitSha': commitSha,
      'branch': branch,
      'runUrl': runUrl,
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'projectId': projectId,
      'projectName': projectName,
      'projectDisplayName': projectDisplayName,
    };
  }

  bool get isFailure => status == 'failure';
  bool get isSuccess => status == 'success';
  bool get isInProgress => status == 'in_progress';
  bool get isQueued => status == 'queued';

  String get shortCommit => commitSha?.substring(0, 7) ?? '';

  @override
  String toString() => 'Deployment($projectDisplayName, $status, $provider)';
}
