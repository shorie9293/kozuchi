import 'package:flutter/material.dart';
import 'package:kozuchi/core/theme/app_theme.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:kozuchi/features/tutorial/data/kozuchi_tutorial_service.dart';
import 'package:kozuchi/features/tutorial/presentation/kozuchi_tutorial_overlay.dart';
import 'package:kozuchi/features/tutorial/domain/kozuchi_tutorial_step.dart';
import 'package:kozuchi/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isFirstLaunch = await KozuchiTutorialService.isFirstLaunch();
  runApp(MyApp(isFirstLaunch: isFirstLaunch));
}

class MyApp extends StatefulWidget {
  final bool isFirstLaunch;
  const MyApp({super.key, this.isFirstLaunch = false});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _showTutorial;

  @override
  void initState() {
    super.initState();
    _showTutorial = widget.isFirstLaunch;
  }

  void _onTutorialComplete() {
    KozuchiTutorialService.markCompleted();
    setState(() => _showTutorial = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'kozuchi',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: ErrorBoundary(
        child: _showTutorial
            ? _TutorialRoot(onComplete: _onTutorialComplete)
            : const MainScreen(),
      ),
    );
  }
}

/// チュートリアル進行Widget
class _TutorialRoot extends StatefulWidget {
  final VoidCallback onComplete;
  const _TutorialRoot({required this.onComplete});

  @override
  State<_TutorialRoot> createState() => _TutorialRootState();
}

class _TutorialRootState extends State<_TutorialRoot> {
  KozuchiTutorialStep _step = KozuchiTutorialStep.welcome;

  void _advance() {
    final next = _step.next;
    if (next != null) {
      setState(() => _step = next);
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return KozuchiTutorialOverlay(
      step: _step,
      onComplete: _advance,
      child: const MainScreen(),
    );
  }
}
