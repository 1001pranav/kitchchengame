import 'package:flutter/material.dart';

import '../scene/shopfront.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The opening: who you are and what is at stake, in four short lines, over
/// a rainy street. Tap to go on; Skip goes straight to the market.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  int _page = 0;

  List<(String, String)> _pages(int cash) => [
        (
          'Twelve years in other people\'s kitchens.',
          'Double shifts. Burnt hands. Other people\'s names over the door.'
        ),
        (
          'You have ${fmtMoney(cash)} coins.',
          'Every coin you saved. Tonight you buy a restaurant of your own.'
        ),
        (
          'Nothing for sale is for sale by accident.',
          'Debts in the drawer. Staff who have not been paid. An oven older than the waiters.'
        ),
        (
          'Keep it alive. Then make it matter.',
          'Miss three loan payments and the bank takes the keys. Get it right and one restaurant becomes many.'
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final pages = _pages(c.state!.cash);
    final last = _page == pages.length - 1;
    final (title, body) = pages[_page];
    return Scaffold(
      backgroundColor: Palette.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => last ? c.finishIntro() : setState(() => _page++),
        child: Stack(children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.55,
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.transparent],
                  stops: [0.35, 0.8],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: LayoutBuilder(
                  builder: (context, box) => Shopfront(
                      name: 'FOR SALE',
                      quality: 1,
                      time: DayTime.night,
                      open: false,
                      rain: true,
                      animate: true,
                      height: box.maxHeight,
                      seed: 7),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: TextButton(
                          onPressed: c.finishIntro, child: const Text('Skip')),
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 700),
                      switchInCurve: Curves.easeOut,
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                            position: Tween(
                                    begin: const Offset(0, 0.06),
                                    end: Offset.zero)
                                .animate(a),
                            child: child),
                      ),
                      child: Column(
                        key: ValueKey(_page),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(height: 1.2, fontSize: 30)),
                          const SizedBox(height: 14),
                          Text(body,
                              style: const TextStyle(
                                  color: Palette.muted,
                                  fontSize: 16,
                                  height: 1.55)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    Row(children: [
                      for (var i = 0; i < pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _page ? 22 : 8,
                          height: 3,
                          color: i <= _page ? Palette.accent : Palette.line,
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () =>
                            last ? c.finishIntro() : setState(() => _page++),
                        child: Text(last ? 'See what is for sale' : 'Continue'),
                      ),
                    ]),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}
