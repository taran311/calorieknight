// Sign in and create-account screens, styled like the rest of the game.

import 'package:flutter/material.dart';

import '../services/auth.dart';
import 'theme.dart';

class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.title, required this.subtitle, required this.children});
  final String title, subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: SizedBox(width: 56, height: 68, child: CustomPaint(painter: CrestPainter())),
                ),
                const SizedBox(height: 10),
                Text('CalorieKnight', textAlign: TextAlign.center, style: Txt.logo().copyWith(fontSize: 30)),
                const SizedBox(height: 4),
                Text('Every meal you log is a swing of the sword.', textAlign: TextAlign.center, style: Txt.onStone(size: 15)),
                const SizedBox(height: 22),
                Stone(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: BoxDecoration(
                      color: Palette.parch,
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title, style: Txt.inkLabel(size: 22)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: Txt.body(size: 14, color: Palette.inkSoft)),
                        const SizedBox(height: 14),
                        ...children,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.auth});
  final AuthService auth;
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController(), _password = TextEditingController();
  String? _error;
  bool _working = false, _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.auth.signIn(_email.text, _password.text);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _useDemo() {
    _email.text = demoEmail;
    _password.text = demoPassword;
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
    title: 'Sign in',
    subtitle: 'Pick up your adventure where you left it.',
    children: [
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next,
        style: Txt.body(),
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _password,
        obscureText: _hide,
        autofillHints: const [AutofillHints.password],
        onSubmitted: (_) => _submit(),
        style: Txt.body(),
        decoration: InputDecoration(
          labelText: 'Password',
          suffixIcon: IconButton(
            tooltip: _hide ? 'Show password' : 'Hide password',
            icon: Icon(_hide ? Icons.visibility : Icons.visibility_off, color: Palette.inkSoft),
            onPressed: () => setState(() => _hide = !_hide),
          ),
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: Txt.body(size: 14, color: Palette.blood)),
        ),
      const SizedBox(height: 14),
      StoneButton(title: _working ? 'Signing in…' : 'Sign in', tone: ButtonTone.blood, onPressed: _working ? null : _submit),
      const SizedBox(height: 10),
      TextButton(
        onPressed: _working ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SignUpScreen(auth: widget.auth))),
        child: Text(
          'New here? Create an account',
          style: Txt.body(color: Palette.blood, weight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Palette.parchLine),
          borderRadius: BorderRadius.circular(2),
          color: const Color(0xFFE6D9B8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Testing build', style: Txt.inkLabel(size: 13, color: Palette.inkSoft)),
            const SizedBox(height: 2),
            SelectableText('Demo account: $demoEmail\nPassword: $demoPassword', style: Txt.body(size: 14)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _useDemo,
                child: Text(
                  'Fill in demo account',
                  style: Txt.body(size: 14, color: Palette.blood, weight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, required this.auth});
  final AuthService auth;
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _name = TextEditingController(), _email = TextEditingController(), _password = TextEditingController(), _confirm = TextEditingController();
  String? _error;
  bool _working = false, _agreed = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final problem = _name.text.trim().isEmpty
        ? 'Give your hero a name.'
        : validateEmail(_email.text) ??
              validatePassword(_password.text) ??
              (_password.text != _confirm.text
                  ? "The passwords don't match."
                  : !_agreed
                  ? 'Confirm you are 18 or over to play.'
                  : null);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.auth.signUp(knightName: _name.text, email: _email.text, password: _password.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
    title: 'Create an account',
    subtitle: 'Name your hero, then choose knight, mage or ranger.',
    children: [
      TextField(
        controller: _name,
        maxLength: 24,
        textInputAction: TextInputAction.next,
        style: Txt.body(),
        decoration: const InputDecoration(labelText: "Hero's name", hintText: 'e.g. Sir Galen'),
      ),
      const SizedBox(height: 4),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next,
        style: Txt.body(),
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _password,
        obscureText: true,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.next,
        style: Txt.body(),
        decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 8 characters'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _confirm,
        obscureText: true,
        onSubmitted: (_) => _submit(),
        style: Txt.body(),
        decoration: const InputDecoration(labelText: 'Confirm password'),
      ),
      CheckboxListTile(
        value: _agreed,
        onChanged: (v) => setState(() => _agreed = v ?? false),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: Palette.blood,
        dense: true,
        title: Text('I am 18 or over', style: Txt.body()),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_error!, style: Txt.body(size: 14, color: Palette.blood)),
        ),
      const SizedBox(height: 12),
      StoneButton(title: _working ? 'Creating account…' : 'Create account', tone: ButtonTone.blood, onPressed: _working ? null : _submit),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _working ? null : () => Navigator.of(context).pop(),
        child: Text(
          'Already have an account? Sign in',
          style: Txt.body(color: Palette.blood, weight: FontWeight.w700),
        ),
      ),
    ],
  );
}

/// The CalorieKnight crest (also used in the camp header).
class CrestPainter extends CustomPainter {
  const CrestPainter();
  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 28);
    Path shield(double i) => Path()
      ..moveTo(1 + i, 1 + i)
      ..lineTo(27 - i, 1 + i)
      ..lineTo(27 - i, 17)
      ..cubicTo(27 - i, 25 - i, 21, 30 - i, 14, 33 - i)
      ..cubicTo(7, 30 - i, 1 + i, 25 - i, 1 + i, 17)
      ..close();
    c.drawPath(shield(0), Paint()..color = Palette.amber);
    c.drawPath(
      shield(0),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.black,
    );
    c.drawPath(shield(3), Paint()..color = const Color(0xFF8E2117));
    final cross = Paint()..color = Palette.cream;
    c.drawRect(const Rect.fromLTWH(13, 7, 2, 20), cross);
    c.drawRect(const Rect.fromLTWH(9, 19, 10, 2), cross);
  }

  @override
  bool shouldRepaint(CrestPainter old) => false;
}
