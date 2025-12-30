import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/updates/update_service.dart';
import '../terminal/ssh_terminal_screen.dart';
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
                  _SettingsTile(
                    icon: Icons.smart_toy,
                    title: 'Launch Claude',
                    subtitle: 'AI assistant via SSH',
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
                    highlight: true,
                  ),
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

    switch (updateState.status) {
      case UpdateStatus.checking:
        subtitle = 'Checking...';
        isLoading = true;
        break;
      case UpdateStatus.available:
        subtitle = 'Update available: v${updateState.updateInfo?.version}';
        icon = Icons.download;
        break;
      case UpdateStatus.downloading:
        subtitle = 'Downloading: ${(updateState.downloadProgress * 100).toInt()}%';
        isLoading = true;
        break;
      case UpdateStatus.readyToInstall:
        subtitle = 'Ready to install';
        icon = Icons.install_mobile;
        break;
      case UpdateStatus.upToDate:
        subtitle = 'You\'re up to date';
        icon = Icons.check_circle_outline;
        break;
      case UpdateStatus.error:
        subtitle = 'Error: ${updateState.errorMessage}';
        icon = Icons.error_outline;
        break;
      default:
        subtitle = 'Check for app updates';
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: Colors.grey[400], size: 20),
      ),
      title: const Text(
        'Check for Update',
        style: TextStyle(
          color: Colors.white,
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
        color: Colors.grey[600],
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
