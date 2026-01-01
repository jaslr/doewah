import 'package:flutter/material.dart';
import '../../../models/deployment.dart';

/// Card widget for displaying a single deployment in the list
class DeploymentCard extends StatelessWidget {
  final Deployment deployment;
  final VoidCallback onTap;

  const DeploymentCard({
    super.key,
    required this.deployment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: deployment.isFailure
          ? Colors.red.withOpacity(0.15)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: deployment.isFailure
            ? BorderSide(color: Colors.red.withOpacity(0.5), width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _StatusIcon(status: deployment.status),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deployment.projectDisplayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _ProviderBadge(provider: deployment.provider),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (deployment.branch != null) ...[
                          Icon(Icons.alt_route, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            deployment.branch!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (deployment.shortCommit.isNotEmpty) ...[
                          Icon(Icons.commit, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            deployment.shortCommit,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          _formatTimestamp(deployment.completedAt ?? deployment.startedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${timestamp.month}/${timestamp.day}';
  }
}

/// Status icon with color coding
class _StatusIcon extends StatelessWidget {
  final String status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      'success' => (Icons.check_circle, Colors.green),
      'failure' => (Icons.error, Colors.red),
      'in_progress' => (Icons.sync, Colors.amber),
      'queued' => (Icons.schedule, Colors.grey),
      _ => (Icons.help_outline, Colors.grey),
    };

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }
}

/// Provider badge (GitHub, Cloudflare, Fly.io, GCP)
class _ProviderBadge extends StatelessWidget {
  final String provider;

  const _ProviderBadge({required this.provider});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (provider.toLowerCase()) {
      'github' => ('GitHub', const Color(0xFF6E40C9)),
      'cloudflare' => ('CF', const Color(0xFFF38020)),
      'flyio' => ('Fly', const Color(0xFF8B5CF6)),
      'gcp' => ('GCP', const Color(0xFF4285F4)),
      _ => (provider, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
