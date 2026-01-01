import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/deployment.dart';
import '../threads/threads_provider.dart';
import '../threads/chat_screen.dart';

class DeploymentDetailScreen extends ConsumerStatefulWidget {
  final Deployment deployment;

  const DeploymentDetailScreen({
    super.key,
    required this.deployment,
  });

  @override
  ConsumerState<DeploymentDetailScreen> createState() => _DeploymentDetailScreenState();
}

class _DeploymentDetailScreenState extends ConsumerState<DeploymentDetailScreen> {
  bool _isCreatingThread = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.deployment;

    // Listen for thread creation
    ref.listen<ThreadsState>(threadsProvider, (previous, next) {
      if (_isCreatingThread && next.threads.isNotEmpty) {
        // Find the newest thread (just created)
        final newThread = next.threads.first;
        setState(() => _isCreatingThread = false);

        // Navigate to chat and send the initial message
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              thread: newThread,
              initialMessage: _buildFixMessage(),
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(d.projectDisplayName),
        actions: [
          if (d.runUrl != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open in browser',
              onPressed: () => _openExternalUrl(d.runUrl!),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            _StatusBanner(status: d.status),
            const SizedBox(height: 24),

            // Deployment details
            _DetailSection(
              title: 'Deployment Info',
              children: [
                _DetailRow(label: 'Project', value: d.projectDisplayName),
                _DetailRow(label: 'Provider', value: _formatProvider(d.provider)),
                if (d.branch != null)
                  _DetailRow(label: 'Branch', value: d.branch!),
                if (d.commitSha != null)
                  _DetailRow(
                    label: 'Commit',
                    value: d.commitSha!,
                    isMonospace: true,
                    onCopy: () => _copyToClipboard(d.commitSha!),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Timestamps
            _DetailSection(
              title: 'Timeline',
              children: [
                if (d.startedAt != null)
                  _DetailRow(
                    label: 'Started',
                    value: _formatDateTime(d.startedAt!),
                  ),
                if (d.completedAt != null)
                  _DetailRow(
                    label: 'Completed',
                    value: _formatDateTime(d.completedAt!),
                  ),
                if (d.startedAt != null && d.completedAt != null)
                  _DetailRow(
                    label: 'Duration',
                    value: _formatDuration(d.completedAt!.difference(d.startedAt!)),
                  ),
              ],
            ),

            if (d.runUrl != null) ...[
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Links',
                children: [
                  InkWell(
                    onTap: () => _openExternalUrl(d.runUrl!),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.link, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              d.runUrl!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.open_in_new, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),

            // Fix This button (only for failures)
            if (d.isFailure)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isCreatingThread ? null : _handleFixThis,
                  icon: _isCreatingThread
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.build),
                  label: Text(_isCreatingThread ? 'Creating thread...' : 'Fix This'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleFixThis() {
    setState(() => _isCreatingThread = true);

    // Create a new thread with the project hint
    ref.read(threadsProvider.notifier).createThread(
      projectHint: widget.deployment.projectName.toLowerCase(),
    );
  }

  String _buildFixMessage() {
    final d = widget.deployment;
    return '''Fix deployment failure for ${d.projectDisplayName}.

Provider: ${_formatProvider(d.provider)}
Branch: ${d.branch ?? 'main'}
Commit: ${d.commitSha ?? 'unknown'}
${d.runUrl != null ? 'Run URL: ${d.runUrl}' : ''}
Failed at: ${d.completedAt != null ? _formatDateTime(d.completedAt!) : 'unknown'}

Please investigate and fix this deployment issue.''';
  }

  String _formatProvider(String provider) {
    return switch (provider.toLowerCase()) {
      'github' => 'GitHub Actions',
      'cloudflare' => 'Cloudflare Pages',
      'flyio' => 'Fly.io',
      'gcp' => 'Google Cloud Platform',
      _ => provider,
    };
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 1) {
      return '${duration.inSeconds}s';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;

  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status) {
      'success' => (Icons.check_circle, Colors.green, 'Deployment Successful'),
      'failure' => (Icons.error, Colors.red, 'Deployment Failed'),
      'in_progress' => (Icons.sync, Colors.amber, 'Deployment In Progress'),
      'queued' => (Icons.schedule, Colors.grey, 'Deployment Queued'),
      _ => (Icons.help_outline, Colors.grey, 'Unknown Status'),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMonospace;
  final VoidCallback? onCopy;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isMonospace = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: isMonospace ? 'monospace' : null,
              ),
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: onCopy,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
