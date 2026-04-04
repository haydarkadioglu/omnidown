import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoRetry = true;
  int _concurrency = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Storage'),
            subtitle: Text('App managed internal downloads folder'),
          ),
          SwitchListTile(
            value: _autoRetry,
            onChanged: (value) => setState(() => _autoRetry = value),
            title: const Text('Auto retry failed downloads'),
          ),
          ListTile(
            title: const Text('Max concurrent downloads'),
            subtitle: Text('$_concurrency'),
            trailing: SizedBox(
              width: 140,
              child: Slider(
                value: _concurrency.toDouble(),
                min: 1,
                max: 3,
                divisions: 2,
                label: '$_concurrency',
                onChanged: (value) => setState(() => _concurrency = value.toInt()),
              ),
            ),
          ),
          const ListTile(
            title: Text('Desteklenen Platformlar (yt-dlp)'),
            subtitle: Text('YouTube, Instagram, TikTok, Twitter, Facebook, Pinterest, Reddit, Vimeo, Dailymotion, SoundCloud ve binlercesi açık kaynak yt-dlp altyapısı ile desteklenmektedir.'),
          ),
          const ListTile(
            title: Text('Disclaimer'),
            subtitle: Text('Download only content you have rights to use. Platform terms may apply.'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Haydar Kadıoğlu tarafından geliştirildi.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('haydarkadioglu.com'),
                SizedBox(height: 4),
                Text(
                  'Open Source ❤️',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
