import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vid_donw/app/theme_provider.dart';
import 'package:vid_donw/features/download/services/download_manager.dart';
import 'package:vid_donw/features/downloads/presentation/downloads_screen.dart';
import 'package:vid_donw/features/home/presentation/home_screen.dart';
import 'package:vid_donw/features/history/presentation/history_screen.dart';
import 'package:vid_donw/features/settings/presentation/settings_screen.dart';

class DownloaderApp extends StatelessWidget {
  const DownloaderApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DownloadManager()..bootstrap()),
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'OmniDown',
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              colorSchemeSeed: Colors.blue, 
              useMaterial3: true,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              colorSchemeSeed: Colors.blue,
              useMaterial3: true,
              brightness: Brightness.dark,
            ),
            home: const _RootScaffold(),
          );
        },
      ),
    );
  }
}

class _RootScaffold extends StatefulWidget {
  const _RootScaffold();

  @override
  State<_RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<_RootScaffold> {
  int _index = 0;
  final _screens = const [HomeScreen(), DownloadsScreen(), HistoryScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          // Tablet / Desktop Layout
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (value) => setState(() => _index = value),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.home_outlined), label: Text('Home')),
                    NavigationRailDestination(icon: Icon(Icons.downloading_outlined), label: Text('Downloads')),
                    NavigationRailDestination(icon: Icon(Icons.history), label: Text('History')),
                    NavigationRailDestination(icon: Icon(Icons.settings_outlined), label: Text('Settings')),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: ClipRect(
                        child: IndexedStack(
                          index: _index,
                          children: _screens,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Phone Layout
        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: _screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.downloading_outlined), label: 'Downloads'),
              NavigationDestination(icon: Icon(Icons.history), label: 'History'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
            ],
          ),
        );
      },
    );
  }
}
