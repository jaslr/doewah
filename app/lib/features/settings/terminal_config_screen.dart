import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project configuration
class ProjectConfig {
  final String name;
  final String directory;

  const ProjectConfig({required this.name, required this.directory});

  Map<String, dynamic> toJson() => {'name': name, 'directory': directory};

  factory ProjectConfig.fromJson(Map<String, dynamic> json) => ProjectConfig(
    name: json['name'] as String,
    directory: json['directory'] as String,
  );
}

// Terminal config state
class TerminalConfig {
  final String dropletIp;
  final String sshUser;
  final String claudeCommand;
  final List<ProjectConfig> projects;
  final int terminalFontScale; // Percentage: 50-200, default 100

  const TerminalConfig({
    this.dropletIp = '209.38.85.244',
    this.sshUser = 'root',
    this.claudeCommand = 'IS_SANDBOX=1 claude --dangerously-skip-permissions',
    this.projects = const [],
    this.terminalFontScale = 100,
  });

  // Get actual font size from scale (base size is 14)
  double get terminalFontSize => 14.0 * (terminalFontScale / 100.0);

  // Sensible defaults
  static const List<ProjectConfig> defaultProjects = [
    ProjectConfig(name: 'Livna', directory: '/root/projects/livna'),
    ProjectConfig(name: 'Brontiq', directory: '/root/projects/brontiq'),
    ProjectConfig(name: 'ORCHON', directory: '/root/projects/orchon'),
    ProjectConfig(name: 'LittleListOfLights', directory: '/root/projects/littlelistoflights'),
    ProjectConfig(name: 'Doewah', directory: '/root/doewah'),
    ProjectConfig(name: 'Agent Deck', directory: '/root/agent-deck'),
  ];

  TerminalConfig copyWith({
    String? dropletIp,
    String? sshUser,
    String? claudeCommand,
    List<ProjectConfig>? projects,
    int? terminalFontScale,
  }) {
    return TerminalConfig(
      dropletIp: dropletIp ?? this.dropletIp,
      sshUser: sshUser ?? this.sshUser,
      claudeCommand: claudeCommand ?? this.claudeCommand,
      projects: projects ?? this.projects,
      terminalFontScale: terminalFontScale ?? this.terminalFontScale,
    );
  }

  Map<String, dynamic> toJson() => {
    'dropletIp': dropletIp,
    'sshUser': sshUser,
    'claudeCommand': claudeCommand,
    'projects': projects.map((p) => p.toJson()).toList(),
    'terminalFontScale': terminalFontScale,
  };

  factory TerminalConfig.fromJson(Map<String, dynamic> json) => TerminalConfig(
    dropletIp: json['dropletIp'] as String? ?? '209.38.85.244',
    sshUser: json['sshUser'] as String? ?? 'root',
    claudeCommand: json['claudeCommand'] as String? ?? 'IS_SANDBOX=1 claude --dangerously-skip-permissions',
    projects: (json['projects'] as List<dynamic>?)
        ?.map((p) => ProjectConfig.fromJson(p as Map<String, dynamic>))
        .toList() ?? TerminalConfig.defaultProjects,
    terminalFontScale: json['terminalFontScale'] as int? ?? 100,
  );
}

// Notifier with persistence
class TerminalConfigNotifier extends Notifier<TerminalConfig> {
  static const _storageKey = 'terminal_config';

  @override
  TerminalConfig build() {
    _loadFromStorage();
    // Return defaults with projects, will be updated when storage loads
    return TerminalConfig(projects: TerminalConfig.defaultProjects);
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr != null) {
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = TerminalConfig.fromJson(json);
      } catch (e) {
        debugPrint('Failed to load config: $e');
      }
    }
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }

  void updateConfig({
    String? dropletIp,
    String? sshUser,
    String? claudeCommand,
  }) {
    state = state.copyWith(
      dropletIp: dropletIp,
      sshUser: sshUser,
      claudeCommand: claudeCommand,
    );
    _saveToStorage();
  }

  void setTerminalFontScale(int scale) {
    // Clamp between 50% and 200%
    final clamped = scale.clamp(50, 200);
    state = state.copyWith(terminalFontScale: clamped);
    _saveToStorage();
  }

  void addProject(ProjectConfig project) {
    state = state.copyWith(projects: [...state.projects, project]);
    _saveToStorage();
  }

  void updateProject(int index, ProjectConfig project) {
    final updated = [...state.projects];
    updated[index] = project;
    state = state.copyWith(projects: updated);
    _saveToStorage();
  }

  void removeProject(int index) {
    final updated = [...state.projects];
    updated.removeAt(index);
    state = state.copyWith(projects: updated);
    _saveToStorage();
  }

  void resetToDefaults() {
    state = TerminalConfig(projects: TerminalConfig.defaultProjects);
    _saveToStorage();
  }
}

