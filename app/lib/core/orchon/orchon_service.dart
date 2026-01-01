import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../../models/deployment.dart';

/// State for deployments list
class DeploymentsState {
  final List<Deployment> deployments;
  final bool isLoading;
  final String? error;
  final DateTime? lastFetched;

  const DeploymentsState({
    this.deployments = const [],
    this.isLoading = false,
    this.error,
    this.lastFetched,
  });

  DeploymentsState copyWith({
    List<Deployment>? deployments,
    bool? isLoading,
    String? error,
    DateTime? lastFetched,
  }) {
    return DeploymentsState(
      deployments: deployments ?? this.deployments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }
}

/// Service for fetching deployment data from ORCHON API
class OrchonService {
  final http.Client _client;

  /// Retry configuration
  static const int _maxRetries = 3;
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _initialBackoff = Duration(milliseconds: 500);

  OrchonService({http.Client? client}) : _client = client ?? http.Client();

  /// Execute HTTP GET with retry and exponential backoff
  Future<http.Response> _getWithRetry(Uri uri) async {
    Exception? lastException;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await _client
            .get(uri, headers: _authHeaders)
            .timeout(_requestTimeout);

        // Success or client error (4xx) - don't retry
        if (response.statusCode < 500) {
          return response;
        }

        // Server error (5xx) - retry
        lastException = OrchonException(
          'Server error: ${response.statusCode}',
          statusCode: response.statusCode,
        );
        debugPrint('ORCHON attempt ${attempt + 1} failed: ${response.statusCode}');

      } on TimeoutException {
        lastException = OrchonException('Request timeout after ${_requestTimeout.inSeconds}s');
        debugPrint('ORCHON attempt ${attempt + 1} timed out');
      } on SocketException catch (e) {
        lastException = OrchonException('Network error: ${e.message}');
        debugPrint('ORCHON attempt ${attempt + 1} network error: $e');
      } on http.ClientException catch (e) {
        lastException = OrchonException('Connection failed: ${e.message}');
        debugPrint('ORCHON attempt ${attempt + 1} connection error: $e');
      } catch (e) {
        // Catch any other exception
        lastException = OrchonException('Unexpected error: $e');
        debugPrint('ORCHON attempt ${attempt + 1} unexpected error: $e');
      }

      // Exponential backoff before next retry
      if (attempt < _maxRetries - 1) {
        final backoff = _initialBackoff * (1 << attempt); // 500ms, 1s, 2s
        debugPrint('ORCHON retrying in ${backoff.inMilliseconds}ms...');
        await Future.delayed(backoff);
      }
    }

    throw lastException ?? OrchonException('Unknown error after $_maxRetries attempts');
  }

  /// Fetch recent deployments across all projects
  Future<List<Deployment>> getRecentDeployments({int limit = 100}) async {
    final uri = Uri.parse('${AppConfig.orchonUrl}/api/deployments/recent')
        .replace(queryParameters: {'limit': limit.toString()});

    final response = await _getWithRetry(uri);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      // API returns {"deployments": [...]} not a raw array
      final List<dynamic> data = decoded is List ? decoded : (decoded['deployments'] ?? []);
      return data.map((json) => Deployment.fromJson(json)).toList();
    } else {
      throw OrchonException(
        'Failed to fetch deployments: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Fetch recent failed deployments
  Future<List<Deployment>> getFailedDeployments({int limit = 5}) async {
    final uri = Uri.parse('${AppConfig.orchonUrl}/api/deployments/failures')
        .replace(queryParameters: {'limit': limit.toString()});

    final response = await _getWithRetry(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Deployment.fromJson(json)).toList();
    } else {
      throw OrchonException(
        'Failed to fetch failures: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Fetch a single deployment by ID
  Future<Deployment?> getDeployment(String id) async {
    final uri = Uri.parse('${AppConfig.orchonUrl}/api/deployments/$id');

    final response = await _getWithRetry(uri);

    if (response.statusCode == 200) {
      return Deployment.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw OrchonException(
        'Failed to fetch deployment: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }

  Map<String, String> get _authHeaders {
    final secret = AppConfig.orchonApiSecret;
    return {
      'Content-Type': 'application/json',
      if (secret.isNotEmpty) 'Authorization': 'Bearer $secret',
    };
  }

  void dispose() {
    _client.close();
  }
}

/// Exception for ORCHON API errors
class OrchonException implements Exception {
  final String message;
  final int? statusCode;

  OrchonException(this.message, {this.statusCode});

  @override
  String toString() => 'OrchonException: $message';
}

/// Notifier for managing deployments state
class DeploymentsNotifier extends StateNotifier<DeploymentsState> {
  final OrchonService _service;

  DeploymentsNotifier(this._service) : super(const DeploymentsState());

  /// Fetch deployments from API
  Future<void> fetchDeployments({int limit = 100}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final deployments = await _service.getRecentDeployments(limit: limit);
      state = state.copyWith(
        deployments: deployments,
        isLoading: false,
        lastFetched: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error fetching deployments: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh deployments (pull-to-refresh)
  Future<void> refresh() => fetchDeployments();

  /// Get only failed deployments from current state
  List<Deployment> get failures =>
      state.deployments.where((d) => d.isFailure).toList();

  /// Get only successful deployments from current state
  List<Deployment> get successes =>
      state.deployments.where((d) => d.isSuccess).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Provider for OrchonService instance
final orchonServiceProvider = Provider<OrchonService>((ref) {
  final service = OrchonService();
  ref.onDispose(service.dispose);
  return service;
});

/// Provider for deployments state
final deploymentsProvider =
    StateNotifierProvider<DeploymentsNotifier, DeploymentsState>((ref) {
  final service = ref.watch(orchonServiceProvider);
  return DeploymentsNotifier(service);
});

/// Provider for just the failures (convenience)
final failedDeploymentsProvider = Provider<List<Deployment>>((ref) {
  final state = ref.watch(deploymentsProvider);
  return state.deployments.where((d) => d.isFailure).toList();
});
