import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'legal_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  bool _agreed = false;

  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _openLegal(orbitTermsDoc);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openLegal(orbitPrivacyDoc);
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _openLegal(LegalDoc doc) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => LegalScreen(doc: doc)));
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await context.read<AppState>().signInWithGoogle();
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [OrbitColors.primary, Color(0xFF7C8CF8)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 3),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      'assets/brand/orbit_logo.png',
                      width: 116,
                      height: 116,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Orbit',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Find spontaneous hangouts\nhappening around you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const Spacer(flex: 4),
                _ConsentRow(
                  agreed: _agreed,
                  busy: _busy,
                  onChanged: (v) => setState(() => _agreed = v),
                  termsRecognizer: _termsRecognizer,
                  privacyRecognizer: _privacyRecognizer,
                ),
                const SizedBox(height: 16),
                _GoogleButton(
                  busy: _busy,
                  onTap: (_busy || !_agreed) ? null : _signIn,
                ),
                const SizedBox(height: 12),
                if (!Config.hasGoogleClientId && !Config.devAuthEnabled)
                  Text(
                    'Dev note: set ORBIT_GOOGLE_CLIENT_ID to enable sign-in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  final bool agreed;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final TapGestureRecognizer termsRecognizer;
  final TapGestureRecognizer privacyRecognizer;
  const _ConsentRow({
    required this.agreed,
    required this.busy,
    required this.onChanged,
    required this.termsRecognizer,
    required this.privacyRecognizer,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: agreed,
            onChanged: busy ? null : (v) => onChanged(v ?? false),
            side: const BorderSide(color: Colors.white, width: 2),
            fillColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white
                  : Colors.transparent,
            ),
            checkColor: OrbitColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
                children: [
                  const TextSpan(text: "I agree to Orbit's "),
                  TextSpan(
                    text: 'Terms of Use',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: termsRecognizer,
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: privacyRecognizer,
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onTap;
  const _GoogleButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: context.cInk,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: OrbitColors.primary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleGlyph(),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          colors: [Color(0xFF4285F4), Color(0xFF34A853)],
        ),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}
