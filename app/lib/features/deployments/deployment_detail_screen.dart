import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../../models/deployment.dart';
import '../../core/websocket/websocket_service.dart';
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
  bool _waitingForThread = false;
  int _previousThreadCount = 0;
  String? _statusMessage;
  bool _isError = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.deployment;
    final threadsState = ref.watch(threadsProvider);

    // Handle server errors
    if (_waitingForThread && threadsState.error != null) {
      _waitingForThread = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isError = true;
            _statusMessage = 'Server error: ${threadsState.error}';
          });
        }
      });
    }

    // Navigate to new thread when it's created
    if (_waitingForThread && threadsState.threads.length > _previousThreadCount) {
      _waitingForThread = false;
      final newThread = threadsState.threads.first;

      // Update status before navigating
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isError = false;
            _statusMessage = 'Thread created! Opening chat...';
          });
        }
      });

      // Small delay to show the message, then navigate
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              thread: newThread,
              initialMessage: _buildContextMessage(),
            ),
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'DOEWAH',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 3,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                d.projectDisplayName,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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

            // Send to Claude button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _waitingForThread ? null : _handleSendToClaude,
                style: FilledButton.styleFrom(
                  backgroundColor: d.isFailure ? Colors.red : const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('Send to Claude'),
              ),
            ),

            // Status message below button
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isError ? Colors.red.withOpacity(0.1) : Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isError ? Colors.red.withOpacity(0.3) : Colors.grey[700]!,
                  ),
                ),
                child: Row(
                  children: [
                    if (_isError)
                      const Icon(Icons.error_outline, color: Colors.red, size: 18)
                    else
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: _isError ? Colors.red[300] : Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleSendToClaude() {
    // Check WebSocket is authenticated
    final wsService = ref.read(webSocketServiceProvider);
    final wsState = wsService.currentState;

    if (wsState != WsConnectionState.authenticated) {
      setState(() {
        _isError = true;
        _statusMessage = wsState == WsConnectionState.connected
            ? 'WebSocket connected but not authenticated yet'
            : 'WebSocket not connected (state: ${wsState.name})';
      });
      return;
    }

    setState(() {
      _isError = false;
      _statusMessage = 'Creating thread...';
    });

    // Remember thread count before creating
    _previousThreadCount = ref.read(threadsProvider).threads.length;
    _waitingForThread = true;

    // Create thread - navigation happens in build() when thread appears
    ref.read(threadsProvider.notifier).createThread(
      projectHint: widget.deployment.projectName.toLowerCase(),
    );

    // Timeout after 10 seconds
    Timer(const Duration(seconds: 10), () {
      if (mounted && _waitingForThread) {
        setState(() {
          _waitingForThread = false;
          _isError = true;
          _statusMessage = 'Timeout: No response from server after 10s';
        });
      }
    });
  }

  String _buildContextMessage() {
    final d = widget.deployment;
    if (d.isFailure) {
      return '''Fix deployment failure for ${d.projectDisplayName}.

Project: ${d.projectDisplayName}
Provider: ${_formatProvider(d.provider)}
Branch: ${d.branch ?? 'main'}
Commit: ${d.commitSha ?? 'unknown'}
${d.runUrl != null ? 'Run URL: ${d.runUrl}' : ''}
Failed at: ${d.completedAt != null ? _formatDateTime(d.completedAt!) : 'unknown'}

Please investigate the deployment logs and fix this issue.''';
    } else {
      return '''Deployment succeeded for ${d.projectDisplayName}.

Project: ${d.projectDisplayName}
Provider: ${_formatProvider(d.provider)}
Branch: ${d.branch ?? 'main'}
Commit: ${d.commitSha ?? 'unknown'}
${d.runUrl != null ? 'Run URL: ${d.runUrl}' : ''}
Completed at: ${d.completedAt != null ? _formatDateTime(d.completedAt!) : 'unknown'}

What would you like to do with this deployment?''';
    }
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
    // Convert to Sydney time (AEDT = UTC+11, AEST = UTC+10)
    // Daylight saving: first Sunday in October to first Sunday in April
    final utc = dt.toUtc();
    final month = utc.month;
    final isDst = month >= 10 || month <= 3; // Simplified DST check
    final sydneyOffset = isDst ? 11 : 10;
    final sydney = utc.add(Duration(hours: sydneyOffset));

    // Format: "10 Jan 2026 14:30"
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = sydney.day;
    final monthName = months[sydney.month - 1];
    final year = sydney.year;
    final hour = sydney.hour.toString().padLeft(2, '0');
    final minute = sydney.minute.toString().padLeft(2, '0');

    return '$day $monthName $year $hour:$minute';
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
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);
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
