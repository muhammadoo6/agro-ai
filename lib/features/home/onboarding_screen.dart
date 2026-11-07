import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';

/// Экран приветствия при первом запуске.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final s = AppScope.of(context);
    await s.settings.update(s.settings.value.copyWith(onboarded: true));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = context.l;
    final lang = s.settings.value.languageCode;
    final pages = [
      (Icons.eco, l.t('ob1_title'), l.t('ob1_text')),
      (Icons.document_scanner, l.t('ob2_title'),
          l.t(s.config.isOffline ? 'ob2_text_offline' : 'ob2_text_online')),
      (Icons.insights, l.t('ob3_title'), l.t('ob3_text')),
    ];
    final last = _index == pages.length - 1;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<String>(
                  style: SegmentedButton.styleFrom(
                    foregroundColor: Colors.white,
                    selectedForegroundColor: const Color(0xFF1B5E20),
                    selectedBackgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  segments: [
                    for (final e in supportedLanguages.entries)
                      ButtonSegment(value: e.key, label: Text(e.value)),
                  ],
                  selected: {lang},
                  onSelectionChanged: (v) =>
                      s.settings.update(s.settings.value.copyWith(languageCode: v.first)),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _page,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    for (final (icon, title, text) in pages)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.6, end: 1),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.elasticOut,
                              builder: (context, v, child) =>
                                  Transform.scale(scale: v, child: child),
                              child: Container(
                                padding: const EdgeInsets.all(28),
                                decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, size: 72, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.all(4),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? Colors.white : Colors.white38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(
                  children: [
                    if (!last)
                      TextButton(
                        key: const Key('ob_skip'),
                        onPressed: _finish,
                        child: Text(l.t('ob_skip'),
                            style: const TextStyle(color: Colors.white70)),
                      ),
                    const Spacer(),
                    FilledButton(
                      key: const Key('ob_next'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1B5E20),
                        minimumSize: const Size(140, 52),
                      ),
                      onPressed: last
                          ? _finish
                          : () => _page.nextPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic),
                      child: Text(l.t(last ? 'ob_start' : 'ob_next')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
