import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../terminal/terminal_screen.dart';
import '../terminal/termux_setup_screen.dart';

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
                  _SettingsTile(
                    icon: Icons.terminal,
                    title: 'Terminal',
                    subtitle: 'Open droplet shell',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TerminalScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.phone_android,
                    title: 'Termux Setup',
                    subtitle: 'SSH key & Claude alias',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermuxSetupScreen(),
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
                  _SettingsTile(
                    icon: Icons.system_update_outlined,
                    title: 'Updates',
                    subtitle: 'Check for app updates',
                    onTap: () {
                      // TODO: Manual update check
                    },
                  ),
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

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.grey[400], size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
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
      onTap: onTap,
    );
  }
}
