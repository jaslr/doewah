import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config.dart';

// Terminal config state
class TerminalConfig {
  final String dropletIp;
  final String sshUser;
  final String claudeCommand;
  final List<ProjectConfig> projects;

  const TerminalConfig({
    this.dropletIp = '209.38.85.244',
    this.sshUser = 'root',
    this.claudeCommand = 'IS_SANDBOX=1 claude --dangerously-skip-permissions',
    this.projects = const [
      ProjectConfig(name: 'Livna', directory: '/root/projects/livna'),
      ProjectConfig(name: 'Brontiq', directory: '/root/projects/brontiq'),
      ProjectConfig(name: 'ORCHON', directory: '/root/projects/orchon'),
      ProjectConfig(name: 'Doewah', directory: '/root/doewah'),
    ],
  });

  TerminalConfig copyWith({
    String? dropletIp,
    String? sshUser,
    String? claudeCommand,
    List<ProjectConfig>? projects,
  }) {
    return TerminalConfig(
      dropletIp: dropletIp ?? this.dropletIp,
      sshUser: sshUser ?? this.sshUser,
      claudeCommand: claudeCommand ?? this.claudeCommand,
      projects: projects ?? this.projects,
    );
  }
}

class ProjectConfig {
  final String name;
  final String directory;

  const ProjectConfig({required this.name, required this.directory});
}

final terminalConfigProvider = StateProvider<TerminalConfig>((ref) {
  return const TerminalConfig();
});

class TerminalConfigScreen extends ConsumerStatefulWidget {
  const TerminalConfigScreen({super.key});

  @override
  ConsumerState<TerminalConfigScreen> createState() => _TerminalConfigScreenState();
}

class _TerminalConfigScreenState extends ConsumerState<TerminalConfigScreen> {
  late TextEditingController _ipController;
  late TextEditingController _userController;
  late TextEditingController _claudeController;

  @override
  void initState() {
    super.initState();
    final config = ref.read(terminalConfigProvider);
    _ipController = TextEditingController(text: config.dropletIp);
    _userController = TextEditingController(text: config.sshUser);
    _claudeController = TextEditingController(text: config.claudeCommand);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _userController.dispose();
    _claudeController.dispose();
    super.dispose();
  }

  void _saveConfig() {
    ref.read(terminalConfigProvider.notifier).state = TerminalConfig(
      dropletIp: _ipController.text,
      sshUser: _userController.text,
      claudeCommand: _claudeController.text,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuration saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal Config'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveConfig,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection Settings
          _buildSectionHeader('Connection Settings'),
          _buildTextField(
            controller: _ipController,
            label: 'Droplet IP',
            hint: '209.38.85.244',
            icon: Icons.dns,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _userController,
            label: 'SSH User',
            hint: 'root',
            icon: Icons.person,
          ),
          const SizedBox(height: 24),

          // Claude Settings
          _buildSectionHeader('Claude Command'),
          _buildTextField(
            controller: _claudeController,
            label: 'Launch Command',
            hint: 'IS_SANDBOX=1 claude --dangerously-skip-permissions',
            icon: Icons.terminal,
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // How It Works
          _buildSectionHeader('How It Works'),
          _buildInfoCard(
            title: 'Connection Steps',
            content: '''1. App fetches SSH key from update server
2. Decodes base64-encoded ed25519 private key
3. Establishes SSH connection to droplet
4. Opens interactive shell session
5. (Optional) Runs Claude command automatically''',
            icon: Icons.route,
          ),
          const SizedBox(height: 12),

          _buildInfoCard(
            title: 'SSH Key Setup',
            content: '''The SSH key is stored on your droplet at:
/root/termux-key.b64

To add a new key:
1. Generate: ssh-keygen -t ed25519
2. Add public key to ~/.ssh/authorized_keys
3. Base64 encode private key:
   base64 -w0 id_ed25519 > /root/termux-key.b64
4. Restart update server:
   systemctl restart doewah-updates''',
            icon: Icons.vpn_key,
          ),
          const SizedBox(height: 12),

          _buildInfoCard(
            title: 'DigitalOcean Droplet',
            content: '''This app is designed for DigitalOcean droplets.

Requirements:
• Ubuntu 22.04+ droplet
• SSH enabled (port 22)
• Node.js installed
• Claude CLI installed (npm i -g @anthropic-ai/claude-code)

The update server runs on port 8406 and serves:
• /version - App version info
• /download - APK download
• /termux-key - SSH private key (base64)''',
            icon: Icons.cloud,
          ),
          const SizedBox(height: 12),

          _buildInfoCard(
            title: 'Future LLM Support',
            content: '''Coming soon:
• Gemini CLI integration
• OpenAI CLI integration
• Custom LLM endpoints

Configure your preferred AI assistant in settings.''',
            icon: Icons.auto_awesome,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[900],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                  tooltip: 'Copy',
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              content,
              style: TextStyle(
                color: Colors.grey[400],
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
