import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/theme_store.dart';

Future<void> showThemePicker(BuildContext context, ThemeStore themeStore) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: themeStore.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return ListenableBuilder(
        listenable: themeStore,
        builder: (context, _) {
          final colors = themeStore.colors;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('Theme',
                      style: TextStyle(color: colors.textPrimary, fontSize: 17, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('Applies across the whole app.', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  ...appThemes.map((theme) => _ThemeRow(
                        theme: theme,
                        selected: theme.id == colors.id,
                        colors: colors,
                        onTap: () async {
                          await themeStore.select(theme.id);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      )),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _ThemeRow extends StatelessWidget {
  final AppColors theme;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  const _ThemeRow({
    required this.theme,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.background,
                shape: BoxShape.circle,
                border: Border.all(color: theme.accent, width: 2),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(theme.name, style: TextStyle(color: colors.textPrimary, fontSize: 15)),
            ),
            if (selected) Icon(Icons.check, size: 20, color: theme.accent),
          ],
        ),
      ),
    );
  }
}
