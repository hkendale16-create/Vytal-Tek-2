import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/vytal_theme.dart';
import '../../fitness/repositories/fitness_repositories.dart';
import '../../fitness/repositories/local_fitness_store.dart';
import '../../fitness/repositories/local_fitness_sync.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

/// Cloud sync status — pending queue + optional endpoint + Sync now.
class FitnessSyncSettingsScreen extends ConsumerStatefulWidget {
  const FitnessSyncSettingsScreen({super.key});

  @override
  ConsumerState<FitnessSyncSettingsScreen> createState() =>
      _FitnessSyncSettingsScreenState();
}

class _FitnessSyncSettingsScreenState
    extends ConsumerState<FitnessSyncSettingsScreen> {
  final _endpoint = TextEditingController();
  var _pending = 0;
  var _loading = true;
  var _flushing = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _endpoint.dispose();
    super.dispose();
  }

  LocalQueuedFitnessSyncPort? get _port {
    final port = ref.read(fitnessSyncPortProvider);
    return port is LocalQueuedFitnessSyncPort ? port : null;
  }

  Future<void> _reload() async {
    final port = ref.read(fitnessSyncPortProvider);
    final pending = await port.pendingCount();
    final endpoint = await _port?.loadEndpointUrl();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _endpoint.text = endpoint ?? '';
      _loading = false;
    });
  }

  Future<void> _saveEndpoint() async {
    final port = _port;
    if (port == null) {
      setState(() => _status = 'Sync port does not support endpoint config.');
      return;
    }
    await port.setEndpointUrl(_endpoint.text);
    if (!mounted) return;
    setState(() => _status = 'Endpoint saved on this device.');
    await _reload();
  }

  Future<void> _flush() async {
    setState(() {
      _flushing = true;
      _status = null;
    });
    final result = await ref.read(fitnessSyncPortProvider).flush();
    if (!mounted) return;
    setState(() {
      _flushing = false;
      _pending = result.remainingCount;
      _status = result.message ??
          switch (result.mode) {
            FitnessSyncFlushMode.localOnly => 'Queue kept locally.',
            FitnessSyncFlushMode.remoteOk => 'Synced.',
            FitnessSyncFlushMode.remoteFailed => 'Sync failed.',
          };
    });
  }

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;

    return SectionScaffold(
      title: 'Fitness sync',
      subtitle: 'Local queue with optional cloud flush.',
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending events',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_pending',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                    'Completed workouts enqueue here and flush to the Vytal '
                    'fitness-sync Edge Function when you are signed in. '
                    'Nothing is marked delivered until HTTP 2xx.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: extras.textMuted),
                  ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Sync endpoint (optional)',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _endpoint,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          hintText: 'https://api.example.com/fitness/sync',
                          labelText: 'POST URL',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _saveEndpoint,
                        child: const Text('Save endpoint'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _flushing ? null : _flush,
                  icon: _flushing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(_flushing ? 'Syncing…' : 'Sync now'),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _status!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: extras.textMuted),
                  ),
                ],
              ],
            ),
    );
  }
}
