import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/config.dart';
import '../../core/websocket/websocket_service.dart';
import '../../core/orchon/orchon_service.dart';
import '../../core/updates/update_dialog.dart';
import '../settings/settings_drawer.dart';
import '../terminal/quick_commands.dart';
import '../threads/threads_screen.dart';
import 'widgets/deployment_card.dart';
import 'deployment_detail_screen.dart';

class DeploymentsScreen extends ConsumerStatefulWidget {
  const DeploymentsScreen({super.key});

  @override
  ConsumerState<DeploymentsScreen> createState() => _DeploymentsScreenState();
}

class _DeploymentsScreenState extends ConsumerState<DeploymentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeServices();
    });
  }

  Future<void> _initializeServices() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // Connect WebSocket
    try {
      final wsService = ref.read(webSocketServiceProvider);
      wsService.connect(AppConfig.wsUrl, authToken: 'dev-token');
    } catch (e) {
      debugPrint('WebSocket init error: $e');
    }

    // Fetch deployments
    try {
      await ref.read(deploymentsProvider.notifier).fetchDeployments();
    } catch (e) {
      debugPrint('Deployments fetch error: $e');
    }

    // Check for updates
    try {
      await showUpdateDialogIfAvailable(context, ref);
    } catch (e) {
      debugPrint('Update check error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final deploymentsState = ref.watch(deploymentsProvider);
    final connectionState = ref.watch(connectionStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/icon.svg',
              height: 28,
              width: 28,
            ),
            const SizedBox(width: 10),
            Text(
              'DOEWAH',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 3,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(width: 8),
            _buildConnectionIndicator(connectionState),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt),
            tooltip: 'Quick Commands',
            onPressed: () => showQuickCommands(context),
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      endDrawer: const SettingsDrawer(),
      body: RefreshIndicator(
        onRefresh: () => ref.read(deploymentsProvider.notifier).refresh(),
        child: deploymentsState.isLoading && deploymentsState.deployments.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : deploymentsState.error != null && deploymentsState.deployments.isEmpty
                ? _buildErrorState(deploymentsState.error!)
                : deploymentsState.deployments.isEmpty
                    ? _buildEmptyState()
                    : _buildDeploymentsList(deploymentsState),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewThreadSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New Thread'),
      ),
    );
  }

  Widget _buildConnectionIndicator(AsyncValue<WsConnectionState> connectionState) {
    return connectionState.when(
      data: (state) {
        final Color color;
        final String tooltip;
        switch (state) {
          case WsConnectionState.connected:
            color = Colors.green;
            tooltip = 'Connected';
          case WsConnectionState.connecting:
            color = Colors.orange;
            tooltip = 'Connecting...';
          case WsConnectionState.disconnected:
            color = Colors.grey;
            tooltip = 'Disconnected';
          case WsConnectionState.error:
            color = Colors.red;
            tooltip = 'Connection error';
        }
        return Tooltip(
          message: tooltip,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      loading: () => Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.orange,
          shape: BoxShape.circle,
        ),
      ),
      error: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rocket_launch_outlined,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No deployments yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull to refresh or wait for activity',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load deployments',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.read(deploymentsProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeploymentsList(DeploymentsState state) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.deployments.length,
      itemBuilder: (context, index) {
        final deployment = state.deployments[index];
        return DeploymentCard(
          deployment: deployment,
          onTap: () => _openDeploymentDetail(deployment),
        );
      },
    );
  }

  void _openDeploymentDetail(deployment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeploymentDetailScreen(deployment: deployment),
      ),
    );
  }

  void _showNewThreadSheet(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ThreadsScreen(),
      ),
    );
  }
}
