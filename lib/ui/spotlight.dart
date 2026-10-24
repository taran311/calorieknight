// Spotlight tours: the screen dims, one part of it is lit up with a note beside it, and Next
// walks on to the next part. Used to explain camp (and energy) before the first meal is logged.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

class SpotStep {
  const SpotStep(this.target, this.title, this.body, {this.icon});

  /// The widget to light up (its key). Missing or off-screen targets are skipped.
  final GlobalKey target;
  final String title, body;
  final IconData? icon;
}

/// Walks through [steps]. Completes when the tour is finished or skipped.
Future<void> showSpotlightTour(BuildContext context, List<SpotStep> steps) async {
  final shown = [for (final s in steps) if (s.target.currentContext != null) s];
  if (shown.isEmpty) return;
  await Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => _Tour(steps: shown),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

class _Tour extends StatefulWidget {
  const _Tour({required this.steps});
  final List<SpotStep> steps;
  @override
  State<_Tour> createState() => _TourState();
}

class _TourState extends State<_Tour> {
  int _i = 0;
  Rect? _rect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go(0));
  }

  /// Scrolls the target into view, then lights it.
  Future<void> _go(int i) async {
    final ctx = widget.steps[i].target.currentContext;
    if (ctx == null) return;
    setState(() {
      _i = i;
      _rect = null;
    });
    await Scrollable.ensureVisible(ctx, alignment: .3, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!mounted || !ctx.mounted) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    setState(() => _rect = box.localToGlobal(Offset.zero) & box.size);
  }

  void _next() {
    if (_i + 1 >= widget.steps.length) {
      Navigator.of(context).pop();
    } else {
      _go(_i + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_i], size = MediaQuery.sizeOf(context), r = _rect;
    final hole = r?.inflate(6);
    // The note goes below the lit part if there's room, otherwise above it.
    final below = hole == null || hole.bottom + 210 < size.height || hole.top < size.height / 2;
    const w = 360.0;
    final cardW = math.min(w, size.width - 24);
    final left = hole == null ? (size.width - cardW) / 2 : (hole.center.dx - cardW / 2).clamp(12.0, size.width - cardW - 12);
    final last = _i + 1 >= widget.steps.length;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _next,
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: hole ?? Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0)),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                builder: (_, rect, __) => CustomPaint(painter: _ScrimPainter(rect)),
              ),
            ),
          ),
          if (hole != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              left: left,
              top: below ? math.min(hole.bottom + 12, size.height - 220) : null,
              bottom: below ? null : size.height - hole.top + 12,
              width: cardW,
              child: _Note(
                step: step,
                index: _i,
                count: widget.steps.length,
                last: last,
                onNext: _next,
                onSkip: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.step, required this.index, required this.count, required this.last, required this.onNext, required this.onSkip});
  final SpotStep step;
  final int index, count;
  final bool last;
  final VoidCallback onNext, onSkip;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: parchmentDecoration().copyWith(boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 14, offset: Offset(0, 4))]),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (step.icon != null) ...[Icon(step.icon, size: 20, color: Palette.goldText), const SizedBox(width: 6)],
              Expanded(child: Text(step.title, style: Txt.inkLabel(size: 17))),
            ],
          ),
          const SizedBox(height: 4),
          Text(step.body, style: Txt.body(size: 14.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var d = 0; d < count; d++)
                Container(
                  width: d == index ? 16 : 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(color: d == index ? Palette.blood : Palette.parchLine, borderRadius: BorderRadius.circular(4)),
                ),
              const Spacer(),
              if (!last) TextButton(onPressed: onSkip, child: Text('Skip', style: Txt.inkLabel(size: 14, color: Palette.inkSoft))),
              StoneButton(title: last ? 'To battle!' : 'Next', tone: ButtonTone.blood, compact: true, onPressed: onNext),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Dims everything except [hole], which gets a soft amber rim.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter(this.hole);
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final h = hole;
    if (h == null || h.isEmpty) {
      canvas.drawPath(all, Paint()..color = const Color(0xC0000000));
      return;
    }
    final rr = RRect.fromRectAndRadius(h, const Radius.circular(6));
    canvas.drawPath(Path.combine(PathOperation.difference, all, Path()..addRRect(rr)), Paint()..color = const Color(0xC0000000));
    canvas.drawRRect(rr, Paint()
      ..color = Palette.amber.withValues(alpha: .9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);
    canvas.drawRRect(rr.inflate(4), Paint()
      ..color = Palette.amber.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}
