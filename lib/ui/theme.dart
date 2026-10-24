// Colours, type and the two surfaces the whole UI is built from: carved stone and parchment.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class Palette {
  static const ground = Color(0xFF14110D);
  static const stone0 = Color(0xFF1D1913);
  static const stone1 = Color(0xFF2C261D);
  static const stone2 = Color(0xFF3B3327);
  static const stone3 = Color(0xFF51463A);
  static const stoneHi = Color(0xFF6E604C);
  static const parch = Color(0xFFDDD0B1);
  static const parch2 = Color(0xFFCBBB96);
  static const parchLine = Color(0xFFAE9A72);
  static const ink = Color(0xFF231B12);
  static const inkSoft = Color(0xFF5F4F3A);
  static const cream = Color(0xFFEFE4C8);
  static const amber = Color(0xFFE3A548);
  static const amberLo = Color(0xFF9B6A22);
  static const blood = Color(0xFFA8291F);
  static const bloodDeep = Color(0xFF6E2016);
  static const moss = Color(0xFF4F7F37);
  static const good = Color(0xFF2F5A1F);
  static const goldText = Color(0xFF7A5A12);
  static const frost = Color(0xFF8FC3D9);
}

const _shadow = [Shadow(offset: Offset(1, 1), color: Colors.black)];

class Txt {
  static TextStyle logo() => GoogleFonts.cinzel(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.1,
    color: Palette.amber,
    shadows: const [Shadow(offset: Offset(2, 2), color: Colors.black)],
  );

  /// Small-caps labels on stone.
  static TextStyle label({double size = 14, Color color = Palette.cream, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.alegreyaSansSc(fontSize: size, fontWeight: weight, color: color, shadows: _shadow, letterSpacing: .3);

  /// Small-caps labels on parchment (no shadow).
  static TextStyle inkLabel({double size = 14, Color color = Palette.ink, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.alegreyaSansSc(fontSize: size, fontWeight: weight, color: color, letterSpacing: .3);

  static TextStyle body({double size = 15, Color color = Palette.ink, FontWeight weight = FontWeight.w400, bool italic = false}) =>
      GoogleFonts.alegreyaSans(fontSize: size, fontWeight: weight, color: color, fontStyle: italic ? FontStyle.italic : FontStyle.normal, height: 1.3);

  static TextStyle onStone({double size = 14, Color color = Palette.parch2}) => GoogleFonts.alegreyaSans(fontSize: size, color: color, shadows: _shadow);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Palette.ground,
    colorScheme: const ColorScheme.dark(primary: Palette.amber, secondary: Palette.blood, surface: Palette.stone2, onSurface: Palette.cream),
  );
  return base.copyWith(
    textTheme: GoogleFonts.alegreyaSansTextTheme(base.textTheme),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF3EAD2),
      labelStyle: Txt.body(size: 14, color: Palette.inkSoft),
      // Readable examples and icons on the cream fill (the defaults were nearly invisible).
      hintStyle: Txt.body(size: 14, color: Palette.inkSoft.withValues(alpha: .7), italic: true),
      prefixIconColor: Palette.inkSoft,
      suffixIconColor: Palette.ink,
      floatingLabelStyle: Txt.body(size: 14, color: Palette.inkSoft),
      border: const OutlineInputBorder(
        borderSide: BorderSide(color: Palette.parchLine),
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Palette.parchLine),
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Palette.amberLo, width: 1.6),
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
    ),
  );
}

/// Bevelled stone: the frame for panels, buttons and chips.
BoxDecoration stoneDecoration({Color fill = Palette.stone2, bool raised = true}) => BoxDecoration(
  borderRadius: BorderRadius.circular(3),
  border: Border.all(color: Palette.stone0, width: 2),
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color.lerp(fill, Colors.white, .06)!, Color.lerp(fill, Colors.black, .12)!],
  ),
  boxShadow: raised ? const [BoxShadow(color: Colors.black, offset: Offset(0, 2))] : null,
);

BoxDecoration parchmentDecoration() => BoxDecoration(
  borderRadius: BorderRadius.circular(3),
  border: Border.all(color: Palette.stone0, width: 2),
  gradient: const RadialGradient(center: Alignment(0, -1.2), radius: 1.6, colors: [Color(0xFFE8DDC2), Palette.parch, Color(0xFFCFBF98)], stops: [0, .55, 1]),
  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(0, 2))],
);

/// A panel of carved stone with an inner highlight line.
class Stone extends StatelessWidget {
  const Stone({super.key, required this.child, this.padding = const EdgeInsets.all(10), this.fill = Palette.stone2});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color fill;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: stoneDecoration(fill: fill),
    child: Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        border: Border.all(color: Palette.stoneHi.withValues(alpha: .7)),
        borderRadius: BorderRadius.circular(2),
      ),
      padding: padding,
      child: child,
    ),
  );
}

class Parchment extends StatelessWidget {
  const Parchment({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 12)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: parchmentDecoration(),
    child: Padding(padding: padding, child: child),
  );
}

enum ButtonTone { stone, blood, amber }

/// A pressable stone block with a title and an optional caption.
class StoneButton extends StatefulWidget {
  const StoneButton({super.key, required this.title, this.caption, this.onPressed, this.tone = ButtonTone.stone, this.compact = false});
  final String title;
  final String? caption;
  final VoidCallback? onPressed;
  final ButtonTone tone;
  final bool compact;

