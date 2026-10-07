import 'package:flutter/material.dart';
import '../state/device_store.dart';
import '../theme/theme_store.dart';
import '../theme/app_colors.dart';
import '../models/boiler_device.dart';
import '../models/boiler_parameter.dart';

class BoilerDashboardScreen extends StatelessWidget {
  final DeviceStore store;
  final ThemeStore themeStore;
  final String deviceId;

  const BoilerDashboardScreen({
    super.key,
    required this.store,
    required this.themeStore,
    required this.deviceId,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeStore,
      builder: (context, _) {
        final colors = themeStore.colors;
        return Scaffold(
          backgroundColor: colors.background,
          body: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final matches = store.devices.where((d) => d.id == deviceId);
              final BoilerDevice? device = matches.isEmpty ? null : matches.first;
              if (device == null) {
                return Center(
                  child: Text('Boiler removed', style: TextStyle(color: colors.textSecondary)),
                );
              }
              final isLive = store.isOnline(deviceId);
              final error = store.connectionErrorFor(deviceId);

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                          ),
                          Expanded(
                            child: Text(
                              device.name,
                              style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 48),
                        child: Text(device.location, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: (isLive ? colors.accent : colors.danger).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(isLive ? Icons.wifi : Icons.wifi_off,
                                size: 16, color: isLive ? colors.accent : colors.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                error ?? (isLive ? 'Live' : 'Offline'),
                                style: TextStyle(
                                  color: isLive ? colors.accent : colors.danger,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.05,
                          children: device.enabledParameters
                              .map((param) => _ParamTile(
                                    param: param,
                                    value: store.valueFor(deviceId, param),
                                    faulted: store.hasFault(deviceId, param),
                                    colors: colors,
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ParamTile extends StatelessWidget {
  final BoilerParameter param;
  final double? value;
  final bool faulted;
  final AppColors colors;

  const _ParamTile({
    required this.param,
    required this.value,
    required this.faulted,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final info = boilerParameterInfo[param]!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: faulted ? Border.all(color: colors.danger, width: 1.5) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(info.label, style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Icon(faulted ? Icons.warning_amber_rounded : info.icon, size: 26, color: faulted ? colors.danger : info.color),
          const SizedBox(height: 8),
          Text(
            faulted
                ? 'Fault'
                : (value != null ? '${value!.toStringAsFixed(1)} ${info.unit}' : '--'),
            style: TextStyle(
              color: faulted ? colors.danger : (value != null ? colors.textPrimary : colors.textMuted),
              fontSize: faulted ? 16 : 20,
              fontWeight: faulted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (faulted) ...[
            const SizedBox(height: 2),
            Text(
              'Not connected or faulted',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.danger.withOpacity(0.8), fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}
