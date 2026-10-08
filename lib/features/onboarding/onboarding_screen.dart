import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/components.dart';
import '../../providers.dart';

/// 3 écrans d'introduction (décision du 08/10/2026), affichés une seule fois.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  final IconData icon;
  final Color color;
  final String titleKey;
  final String bodyKey;

  const _Slide(this.icon, this.color, this.titleKey, this.bodyKey);
}

const _slides = [
  _Slide(Icons.local_taxi_rounded, AppColors.primary, 'intro1_title', 'intro1_body'),
  _Slide(Icons.near_me_rounded, AppColors.accent, 'intro2_title', 'intro2_body'),
  _Slide(Icons.account_balance_wallet_rounded, AppColors.primary, 'intro3_title', 'intro3_body'),
];

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Le routeur redirige vers /login dès que l'intro est marquée comme vue.
  Future<void> _finish() => ref.read(onboardingSeenProvider.notifier).markSeen();

  void _next() {
    if (_index == _slides.length - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;
    return Scaffold(
      body: SoftGradient(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    Image.asset('assets/branding/logo.png', height: 32),
                    const Spacer(),
                    if (!isLast)
                      TextButton(onPressed: _finish, child: Text(context.tr('intro_skip'))),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
                ),
              ),
              PageDots(count: _slides.length, index: _index),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: FilledButton(
                  onPressed: _next,
                  child: Text(context.tr(isLast ? 'intro_start' : 'intro_next')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final eden = context.eden;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration simple : cercles concentriques + icône.
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: eden.surface.withOpacity(0.6),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, color: eden.surface),
              alignment: Alignment.center,
              child: Icon(slide.icon, size: 72, color: slide.color),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            context.tr(slide.titleKey),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(slide.bodyKey),
            textAlign: TextAlign.center,
            style: TextStyle(color: eden.muted, fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}
