import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'features/threads/threads_screen.dart';

// Global error log
final List<String> errorLog = [];

Future<void> logError(String error) async {
  final timestamp = DateTime.now().toIso8601String();
  final entry = '[$timestamp] $error';
  errorLog.add(entry);

  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/doewah_crash.log');
    await file.writeAsString('$entry\n', mode: FileMode.append);
  } catch (e) {
    // Can't write to file, just keep in memory
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch Flutter framework errors
  FlutterError.onError = (details) {
    logError('FlutterError: ${details.exception}\n${details.stack}');
    // Don't crash - just log
  };

  runApp(const ProviderScope(child: DoewahApp()));
}

class DoewahApp extends StatelessWidget {
  const DoewahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doewah',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F0F23),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0F23),
          elevation: 0,
        ),
      ),
      home: const ThreadsScreen(),
    );
  }
}

// Error display app (fallback if main app crashes)
class ErrorApp extends StatelessWidget {
  final String error;
  final List<String> log;

  const ErrorApp({super.key, required this.error, required this.log});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ErrorScreen(error: error, log: log),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;
  final List<String> log;

  const ErrorScreen({super.key, required this.error, required this.log});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        title: const Text('Doewah - Error'),
        backgroundColor: Colors.red[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App crashed with error:',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[900]?.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                error,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Error log:',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: log.length,
                  itemBuilder: (context, index) {
                    return SelectableText(
                      log[index],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
