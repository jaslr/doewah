import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import '../../core/updates/update_service.dart';
import '../terminal/ssh_terminal_screen.dart';
import '../threads/threads_screen.dart';
import 'terminal_config_screen.dart';

/// Provider for package info
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

class SettingsDrawer extends ConsumerWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfoAsync = ref.watch(packageInfoProvider);

    return Drawer(
      backgroundColor: const Color(0xFF1A1A2E),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F23),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[800]!,
                    width: 1,
                  ),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Configure Doewah',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Settings options
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Primary: Launch Claude
                  _LaunchClaudeTile(ref: ref),
                  // Secondary: Launch Bash
                  _SettingsTile(
                    icon: Icons.terminal,
                    title: 'Launch Bash',
                    subtitle: 'SSH shell to droplet',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SshTerminalScreen(
                            launchMode: LaunchMode.bash,
                          ),
                        ),
                      );
                    },
                  ),
                  // All Threads
                  _SettingsTile(
                    icon: Icons.chat_bubble_outline,
                    title: 'All Threads',
                    subtitle: 'View conversation threads',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ThreadsScreen(),
                        ),
                      );
                    },
                  ),
                  // Terminal Config
                  _SettingsTile(
                    icon: Icons.settings,
                    title: 'Terminal Config',
                    subtitle: 'SSH and command settings',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TerminalConfigScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Colors.grey, height: 32),
                  _SettingsTile(
                    icon: Icons.wifi,
                    title: 'Connection',
                    subtitle: 'WebSocket server settings',
                    onTap: () {
                      // TODO: Connection settings
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Push notification preferences',
                    onTap: () {
                      // TODO: Notification settings
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.color_lens_outlined,
                    title: 'Appearance',
                    subtitle: 'Theme and display options',
                    onTap: () {
                      // TODO: Appearance settings
                    },
                  ),
                  _UpdateTile(ref: ref),
                  const Divider(color: Colors.grey, height: 32),
                  _SettingsTile(
                    icon: Icons.info_outline,
                    title: 'About',
                    subtitle: 'App information and licenses',
                    onTap: () {
                      // TODO: About screen
                    },
                  ),
                ],
              ),
            ),

            // Version info at bottom
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F23),
                border: Border(
                  top: BorderSide(
                    color: Colors.grey[800]!,
                    width: 1,
                  ),
                ),
              ),
              child: packageInfoAsync.when(
                data: (info) => Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF6366F1).withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            'v${info.version}',
                            style: const TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Build ${info.buildNumber}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.packageName,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, __) => Text(
                  'Version info unavailable',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final highlightColor = const Color(0xFF6366F1);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: highlight ? highlightColor.withOpacity(0.2) : Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
          border: highlight ? Border.all(color: highlightColor.withOpacity(0.5)) : null,
        ),
        child: Icon(icon, color: highlight ? highlightColor : Colors.grey[400], size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: highlight ? highlightColor : Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: highlight ? highlightColor : Colors.grey[600],
      ),
      onTap: onTap,
    );
  }
}

class _UpdateTile extends StatelessWidget {
  final WidgetRef ref;

  const _UpdateTile({required this.ref});

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(updateProvider);

    String subtitle;
    IconData icon = Icons.system_update_outlined;
    bool isLoading = false;
    bool hasUpdate = updateState.hasUpdate;
    Color? highlightColor = hasUpdate ? Colors.orange : null;

    switch (updateState.status) {
      case UpdateStatus.checking:
        subtitle = 'Checking for updates...';
        isLoading = true;
        break;
      case UpdateStatus.available:
        subtitle = 'v${updateState.updateInfo?.version} available - tap to install';
        icon = Icons.download;
        break;
      case UpdateStatus.downloading:
        subtitle = 'Downloading: ${(updateState.downloadProgress * 100).toInt()}%';
        isLoading = true;
        break;
      case UpdateStatus.readyToInstall:
        subtitle = 'Tap to install v${updateState.updateInfo?.version}';
        icon = Icons.install_mobile;
        break;
      case UpdateStatus.upToDate:
        // Only show "up to date" if we actually checked
        final lastChecked = updateState.lastChecked;
        if (lastChecked != null) {
          final ago = DateTime.now().difference(lastChecked);
          if (ago.inMinutes < 1) {
            subtitle = 'Up to date (just now)';
          } else if (ago.inHours < 1) {
            subtitle = 'Up to date (${ago.inMinutes}m ago)';
          } else {
            subtitle = 'Up to date (${ago.inHours}h ago)';
          }
        } else {
          subtitle = 'Tap to check for updates';
        }
        icon = Icons.check_circle_outline;
        break;
      case UpdateStatus.error:
        subtitle = 'Error: ${updateState.errorMessage}';
        icon = Icons.error_outline;
        break;
      default:
        subtitle = 'Tap to check for updates';
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: hasUpdate ? Colors.orange.withOpacity(0.2) : Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
          border: hasUpdate ? Border.all(color: Colors.orange.withOpacity(0.5)) : null,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: highlightColor ?? Colors.grey[400], size: 20),
      ),
      title: Text(
        hasUpdate ? 'Update Available' : 'Check for Update',
        style: TextStyle(
          color: highlightColor ?? Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: hasUpdate ? Colors.orange[300] : Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: highlightColor ?? Colors.grey[600],
      ),
      onTap: () {
        if (updateState.status == UpdateStatus.available) {
          ref.read(updateProvider.notifier).downloadAndInstall();
        } else if (updateState.status == UpdateStatus.readyToInstall) {
          ref.read(updateProvider.notifier).installUpdate();
        } else if (!isLoading) {
          ref.read(updateProvider.notifier).checkForUpdate();
        }
      },
    );
  }
}