final terminalConfigProvider = NotifierProvider<TerminalConfigNotifier, TerminalConfig>(
  TerminalConfigNotifier.new,
);

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
    ref.read(terminalConfigProvider.notifier).updateConfig(
      dropletIp: _ipController.text,
      sshUser: _userController.text,
      claudeCommand: _claudeController.text,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuration saved')),
    );
  }

  void _showAddProjectDialog() {
    final nameController = TextEditingController();
    final dirController = TextEditingController(text: '/root/projects/');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                hintText: 'My Project',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dirController,
              decoration: const InputDecoration(
                labelText: 'Directory',
                hintText: '/root/projects/myproject',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && dirController.text.isNotEmpty) {
                ref.read(terminalConfigProvider.notifier).addProject(
                  ProjectConfig(name: nameController.text, directory: dirController.text),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditProjectDialog(int index, ProjectConfig project) {
    final nameController = TextEditingController(text: project.name);
    final dirController = TextEditingController(text: project.directory);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Project Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dirController,
              decoration: const InputDecoration(labelText: 'Directory'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(terminalConfigProvider.notifier).removeProject(index);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && dirController.text.isNotEmpty) {
                ref.read(terminalConfigProvider.notifier).updateProject(
                  index,
                  ProjectConfig(name: nameController.text, directory: dirController.text),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(terminalConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal Config'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to Defaults',
            onPressed: () {
              ref.read(terminalConfigProvider.notifier).resetToDefaults();
              final newConfig = ref.read(terminalConfigProvider);
              _ipController.text = newConfig.dropletIp;
              _userController.text = newConfig.sshUser;
              _claudeController.text = newConfig.claudeCommand;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reset to defaults')),
              );
            },
          ),
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

          // Appearance Settings
          _buildSectionHeader('Appearance'),
          _buildFontScaleSelector(config.terminalFontScale),
          const SizedBox(height: 24),

          // Projects
          Row(
            children: [
              Expanded(child: _buildSectionHeader('Projects')),
              IconButton(
                icon: const Icon(Icons.add_circle),
                onPressed: _showAddProjectDialog,
                tooltip: 'Add Project',
              ),
            ],
          ),
          if (config.projects.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No projects configured. Tap + to add one.',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
            )
          else
            ...config.projects.asMap().entries.map((entry) {
              final index = entry.key;
              final project = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(project.name),
                  subtitle: Text(
                    project.directory,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditProjectDialog(index, project),
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),

          // Info cards
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
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
        ),
        filled: true,
        fillColor: Colors.grey[900],
      ),
    );
  }

  Widget _buildFontScaleSelector(int currentScale) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Terminal Font Size',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$currentScale%',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: currentScale > 50
                      ? () => ref.read(terminalConfigProvider.notifier).setTerminalFontScale(currentScale - 10)
                      : null,
                  tooltip: 'Decrease',
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Theme.of(context).colorScheme.primary,
                      inactiveTrackColor: Colors.grey[800],
                      thumbColor: Theme.of(context).colorScheme.primary,
                      overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    ),
                    child: Slider(
                      value: currentScale.toDouble(),
                      min: 50,
                      max: 200,
                      divisions: 15, // 10% increments from 50 to 200
                      label: '$currentScale%',
                      onChanged: (value) {
                        // Round to nearest 10
                        final rounded = (value / 10).round() * 10;
                        ref.read(terminalConfigProvider.notifier).setTerminalFontScale(rounded);
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: currentScale < 200
                      ? () => ref.read(terminalConfigProvider.notifier).setTerminalFontScale(currentScale + 10)
                      : null,
                  tooltip: 'Increase',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Text(
                'Preview: The quick brown fox',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14.0 * (currentScale / 100.0),
                  color: Colors.green[400],
                ),
              ),
            ),
          ],
        ),
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
