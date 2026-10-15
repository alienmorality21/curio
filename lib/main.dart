import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'repositories/fact_republic_repository.dart';
import 'screens/discover_screen.dart';
import 'storage/fact_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CurioApp(repository: FactRepublicRepository()));
}

class CurioApp extends StatefulWidget {
  const CurioApp({super.key, required this.repository, this.storage});

  final FactRepublicRepository repository;
  final FactStorage? storage;

  @override
  State<CurioApp> createState() => _CurioAppState();
}

class _CurioAppState extends State<CurioApp> {
  CurioThemePreference _themePreference = CurioThemePreference.system;
  double _factTextScale = 1;
  double _factLineSpacing = 1.4;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getString('theme_preference');
      final textScale = preferences.getDouble('fact_text_scale');
      final lineSpacing = preferences.getDouble('fact_line_spacing');
      final preference = CurioThemePreference.values
          .where((value) => value.name == stored)
          .firstOrNull;
      if (mounted) {
        setState(() {
          if (preference != null) _themePreference = preference;
          if (textScale != null) _factTextScale = textScale;
          if (lineSpacing != null) _factLineSpacing = lineSpacing;
        });
      }
    } on Exception catch (error, stackTrace) {
      debugPrint(
        'Could not restore Curio theme preference: $error\n$stackTrace',
      );
    }
  }

  Future<void> _setThemePreference(CurioThemePreference preference) async {
    final previousPreference = _themePreference;
    setState(() => _themePreference = preference);
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        'theme_preference',
        preference.name,
      );
      if (!saved) throw Exception('Theme preference was not saved.');
    } on Exception catch (error, stackTrace) {
      debugPrint('Could not save Curio theme preference: $error\n$stackTrace');
      if (mounted) setState(() => _themePreference = previousPreference);
      rethrow;
    }
  }

  Future<void> _setReadingSettings(double textScale, double lineSpacing) async {
    final previousScale = _factTextScale;
    final previousSpacing = _factLineSpacing;
    setState(() {
      _factTextScale = textScale;
      _factLineSpacing = lineSpacing;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      final scaleSaved = await preferences.setDouble(
        'fact_text_scale',
        textScale,
      );
      final spacingSaved = await preferences.setDouble(
        'fact_line_spacing',
        lineSpacing,
      );
      if (!scaleSaved || !spacingSaved) {
        throw Exception('Reading settings were not saved.');
      }
    } on Exception catch (error, stackTrace) {
      debugPrint('Could not save reading settings: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _factTextScale = previousScale;
          _factLineSpacing = previousSpacing;
        });
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Curio',
      debugShowCheckedModeBanner: false,
      themeMode: themeModeFor(_themePreference),
      theme: curioTheme(Brightness.light),
      darkTheme: curioTheme(
        Brightness.dark,
        oled: _themePreference == CurioThemePreference.oled,
      ),
      home: DiscoverScreen(
        repository: widget.repository,
        themePreference: _themePreference,
        onThemeChanged: _setThemePreference,
        factTextScale: _factTextScale,
        factLineSpacing: _factLineSpacing,
        onReadingSettingsChanged: _setReadingSettings,
        storage: widget.storage,
      ),
    );
  }
}
