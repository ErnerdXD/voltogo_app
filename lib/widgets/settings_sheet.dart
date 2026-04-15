import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voltogo_app/providers/theme_provider.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;
    String language = 'English';
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Theme'),
            trailing: Switch(
              value: isDark,
              onChanged: (value) {
                themeProvider.toggleTheme(value);
              },
            ),
          ),
          ListTile(
            title: const Text('Language'),
            trailing: DropdownButton<String>(
              value: language,
              items: const [
                DropdownMenuItem<String>(
                  value: 'English',
                  child: Text('English'),
                ),
                DropdownMenuItem<String>(
                  value: 'Mandarin',
                  child: Text('Mandarin (简体中文)'),
                ),
              ],
              onChanged: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