  @override
  State<StoneButton> createState() => _StoneButtonState();
}

class _StoneButtonState extends State<StoneButton> {
  bool _down = false, _hover = false;

  String get title => widget.title;
  String? get caption => widget.caption;
  VoidCallback? get onPressed => widget.onPressed;
  ButtonTone get tone => widget.tone;
  bool get compact => widget.compact;

  void _tap() {
    HapticFeedback.selectionClick();
    onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final fill = switch (tone) {
      ButtonTone.blood => Palette.bloodDeep,
      ButtonTone.amber => const Color(0xFFC9963E),
      ButtonTone.stone => Palette.stone2,
    };
    final titleColour = switch (tone) {
      ButtonTone.blood => const Color(0xFFFFF0DC),
      ButtonTone.amber => const Color(0xFF2A1C0C),
      ButtonTone.stone => Palette.cream,
    };
    final enabled = onPressed != null;
    // Pressed buttons sink a touch; hovered ones lift a shade lighter.
    return AnimatedScale(
      scale: _down && enabled ? .965 : 1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: Opacity(
      opacity: enabled ? 1 : .5,
      child: Semantics(
        button: true,
        enabled: enabled,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? _tap : null,
            onHighlightChanged: (v) => setState(() => _down = v),
            onHover: (v) => setState(() => _hover = v),
            borderRadius: BorderRadius.circular(3),
            child: Ink(
              decoration: stoneDecoration(fill: _hover && enabled ? Color.lerp(fill, Colors.white, .08)! : fill),
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 6 : 11),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: tone == ButtonTone.amber
                        ? Txt.inkLabel(size: compact ? 13 : 17, color: titleColour)
                        : Txt.label(size: compact ? 13 : 17, color: titleColour, weight: FontWeight.w800),
                  ),
                  if (caption != null)
                    Text(
                      caption!,
                      textAlign: TextAlign.center,
                      style: Txt.onStone(size: 12.5, color: tone == ButtonTone.blood ? const Color(0xFFEEC4B6) : Palette.parch2),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// A labelled HP or XP bar on stone.
class Meter extends StatelessWidget {
  const Meter({super.key, required this.label, required this.value, required this.max, required this.colours, this.trailing});
  final String label;
  final int value, max;
  final List<Color> colours;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final f = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Txt.label(size: 13, color: Palette.parch),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // The numbers count to their new value rather than jumping.
            trailing != null
                ? Text(trailing!, style: Txt.label(size: 13).copyWith(fontFeatures: const [FontFeature.tabularFigures()]))
                : TweenAnimationBuilder<double>(
                    tween: Tween(end: value.toDouble()),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOut,
                    builder: (_, v, __) => Text('${v.round()} / $max', style: Txt.label(size: 13).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFF120F0B),
            border: Border.all(color: Colors.black),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOut,
              widthFactor: f,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colours),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Two-option segmented tabs, styled for stone or parchment.
class Tabs<T> extends StatelessWidget {
  const Tabs({super.key, required this.items, required this.selected, required this.onSelect, this.onParchment = false, this.enabled});
  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onSelect;
  final bool onParchment;
  final bool Function(T)? enabled;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, (v, label)) in items.indexed) ...[if (i > 0) const SizedBox(width: 4), Expanded(child: _tab(v, label))],
    ],
  );

  Widget _tab(T v, String label) {
    final on = v == selected, ok = enabled?.call(v) ?? true;
    final bg = onParchment ? (on ? Palette.ink : Colors.transparent) : (on ? Palette.stone3 : Palette.stone1);
    final fg = onParchment ? (on ? Palette.parch : Palette.inkSoft) : (on ? Palette.amber : Palette.parch2);
    return Opacity(
      opacity: ok ? 1 : .45,
      child: Semantics(
        selected: on,
        button: true,
        child: InkWell(
          onTap: ok ? () => onSelect(v) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: onParchment ? (on ? Palette.ink : Palette.parchLine) : Colors.black),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: onParchment ? Txt.inkLabel(size: 14, color: fg, weight: FontWeight.w700) : Txt.label(size: 14, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// Calories are your hero's stamina: a bolt and the number ("⚡ 368"). Food you log fills your
/// hero with stamina; today's allowance is what "fully fuelled" means.
class StaminaText extends StatelessWidget {
  const StaminaText(this.kcal, {super.key, this.size = 15, this.colour = Palette.amber, this.prefix = '', this.suffix = '', this.weight = FontWeight.w800, this.onParchment = false});
  final int kcal;
  final double size;
  final Color colour;
  final String prefix, suffix;
  final FontWeight weight;
  final bool onParchment;

  @override
  Widget build(BuildContext context) {
    final style = onParchment ? Txt.inkLabel(size: size, color: colour, weight: weight) : Txt.label(size: size, color: colour, weight: weight);
    return Text.rich(
      TextSpan(
        children: [
          if (prefix.isNotEmpty) TextSpan(text: prefix),
          WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(Icons.bolt, size: size * 1.05, color: colour)),
          TextSpan(text: formatStamina(kcal)),
          if (suffix.isNotEmpty) TextSpan(text: suffix),
        ],
      ),
      style: style,
      semanticsLabel: '$prefix$kcal stamina$suffix',
    );
  }
}

/// 1234 → "1,234".
String formatStamina(int n) {
  final s = n.abs().toString(), b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
