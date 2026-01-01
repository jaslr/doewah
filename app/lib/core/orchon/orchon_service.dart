import 'dart:convert';
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

  OrchonService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch recent deployments across all projects
  Future<List<Deployment>> getRecentDeployments({int limit = 100}) async {
    final uri = Uri.parse('${AppConfig.orchonUrl}/api/deployments/recent')
        .replace(queryParameters: {'limit': limit.toString()});

    final response = await _client.get(
      uri,
      headers: _authHeaders,
    );

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

    final response = await _client.get(
      uri,
      headers: _authHeaders,
    );

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

    final response = await _client.get(
      uri,
      headers: _authHeaders,
    );

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
