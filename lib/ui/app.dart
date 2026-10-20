import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app_build.dart';
import '../core_bridge.dart';
import '../local_store.dart';
import '../theme_color.dart';
import 'app_scope.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';
import 'theme/system_color.dart';
import 'widgets/focus_ring.dart';

class DuanjuApp extends StatefulWidget {
  const DuanjuApp({
    super.key,
    required this.repository,
    this.store,
    this.bootstrapError,
    this.onRetry,
    this.television = false,
  });
  final AppRepository repository;
  final LocalStore? store;
  final String? bootstrapError;
  final VoidCallback? onRetry;
  final bool television;

  @override
  State<DuanjuApp> createState() => _DuanjuAppState();
}

class _DuanjuAppState extends State<DuanjuApp> with WidgetsBindingObserver {
  Color? _systemColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSystemColor();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadSystemColor();
  }

  Future<void> _loadSystemColor() async {
    final color = await readSystemColor();
    if (mounted && color != _systemColor) {
      setState(() => _systemColor = color);
    }
  }

  KeyEventResult _escape(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return KeyEventResult.ignored;
    const intent = DismissIntent();
    final action = Actions.maybeFind<DismissIntent>(context, intent: intent);
    if (action != null &&
        Actions.of(context).invokeActionIfEnabled(action, intent, context).$1) {
      return KeyEventResult.handled;
    }
    final navigator = Navigator.maybeOf(context);
    if (navigator == null || !navigator.canPop()) {
      return KeyEventResult.ignored;
    }
    navigator.maybePop();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return store == null
        ? _application(null)
        : ListenableBuilder(
            listenable: store,
            builder: (_, _) => _application(store),
          );
  }

  Widget _application(LocalStore? store) {
    final mode = store?.displayMode ?? 'auto';
    final television =
        mode == 'television' || mode == 'auto' && widget.television;
    final systemColor = (store?.followSystemColor ?? true)
        ? _systemColor
        : null;
    final seed =
        systemColor ?? Color((store?.themeColor ?? ThemeColor.orange).seed);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => FocusManager.instance.highlightStrategy = television
          ? FocusHighlightStrategy.alwaysTraditional
          : FocusHighlightStrategy.automatic,
    );
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const FocusOutlineScrollBehavior(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.build(seed, Brightness.light, television: television),
      darkTheme: AppTheme.build(seed, Brightness.dark, television: television),
      themeMode: AppTheme.mode(store?.themeMode ?? 'system'),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemBars(Theme.of(context).brightness),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (_, event) => _escape(event),
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.select, includeRepeats: false):
                  ActivateIntent(),
              SingleActivator(
                LogicalKeyboardKey.gameButtonA,
                includeRepeats: false,
              ): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.goBack): DismissIntent(),
            },
            child: AppScope(
              repository: widget.repository,
              television: television,
              desktop:
                  mode != 'pad' &&
                  switch (defaultTargetPlatform) {
                    TargetPlatform.windows ||
                    TargetPlatform.macOS ||
                    TargetPlatform.linux => true,
                    _ => false,
                  },
              systemColorAvailable: _systemColor != null,
              child: FocusOutlineLayer(
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(
                    requestFocusCallback: revealFocus,
                  ),
                  child: child!,
                ),
              ),
            ),
          ),
        ),
      ),
      home: switch (store) {
        null => _BootScreen(
          error: widget.bootstrapError,
          onRetry: widget.onRetry,
        ),
        LocalStore(locked: true) => const _BootScreen(
          error: '当前用户需要验证，用户页面还在重建中',
        ),
        _ => AppShell(store: store),
      },
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen({this.error, this.onRetry});
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 24,
          children: [
            Icon(
              Icons.play_circle_fill_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 72,
            ),
            Text(
              error ?? '正在打开$appName',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (error == null)
              const CircularProgressIndicator()
            else if (onRetry != null)
              FilledButton(onPressed: onRetry, child: const Text('重新打开')),
          ],
        ),
      ),
    ),
  );
}
