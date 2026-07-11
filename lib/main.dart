import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/di/di.dart';
import 'core/routing/router.dart';
import 'core/theme/theme.dart';
import 'core/localization/app_localizations.dart';
import 'features/authenticator/presentation/providers/auth_provider.dart';
import 'features/settings/presentation/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Setup GetIt dependency injections
  await setupDependencyInjection();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);

    return LifecycleWatcher(
      child: MaterialApp.router(
        title: 'Digo Authenticator',
        debugShowCheckedModeBanner: false,
        themeMode: settingsState.themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        locale: settingsState.locale,
        supportedLocales: const [
          Locale('en'),
          Locale('hi'),
        ],
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    );
  }
}

class LifecycleWatcher extends ConsumerStatefulWidget {
  final Widget child;
  const LifecycleWatcher({super.key, required this.child});

  @override
  ConsumerState<LifecycleWatcher> createState() => _LifecycleWatcherState();
}

class _LifecycleWatcherState extends ConsumerState<LifecycleWatcher> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final settings = ref.read(settingsProvider);
    final authNotifier = ref.read(authProvider.notifier);

    if (state == AppLifecycleState.paused) {
      authNotifier.handleAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      authNotifier.handleAppResumed(settings.autoLockDuration);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
