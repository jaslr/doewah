import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TermuxSetupScreen extends StatelessWidget {
  const TermuxSetupScreen({super.key});

  static const String sshSetupCommand =
      'mkdir -p ~/.ssh && curl -s http://209.38.85.244:8406/termux-key | base64 -d > ~/.ssh/id_ed25519 && chmod 600 ~/.ssh/id_ed25519';

  static const String claudeAliasCommand =
      'echo \'alias cc="IS_SANDBOX=1 claude --dangerously-skip-permissions"\' >> ~/.bashrc && source ~/.bashrc';

  static const String sshCommand = 'ssh root@209.38.85.244';

  static const String claudeCommand = 'cc';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termux Setup'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            icon: Icons.vpn_key,
            title: '1. Setup SSH Key',
            description: 'Run this in Termux to download and configure your SSH key:',
            command: sshSetupCommand,
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            icon: Icons.terminal,
            title: '2. Create Claude Alias',
            description: 'Add a shortcut to launch Claude without typing the full command:',
            command: claudeAliasCommand,
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            icon: Icons.computer,
            title: '3. SSH to Droplet',
            description: 'Connect to your droplet:',
            command: sshCommand,
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            icon: Icons.smart_toy,
            title: '4. Launch Claude',
            description: 'After SSH\'ing in, just type:',
            command: claudeCommand,
          ),
          const SizedBox(height: 32),
          Card(
            color: Colors.green.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.green[400]),
                      const SizedBox(width: 8),
                      Text(
                        'Pro Tip',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[400],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'After initial setup, your workflow is:\n'
                    '1. Open Termux\n'
                    '2. ssh root@209.38.85.244\n'
                    '3. cc\n\n'
                    'That\'s it! Claude is ready.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String command,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      command,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: command));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
