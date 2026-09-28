import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/security/biometric_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/aegis_logo.dart';

enum PinAuthMode {
  setup,
  verify,
}

class PinAuthScreen extends StatefulWidget {
  final PinAuthMode mode;
  final String? reason;
  final VoidCallback? onUnlocked;
  final bool isDismissible;

  const PinAuthScreen({
    super.key,
    required this.mode,
    this.reason,
    this.onUnlocked,
    this.isDismissible = false,
  });

  static Future<bool> setup(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PinAuthScreen(
          mode: PinAuthMode.setup,
          isDismissible: true,
        ),
      ),
    );
    return result ?? false;
  }

  static Future<bool> verify(BuildContext context, {String? reason}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PinAuthScreen(
          mode: PinAuthMode.verify,
          reason: reason,
          isDismissible: true,
        ),
      ),
    );
    return result ?? false;
  }

  @override
  State<PinAuthScreen> createState() => _PinAuthScreenState();
}

class _PinAuthScreenState extends State<PinAuthScreen>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String _firstPin = '';
  int _step = 0; // 0: enter new, 1: confirm (for setup mode)
  String? _errorMessage;
  bool _isProcessing = false;
  bool _biometricAvailable = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));

    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await BiometricService().isBiometricsAvailable();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_isProcessing || _enteredPin.length >= 6) return;
    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 6) {
      _handleCompletePin();
    }
  }

  void _onBackspace() {
    if (_isProcessing || _enteredPin.isEmpty) return;
    setState(() {
      _errorMessage = null;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _onClear() {
    if (_isProcessing) return;
    setState(() {
      _errorMessage = null;
      _enteredPin = '';
    });
  }

  Future<void> _handleCompletePin() async {
    final settings = context.read<SettingsProvider>();
    final isIndo = settings.isIndonesian;

    if (widget.mode == PinAuthMode.setup) {
      if (_step == 0) {
        setState(() {
          _firstPin = _enteredPin;
          _enteredPin = '';
          _step = 1;
        });
      } else {
        // Confirmation step
        if (_enteredPin == _firstPin) {
          setState(() => _isProcessing = true);
          await settings.setAppPin(_enteredPin);
          await settings.setBiometricLock(true);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isIndo
                      ? '✅ PIN Keamanan 6-Digit Berhasil Diaktifkan!'
                      : '✅ 6-Digit Security PIN Successfully Set!',
                ),
                backgroundColor: AppColors.success,
              ),
            );

            if (widget.onUnlocked != null) {
              widget.onUnlocked!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            }
          }
        } else {
          // Mismatch
          _triggerShake();
          setState(() {
            _errorMessage = isIndo
                ? 'PIN tidak cocok. Silakan ulangi pembuatan PIN.'
                : 'PINs do not match. Please restart PIN setup.';
            _enteredPin = '';
            _firstPin = '';
            _step = 0;
          });
        }
      }
    } else {
      // Verify mode
      setState(() => _isProcessing = true);
      final isCorrect = await settings.verifyAppPin(_enteredPin);

      if (isCorrect) {
        if (mounted) {
          if (widget.onUnlocked != null) {
            widget.onUnlocked!();
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          }
        }
      } else {
        if (mounted) {
          _triggerShake();
          setState(() {
            _isProcessing = false;
            _enteredPin = '';
            _errorMessage = isIndo
                ? 'PIN salah. Akses ditolak!'
                : 'Incorrect PIN. Access denied!';
          });
        }
      }
    }
  }

  void _triggerShake() {
    _shakeController.forward(from: 0.0);
    HapticFeedback.heavyImpact();
  }

  Future<void> _triggerBiometric() async {
    if (!_biometricAvailable) return;
    final settings = context.read<SettingsProvider>();
    final isIndo = settings.isIndonesian;

    final success = await BiometricService().authenticate(
      context: context,
      reason: widget.reason ??
          (isIndo
              ? 'Verifikasi biometrik untuk membuka konsol AEGIS'
              : 'Biometric authorization required to unlock AEGIS console'),
    );

    if (mounted && success) {
      if (widget.onUnlocked != null) {
        widget.onUnlocked!();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.backspace) {
        _onBackspace();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        _onClear();
        return KeyEventResult.handled;
      }
      final char = event.character;
      if (char != null && RegExp(r'^[0-9]$').hasMatch(char)) {
        _onDigitPressed(char);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final settings = context.watch<SettingsProvider>();
    final isIndo = settings.isIndonesian;

    final String title;
    final String subtitle;

    if (widget.mode == PinAuthMode.setup) {
      if (_step == 0) {
        title = isIndo ? 'BUAT PIN KEAMANAN' : 'SET UP SECURITY PIN';
        subtitle = isIndo
            ? 'Masukkan 6 digit angka untuk mengamankan konsol AEGIS'
            : 'Enter 6 digits to secure AEGIS console';
      } else {
        title = isIndo ? 'KONFIRMASI PIN' : 'CONFIRM PIN';
        subtitle = isIndo
            ? 'Ketik ulang 6 digit PIN Anda untuk verifikasi'
            : 'Re-enter your 6-digit PIN to verify';
      }
    } else {
      title = isIndo ? 'KONSOL TERKUNCI' : 'CONSOLE LOCKED';
      subtitle = widget.reason ??
          (isIndo
              ? 'Masukkan 6 digit PIN untuk membuka konsol pertahanan'
              : 'Enter 6-digit PIN to unlock defense console');
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: widget.isDismissible
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(false),
                tooltip: isIndo ? 'Tutup' : 'Close',
              ),
            )
          : null,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Logo / Icon
                    if (widget.mode == PinAuthMode.verify) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: const AegisLogo(
                          size: 48,
                          showGlow: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.pin_rounded,
                          size: 42,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Title
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Operator Badge (for verify mode)
                    if (widget.mode == PinAuthMode.verify) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded, size: 13, color: theme.colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              settings.operatorName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Subtitle
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 6 Animated PIN Indicator Dots with Shake on error
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          final isFilled = index < _enteredPin.length;
                          final isError = _errorMessage != null;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFilled
                                  ? (isError ? AppColors.danger : theme.colorScheme.primary)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isError
                                    ? AppColors.danger
                                    : (isFilled
                                        ? theme.colorScheme.primary
                                        : (isDark
                                            ? AppColors.darkBorderLight
                                            : AppColors.lightBorderLight)),
                                width: 2,
                              ),
                              boxShadow: isFilled
                                  ? [
                                      BoxShadow(
                                        color: (isError ? AppColors.danger : theme.colorScheme.primary)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Error Message
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: _errorMessage != null ? 24 : 0,
                      child: _errorMessage != null
                          ? Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 20),

                    // Cyber Numeric Keypad
                    _buildKeypad(theme, isDark, isIndo),

                    if (widget.mode == PinAuthMode.setup && widget.isDismissible) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          isIndo ? 'BATAL' : 'CANCEL',
                          style: TextStyle(
                            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(ThemeData theme, bool isDark, bool isIndo) {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3'], theme, isDark),
        const SizedBox(height: 14),
        _buildKeypadRow(['4', '5', '6'], theme, isDark),
        const SizedBox(height: 14),
        _buildKeypadRow(['7', '8', '9'], theme, isDark),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Left Action Button
            if (_biometricAvailable && widget.mode == PinAuthMode.verify)
              _buildActionButton(
                icon: Icons.fingerprint_rounded,
                color: theme.colorScheme.primary,
                tooltip: isIndo ? 'Gunakan Sidik Jari' : 'Use Fingerprint',
                onPressed: _triggerBiometric,
                theme: theme,
                isDark: isDark,
              )
            else if (_enteredPin.isNotEmpty)
              _buildActionButton(
                label: 'C',
                color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                tooltip: isIndo ? 'Hapus Semua' : 'Clear All',
                onPressed: _onClear,
                theme: theme,
                isDark: isDark,
              )
            else
              const SizedBox(width: 68, height: 68),

            // Digit '0'
            _buildKeypadButton('0', theme, isDark),

            // Right Action Button: Backspace
            _buildActionButton(
              icon: Icons.backspace_outlined,
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              tooltip: isIndo ? 'Hapus' : 'Backspace',
              onPressed: _onBackspace,
              theme: theme,
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> digits, ThemeData theme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeypadButton(d, theme, isDark)).toList(),
    );
  }

  Widget _buildKeypadButton(String digit, ThemeData theme, bool isDark) {
    return InkWell(
      onTap: () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF141C2E) : const Color(0xFFF1F5F9),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    IconData? icon,
    String? label,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 68,
          height: 68,
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, color: color, size: 26)
              : Text(
                  label!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
        ),
      ),
    );
  }
}
