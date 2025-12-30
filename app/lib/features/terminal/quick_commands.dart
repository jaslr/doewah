import 'package:flutter/material.dart';
import 'terminal_screen.dart';

class QuickCommand {
  final String name;
  final String description;
  final String command;
  final IconData icon;
  final Color? color;

  const QuickCommand({
    required this.name,
    required this.description,
    required this.command,
    required this.icon,
    this.color,
  });
}

const quickCommands = [
  QuickCommand(
    name: 'Service Status',
    description: 'Check claude-bot service status',
    command: 'systemctl status claude-bot --no-pager',
    icon: Icons.monitor_heart,
    color: Colors.blue,
  ),
  QuickCommand(
    name: 'Restart Bot',
    description: 'Restart the claude-bot service',
    command: 'systemctl restart claude-bot && systemctl status claude-bot --no-pager',
    icon: Icons.refresh,
    color: Colors.orange,
  ),
  QuickCommand(
    name: 'View Logs',
    description: 'Show recent bot logs',
    command: 'journalctl -u claude-bot -n 50 --no-pager',
    icon: Icons.article,
    color: Colors.green,
  ),
  QuickCommand(
    name: 'Git Pull',
    description: 'Pull latest changes',
    command: 'cd /root/doewah && git pull',
    icon: Icons.download,
    color: Colors.purple,
  ),
  QuickCommand(
    name: 'Deploy',
    description: 'Pull and restart bot',
    command: 'cd /root/doewah && git pull && systemctl restart claude-bot && systemctl status claude-bot --no-pager',
    icon: Icons.rocket_launch,
    color: Colors.red,
  ),
  QuickCommand(
    name: 'Disk Usage',
    description: 'Check disk space',
    command: 'df -h',
    icon: Icons.storage,
    color: Colors.teal,
  ),
  QuickCommand(
    name: 'Memory',
    description: 'Check memory usage',
    command: 'free -h',
    icon: Icons.memory,
    color: Colors.indigo,
  ),
  QuickCommand(
    name: 'Processes',
    description: 'Top processes by CPU',
    command: 'ps aux --sort=-%cpu | head -10',
    icon: Icons.speed,
    color: Colors.amber,
  ),
];

class QuickCommandsSheet extends StatelessWidget {
  const QuickCommandsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Colors.amber),
              const SizedBox(width: 8),
              const Text(
                'Quick Commands',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: quickCommands.length,
              itemBuilder: (context, index) {
                final cmd = quickCommands[index];
                return _CommandCard(
                  command: cmd,
                  onTap: () {
                    Navigator.pop(context); // Close sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TerminalScreen(
                          initialCommand: cmd.command,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  final QuickCommand command;
  final VoidCallback onTap;

  const _CommandCard({
    required this.command,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: command.color?.withOpacity(0.15) ?? Colors.grey[850],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: command.color?.withOpacity(0.2) ?? Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  command.icon,
                  color: command.color ?? Colors.grey[400],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      command.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      command.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showQuickCommands(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => const QuickCommandsSheet(),
    ),
  );
}
