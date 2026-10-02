import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

final isDarkModeProvider = Provider<bool>((ref) {
  final mode = ref.watch(themeModeProvider);
  return mode == ThemeMode.dark;
});

void toggleTheme(WidgetRef ref) {
  ref.read(themeModeProvider.notifier).update((state) {
    return state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  });
}
