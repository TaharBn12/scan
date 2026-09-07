import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../shop/data/repositories/shop_repository_impl.dart';

/// Full-screen PIN pad shown when the app is locked (single PIN) or when a
/// cashier must sign in (multi-user). Also used as a reusable PIN prompt
/// via [PinPad].
class LockPage extends StatefulWidget {
  const LockPage({super.key});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  String _pin = '';
  bool _error = false;
  int _failures = 0;

  Future<void> _submit() async {
    if (_pin.length < 4) return;
    final ok = await sessionController.unlockWithPin(_pin);
    if (!mounted) return;
    if (ok) {
      // The router redirect sends us to the right place.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/menu');
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _pin = '';
        _failures++;
      });
      // Small back-off after repeated failures.
      if (_failures >= 5) {
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) setState(() => _failures = 0);
      }
    }
  }

  void _tap(String digit) {
    if (_pin.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = false;
      _pin += digit;
    });
    if (_pin.length == 6) _submit();
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final multi = sessionController.isMultiUser;
    final shop = ShopRepositoryImpl.current();
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.primaryColor, Color(0xFF3F37B5)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(),
                const Icon(Icons.lock_outline, color: Colors.white, size: 44),
                const SizedBox(height: 12),
                Text(
                  shop.name.isEmpty ? l10n.appTitle : shop.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  multi ? l10n.t('who_is_working') : l10n.t('enter_pin'),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15),
                ),
                const SizedBox(height: 28),
                _Dots(count: _pin.length, error: _error),
                const SizedBox(height: 10),
                SizedBox(
                  height: 22,
                  child: _error
                      ? Text(l10n.t('wrong_pin'),
                          style: const TextStyle(
                              color: Color(0xFFFFB4AB),
                              fontWeight: FontWeight.w600))
                      : null,
                ),
                const Spacer(),
                PinPad(
                  onDigit: _tap,
                  onBackspace: _backspace,
                  onSubmit: _submit,
                  enabled: _failures < 5,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final bool error;
  const _Dots({required this.count, required this.error});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final filled = i < count;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? (error ? const Color(0xFFFFB4AB) : Colors.white)
                : Colors.white.withValues(alpha: 0.25),
          ),
        );
      }),
    );
  }
}

/// Numeric keypad used by the lock screen and PIN dialogs.
class PinPad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final bool enabled;
  final Color? keyColor;
  final Color? textColor;

  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    this.enabled = true,
    this.keyColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? Colors.white;
    final bg = keyColor ?? Colors.white.withValues(alpha: 0.12);
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? (onTap ?? () => onDigit(label)) : null,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: fg, size: 26)
                    : Text(label,
                        style: TextStyle(
                            color: fg,
                            fontSize: 26,
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [for (final d in row) key(d)],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              key('', icon: Icons.backspace_outlined, onTap: onBackspace),
              key('0'),
              key('', icon: Icons.check, onTap: onSubmit),
            ],
          ),
        ],
      ),
    );
  }
}
