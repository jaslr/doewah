import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config.dart';

/// How often to check for updates (30 minutes)
const _updateCheckInterval = Duration(minutes: 30);

class UpdateInfo {
  final String version;
  final int buildNumber;
  final String apkFile;
  final String releaseDate;
  final String? changelog;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.apkFile,
    required this.releaseDate,
    this.changelog,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String,
      buildNumber: json['buildNumber'] as int,
      apkFile: json['apkFile'] as String,
      releaseDate: json['releaseDate'] as String,
      changelog: json['changelog'] as String?,
    );
  }
}

enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  readyToInstall,
  error,
  upToDate,
}

class UpdateState {
  final UpdateStatus status;
  final UpdateInfo? updateInfo;
  final double downloadProgress;
  final String? errorMessage;
  final String? downloadedApkPath;
  final DateTime? lastChecked;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.updateInfo,
    this.downloadProgress = 0,
    this.errorMessage,
    this.downloadedApkPath,
    this.lastChecked,
  });

  /// Whether an update is available (for badge display)
  bool get hasUpdate => status == UpdateStatus.available || status == UpdateStatus.readyToInstall;

  UpdateState copyWith({
    UpdateStatus? status,
    UpdateInfo? updateInfo,
    double? downloadProgress,
    String? errorMessage,
    String? downloadedApkPath,
    DateTime? lastChecked,
  }) {
    return UpdateState(
      status: status ?? this.status,
      updateInfo: updateInfo ?? this.updateInfo,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage,
      downloadedApkPath: downloadedApkPath ?? this.downloadedApkPath,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  Timer? _periodicCheckTimer;

  UpdateNotifier() : super(const UpdateState()) {
    // Check immediately on startup, then periodically
    _startPeriodicChecks();
  }

  void _startPeriodicChecks() {
    // Initial check after a short delay (let app initialize)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) checkForUpdate(silent: true);
    });

    // Periodic checks every 30 minutes
    _periodicCheckTimer = Timer.periodic(_updateCheckInterval, (_) {
      if (mounted) checkForUpdate(silent: true);
    });
  }

  @override
  void dispose() {
    _periodicCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> checkForUpdate({bool silent = false}) async {
    // Don't show "checking" status for silent background checks
    if (!silent) {
      state = state.copyWith(status: UpdateStatus.checking);
    }

    try {
      // Get actual installed version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse('${AppConfig.updateUrl}/version'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final updateInfo = UpdateInfo.fromJson(jsonDecode(response.body));

        // Compare versions using actual installed version
        if (_isNewerVersion(updateInfo.version, currentVersion)) {
          debugPrint('[UpdateService] Update available: ${updateInfo.version} (current: $currentVersion)');
          state = state.copyWith(
            status: UpdateStatus.available,
            updateInfo: updateInfo,
            lastChecked: DateTime.now(),
          );
        } else {
          state = state.copyWith(
            status: UpdateStatus.upToDate,
            lastChecked: DateTime.now(),
          );
        }
      } else if (response.statusCode == 404) {
        state = state.copyWith(
          status: UpdateStatus.upToDate,
          lastChecked: DateTime.now(),
        );
      } else {
        // Only show error for manual checks
        if (!silent) {
          state = state.copyWith(
            status: UpdateStatus.error,
            errorMessage: 'Server returned ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      // Only show error for manual checks, silently ignore for background checks
      if (!silent) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: e.toString(),
        );
      } else {
        debugPrint('[UpdateService] Silent check failed: $e');
      }
    }
  }

  Future<void> downloadAndInstall() async {
    if (state.updateInfo == null) return;

    // Request install permission on Android
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: 'Install permission denied',
        );
        return;
      }
    }

    state = state.copyWith(status: UpdateStatus.downloading, downloadProgress: 0);

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse('${AppConfig.updateUrl}/download'));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: 'Download failed: ${response.statusCode}',
        );
        return;
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      var downloaded = 0;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          state = state.copyWith(
            downloadProgress: downloaded / contentLength,
          );
        }
      }

      // Verify we got the full file
      if (contentLength > 0 && bytes.length != contentLength) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: 'Incomplete download: ${bytes.length}/$contentLength bytes',
        );
        return;
      }

      // Verify it's a valid APK (starts with PK zip header)
      if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: 'Invalid APK file format',
        );
        return;
      }

      // Use app's cache directory (more reliable on modern Android)
      final dir = await getApplicationCacheDirectory();
      final apkPath = '${dir.path}/${state.updateInfo!.apkFile}';
      final file = File(apkPath);

      // Delete old file if exists
      if (await file.exists()) {
        await file.delete();
      }

      await file.writeAsBytes(bytes, flush: true);

      // Verify file was written correctly
      final writtenSize = await file.length();
      if (writtenSize != bytes.length) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: 'File write error: $writtenSize/${bytes.length} bytes',
        );
        return;
      }

      state = state.copyWith(
        status: UpdateStatus.readyToInstall,
        downloadedApkPath: apkPath,
      );

      // Trigger install
      await installUpdate();
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> installUpdate() async {
    if (state.downloadedApkPath == null) return;

    try {
      final result = await OpenFilex.open(state.downloadedApkPath!);
      if (result.type != ResultType.done) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: result.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  bool _isNewerVersion(String remote, String local) {
    final remoteParts = remote.split('.').map(int.parse).toList();
    final localParts = local.split('.').map(int.parse).toList();

    for (var i = 0; i < remoteParts.length && i < localParts.length; i++) {
      if (remoteParts[i] > localParts[i]) return true;
      if (remoteParts[i] < localParts[i]) return false;
    }
    return remoteParts.length > localParts.length;
  }

  void reset() {
    state = const UpdateState();
  }
}

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  return UpdateNotifier();
});