class _LaunchClaudeTile extends StatelessWidget {
  final WidgetRef ref;

  const _LaunchClaudeTile({required this.ref});

  @override
  Widget build(BuildContext context) {
    final highlightColor = const Color(0xFF6366F1);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: highlightColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: highlightColor.withOpacity(0.5)),
        ),
        child: Icon(Icons.smart_toy, color: highlightColor, size: 20),
      ),
      title: Text(
        'Launch Claude',
        style: TextStyle(
          color: highlightColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        'AI assistant via SSH',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.list, color: highlightColor),
            onPressed: () => _showSessionPicker(context),
            tooltip: 'Session options',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: highlightColor),
        ],
      ),
      onTap: () {
        Navigator.pop(context); // Close drawer
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SshTerminalScreen(
              launchMode: LaunchMode.claude,
            ),
          ),
        );
      },
    );
  }

  void _showSessionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _SessionPickerSheet(ref: ref),
    );
  }
}

class _SessionPickerSheet extends StatefulWidget {
  final WidgetRef ref;

  const _SessionPickerSheet({required this.ref});

  @override
  State<_SessionPickerSheet> createState() => _SessionPickerSheetState();
}

class _SessionPickerSheetState extends State<_SessionPickerSheet> {
  List<Map<String, String>> _sessions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final config = widget.ref.read(terminalConfigProvider);

    try {
      // Fetch tmux sessions from the update server
      final url = 'http://${config.dropletIp}:8406/tmux-sessions';
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _sessions = data.map((s) => {
            'name': s['name']?.toString() ?? 'unknown',
            'windows': s['windows']?.toString() ?? '0',
            'attached': s['attached']?.toString() ?? 'false',
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to fetch sessions: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'CLAUDE SESSIONS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 3,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),

            // Start New option (always at top)
            _SessionOption(
              icon: Icons.add_circle_outline,
              title: 'Start New Session',
              subtitle: 'Launch a fresh Claude instance',
              color: const Color(0xFF6366F1),
              onTap: () {
                Navigator.pop(context); // Close bottom sheet
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SshTerminalScreen(
                      launchMode: LaunchMode.claude,
                    ),
                  ),
                );
              },
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Could not fetch sessions:\n$_error',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              )
            else if (_sessions.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'EXISTING SESSIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 2,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              ...(_sessions.map((session) => _SessionOption(
                icon: Icons.terminal,
                title: session['name'] ?? 'unknown',
                subtitle: '${session['windows']} windows${session['attached'] == 'true' ? ' (attached)' : ''}',
                color: Colors.grey[400]!,
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                  onPressed: () => _killSession(session['name']!),
                  tooltip: 'Kill session',
                ),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  Navigator.pop(context); // Close drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SshTerminalScreen(
                        launchMode: LaunchMode.claude,
                        initialCommand: 'tmux attach -t ${session['name']}',
                      ),
                    ),
                  );
                },
              ))),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _killSession(String sessionName) async {
    final config = widget.ref.read(terminalConfigProvider);

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Kill Session?'),
        content: Text('Kill tmux session "$sessionName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Kill'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final url = 'http://${config.dropletIp}:8406/tmux-kill?session=$sessionName';
      await http.post(Uri.parse(url));
      _loadSessions(); // Refresh the list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to kill session: $e')),
        );
      }
    }
  }
}

class _SessionOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SessionOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right, color: color),
      onTap: onTap,
    );
  }
}
