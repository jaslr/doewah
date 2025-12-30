import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';
import 'package:http/http.dart' as http;
import '../../core/config.dart';
import '../settings/terminal_config_screen.dart';

enum LaunchMode { bash, claude }

class SshTerminalScreen extends ConsumerStatefulWidget {
  final String? initialCommand;
  final LaunchMode launchMode;

  const SshTerminalScreen({
    super.key,
    this.initialCommand,
    this.launchMode = LaunchMode.bash,
  });

  @override
  ConsumerState<SshTerminalScreen> createState() => _SshTerminalScreenState();
}

class _SshTerminalScreenState extends ConsumerState<SshTerminalScreen> {
  final terminal = Terminal(maxLines: 10000);
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  SSHClient? _client;
  SSHSession? _session;
  bool _isConnecting = true;
  String? _error;
  bool _useVoiceInput = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _error = null;
    });

    final config = ref.read(terminalConfigProvider);

    try {
      terminal.write('Connecting to ${config.dropletIp}...\r\n');

      // Get SSH key from server
      terminal.write('Fetching SSH key from update server...\r\n');
      final keyUrl = 'http://${config.dropletIp}:8406/termux-key';
      final keyResponse = await http.get(Uri.parse(keyUrl));

      if (keyResponse.statusCode != 200) {
        throw Exception('Failed to fetch SSH key: ${keyResponse.statusCode}');
      }

      // Strip whitespace from base64 before decoding
      terminal.write('Decoding SSH key...\r\n');
      final keyB64 = keyResponse.body.replaceAll(RegExp(r'\s'), '');
      final keyBytes = base64Decode(keyB64);
      final keyString = utf8.decode(keyBytes);

      terminal.write('Establishing SSH connection...\r\n');

      // Connect via SSH
      final socket = await SSHSocket.connect(config.dropletIp, 22);

      _client = SSHClient(
        socket,
        username: config.sshUser,
        identities: [
          ...SSHKeyPair.fromPem(keyString),
        ],
      );

      terminal.write('Starting shell...\r\n\r\n');

      // Start shell session
      _session = await _client!.shell(
        pty: SSHPtyConfig(
          width: 80,
          height: 24,
        ),
      );

      // Handle terminal output
      _session!.stdout.listen((data) {
        terminal.write(String.fromCharCodes(data));
      });

      _session!.stderr.listen((data) {
        terminal.write(String.fromCharCodes(data));
      });

      // Handle terminal input
      terminal.onOutput = (data) {
        _session?.write(Uint8List.fromList(data.codeUnits));
      };

      // Handle session close
      _session!.done.then((_) {
        terminal.write('\r\n[Connection closed]\r\n');
        setState(() {
          _isConnecting = false;
        });
      });

      setState(() {
        _isConnecting = false;
      });

      // Execute command based on launch mode
      await Future.delayed(const Duration(milliseconds: 800));

      if (widget.initialCommand != null) {
        _session?.write(Uint8List.fromList('${widget.initialCommand}\n'.codeUnits));
      } else if (widget.launchMode == LaunchMode.claude) {
        terminal.write('[Launching Claude...]\r\n');
        _session?.write(Uint8List.fromList('${config.claudeCommand}\n'.codeUnits));
      }
    } catch (e) {
      terminal.write('\r\n[Error: $e]\r\n');
      setState(() {
        _isConnecting = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _session?.close();
    _client?.close();
    super.dispose();
  }

  void _sendInput(String text) {
    if (_session != null && text.isNotEmpty) {
      _session!.write(Uint8List.fromList('$text\n'.codeUnits));
      _inputController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final modeName = widget.launchMode == LaunchMode.claude ? 'Claude' : 'Terminal';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              widget.launchMode == LaunchMode.claude
                ? Icons.smart_toy
                : Icons.terminal,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(modeName),
            if (_isConnecting) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.black,
        actions: [
          // Voice input toggle
          IconButton(
            icon: Icon(
              _useVoiceInput ? Icons.keyboard : Icons.mic,
              color: _useVoiceInput ? const Color(0xFF6366F1) : null,
            ),
            onPressed: () {
              setState(() {
                _useVoiceInput = !_useVoiceInput;
              });
              if (_useVoiceInput) {
                _inputFocusNode.requestFocus();
              }
            },
            tooltip: _useVoiceInput ? 'Use keyboard input' : 'Use voice input',
          ),
          if (_error != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _connect,
              tooltip: 'Reconnect',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Terminal view
            Expanded(
              child: GestureDetector(
                onTap: _useVoiceInput
                    ? () => _inputFocusNode.requestFocus()
                    : null,
                child: TerminalView(
                  terminal,
                  readOnly: _useVoiceInput,
                  textStyle: const TerminalStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            // Voice input field (when enabled)
            if (_useVoiceInput)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  border: Border(
                    top: BorderSide(color: Colors.grey[800]!),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        focusNode: _inputFocusNode,
                        autofocus: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: 'Speak or type your message...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: Colors.black,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(
                            Icons.mic,
                            color: Colors.grey[600],
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: _sendInput,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF6366F1)),
                      onPressed: () => _sendInput(_inputController.text),
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
