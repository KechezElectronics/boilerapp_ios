import 'package:flutter/material.dart';
import '../state/device_store.dart';
import '../theme/theme_store.dart';
import '../theme/app_colors.dart';
import '../models/boiler_device.dart';
import '../models/boiler_parameter.dart';
import '../widgets/theme_picker_sheet.dart';
import 'add_boiler_screen.dart';
import 'boiler_dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  final DeviceStore store;
  final ThemeStore themeStore;

  const HomeScreen({
    super.key,
    required this.store,
    required this.themeStore,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeStore,
      builder: (context, _) {
        final colors = themeStore.colors;
        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.background,
            elevation: 0,
            title: Text(
              'Boilers',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
            ),
            actions: [
              IconButton(
                onPressed: () => showThemePicker(context, themeStore),
                icon: Icon(Icons.palette_outlined, color: colors.textPrimary),
                tooltip: 'Change theme',
              ),
            ],
          ),
          body: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              if (!store.listLoaded) {
                return Center(child: CircularProgressIndicator(color: colors.accent));
              }
              if (store.listError != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      store.listError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.danger),
                    ),
                  ),
                );
              }
              if (store.devices.isEmpty) {
                return _EmptyState(colors: colors, onAdd: () => _openAddScreen(context));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: store.devices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final device = store.devices[index];
                  return _BoilerCard(
                    device: device,
                    store: store,
                    colors: colors,
                    onDelete: () => _confirmDelete(context, device, colors),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BoilerDashboardScreen(
                          store: store,
                          themeStore: themeStore,
                          deviceId: device.id,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: colors.accent,
            onPressed: () => _openAddScreen(context),
            child: Icon(Icons.add, color: colors.onAccent),
          ),
        );
      },
    );
  }

  void _openAddScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddBoilerScreen(store: store, themeStore: themeStore)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, BoilerDevice device, AppColors colors) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Remove boiler?', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'This removes ${device.name} from this phone. You will need the device ID and claim code to add it again. '
          'The boiler itself keeps running.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Remove', style: TextStyle(color: colors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await store.removeDevice(device.id);
    }
  }
}

class _BoilerCard extends StatelessWidget {
  final BoilerDevice device;
  final DeviceStore store;
  final AppColors colors;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _BoilerCard({
    required this.device,
    required this.store,
    required this.colors,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = store.isOnline(device.id);
    final error = store.connectionErrorFor(device.id);
    final previewParam = device.enabledParameters.isNotEmpty ? device.enabledParameters.first : null;
    final previewValue = previewParam != null ? store.valueFor(device.id, previewParam) : null;
    final previewInfo = previewParam != null ? boilerParameterInfo[previewParam] : null;
    final previewFaulted = previewParam != null && store.hasFault(device.id, previewParam);

    return Dismissible(
      key: ValueKey(device.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // the confirm dialog + store handle removal, not the swipe itself
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: colors.danger, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLive ? colors.accent : colors.textMuted,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name,
                        style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      error ?? device.location,
                      style: TextStyle(color: error != null ? colors.danger : colors.textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (previewInfo != null)
                Text(
                  previewFaulted
                      ? 'Fault'
                      : (previewValue != null ? '${previewValue.toStringAsFixed(1)} ${previewInfo.unit}' : '--'),
                  style: TextStyle(
                    color: previewFaulted ? colors.danger : previewInfo.color,
                    fontSize: 16,
                    fontWeight: previewFaulted ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppColors colors;
  final VoidCallback onAdd;

  const _EmptyState({required this.colors, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_outlined, size: 48, color: colors.textMuted),
          const SizedBox(height: 12),
          Text('No boilers yet', style: TextStyle(color: colors.textPrimary, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Add your first boiler to start monitoring it.', style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add boiler'),
          ),
        ],
      ),
    );
  }
}
