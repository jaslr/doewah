import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';
import 'package:http/http.dart' as http;
import '../../core/config.dart';

class SshTerminalScreen extends StatefulWidget {
  final String? initialCommand;

  const SshTerminalScreen({super.key, this.initialCommand});

  @override
  State<SshTerminalScreen> createState() => _SshTerminalScreenState();
}

class _SshTerminalScreenState extends State<SshTerminalScreen> {
  final terminal = Terminal(maxLines: 10000);
  SSHClient? _client;
  SSHSession? _session;
  bool _isConnecting = true;
  String? _error;

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

    try {
      terminal.write('Connecting to ${AppConfig.dropletIp}...\r\n');

      // Get SSH key from server
      terminal.write('Fetching SSH key...\r\n');
      final keyResponse = await http.get(
        Uri.parse('${AppConfig.updateUrl}/termux-key'),
      );

      if (keyResponse.statusCode != 200) {
        throw Exception('Failed to fetch SSH key: ${keyResponse.statusCode}');
      }

      final keyBytes = base64Decode(keyResponse.body.trim());
      final keyString = utf8.decode(keyBytes);

      terminal.write('Establishing SSH connection...\r\n');

      // Connect via SSH
      final socket = await SSHSocket.connect(AppConfig.dropletIp, 22);

      _client = SSHClient(
        socket,
        username: 'root',
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

      // Execute initial command if provided
      if (widget.initialCommand != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        _session?.write(Uint8List.fromList('${widget.initialCommand}\n'.codeUnits));
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
    _session?.close();
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Terminal'),
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
          if (_error != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _connect,
              tooltip: 'Reconnect',
            ),
        ],
      ),
      body: SafeArea(
        child: TerminalView(
          terminal,
          textStyle: const TerminalStyle(
            fontSize: 14,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
