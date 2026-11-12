import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../features/focus/widgets/focus_companion_view.dart';

/// Dev-only entry point: the focus companion on a fake session where one second is one
/// minute (planned 20). No login, no Backend, nothing written.
/// Run: flutter run -t lib/dev/focus_companion_preview_main.dart
void main() => runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0D0D0E),
        ),
        home: const _Preview(),
      ),
    );

class _FakeSession extends ChangeNotifier {
  int elapsed = 0;
  Timer? _timer;

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed += 60;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _Preview extends StatefulWidget {
  const _Preview();

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final _FakeSession _session = _FakeSession()..start();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _session,
                  builder: (_, _) => Text(
                    'Fake session: ${_session.elapsed ~/ 60} / 20 min',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),
                FocusCompanionView(
                  session: _session,
                  elapsedSeconds: () => _session.elapsed,
                  plannedMinutes: () => 20,
                ),
              ],
            ),
          ),
        ),
      );
}
