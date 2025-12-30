import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/config.dart';

class TerminalScreen extends StatefulWidget {
  final String? initialCommand;

  const TerminalScreen({super.key, this.initialCommand});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    // Build URL with basic auth credentials embedded
    final credentials = base64Encode(
      utf8.encode('${AppConfig.ttydUser}:${AppConfig.ttydPassword}'),
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F0F23))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            // Execute initial command if provided
            if (widget.initialCommand != null) {
              _executeCommand(widget.initialCommand!);
            }
          },
          onWebResourceError: (error) {
            setState(() {
              _error = error.description;
              _isLoading = false;
            });
          },
          onHttpAuthRequest: (request) {
            // Handle HTTP Basic Auth
            request.onProceed(
              WebViewCredential(
                user: AppConfig.ttydUser,
                password: AppConfig.ttydPassword,
              ),
            );
          },
        ),
      )
      ..loadRequest(
        Uri.parse(AppConfig.ttydUrl),
        headers: {
          'Authorization': 'Basic $credentials',
        },
      );
  }

  void _executeCommand(String command) {
    // Wait a moment for terminal to initialize, then send the command
    Future.delayed(const Duration(milliseconds: 500), () {
      // ttyd uses xterm.js - send keystrokes via the terminal's WebSocket
      // We inject JS to type the command and press Enter
      final escapedCommand = command.replaceAll("'", "\\'").replaceAll('\n', '\\n');
      _controller.runJavaScript('''
        if (window.term) {
          window.term.paste('$escapedCommand');
          window.term.paste('\\r');
        }
      ''');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _error = null;
                _isLoading = true;
              });
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_error != null)
            _buildErrorState()
          else
            WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load terminal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isLoading = true;
                });
                _initWebView();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
