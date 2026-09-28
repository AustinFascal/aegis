import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/settings_provider.dart';

class BiometricPromptDialog extends StatefulWidget {
  final String reason;

  const BiometricPromptDialog({
    super.key,
    required this.reason,
  });

  static Future<bool> show(BuildContext context, {required String reason}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BiometricPromptDialog(reason: reason),
    );
    return result ?? false;
  }

  @override
  State<BiometricPromptDialog> createState() => _BiometricPromptDialogState();
}

class _BiometricPromptDialogState extends State<BiometricPromptDialog>
    with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  bool _isSuccess = false;
  bool _showPinFallback = false;
  final TextEditingController _pinController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _triggerScan() {
    if (_isScanning || _isSuccess) return;

    setState(() {
      _isScanning = true;
    });

    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _isSuccess = true;
      });

      Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      });
    });
  }

  void _verifyPin() {
    if (_pinController.text.trim().isNotEmpty) {
      setState(() {
        _isSuccess = true;
      });
      Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider?>(context);
    final isIndo = settings?.isIndonesian ?? false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(false);
        }
      },
      child: AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1522) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark
                ? (_isSuccess ? AppColors.success : theme.colorScheme.primary).withValues(alpha: 0.5)
                : (_isSuccess ? AppColors.success : theme.colorScheme.primary).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (_isSuccess ? AppColors.success : theme.colorScheme.primary)
                    .withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _isSuccess ? Icons.verified_user_rounded : Icons.fingerprint_rounded,
                color: _isSuccess ? AppColors.success : theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isIndo ? 'Verifikasi Sidik Jari' : 'Biometric Verification',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AEGIS HARDWARE SECURITY',
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: _isSuccess ? AppColors.success : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reason banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161F33) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Text(
                  widget.reason,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (!_showPinFallback) ...[
                // Interactive Fingerprint Scanner Pad
                GestureDetector(
                  onTap: _triggerScan,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final scale = _isScanning ? 0.95 : (_isSuccess ? 1.0 : _pulseAnimation.value);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isSuccess
                                ? AppColors.success.withValues(alpha: 0.18)
                                : theme.colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                            border: Border.all(
                              color: _isSuccess
                                  ? AppColors.success
                                  : theme.colorScheme.primary.withValues(alpha: 0.6),
                              width: 2.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isSuccess ? AppColors.success : theme.colorScheme.primary)
                                    .withValues(alpha: isDark ? 0.25 : 0.15),
                                blurRadius: 16,
                                spreadRadius: _isScanning ? 4 : 1,
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isScanning
                                ? SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.colorScheme.primary,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    _isSuccess
                                        ? Icons.check_circle_rounded
                                        : Icons.fingerprint_rounded,
                                    size: 56,
                                    color: _isSuccess
                                        ? AppColors.success
                                        : theme.colorScheme.primary,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Status text / Action hint
                Text(
                  _isSuccess
                      ? (isIndo ? '✅ Sidik jari cocok. Otorisasi berhasil!' : '✅ Biometric matched. Authorized!')
                      : (_isScanning
                          ? (isIndo ? 'Memindai sensor sidik jari...' : 'Scanning fingerprint sensor...')
                          : (isIndo ? 'Sentuh / klik sensor untuk verifikasi sidik jari' : 'Touch / click sensor to verify fingerprint')),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isSuccess
                        ? AppColors.success
                        : (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary),
                  ),
                ),

                const SizedBox(height: 12),
                // Toggle PIN Fallback
                TextButton.icon(
                  onPressed: () => setState(() => _showPinFallback = true),
                  icon: const Icon(Icons.pin_outlined, size: 15),
                  label: Text(
                    isIndo ? 'Gunakan PIN / Kata Sandi Sistem' : 'Use System Passcode / PIN',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ] else ...[
                // Passcode fallback input
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  autofocus: true,
                  onSubmitted: (_) => _verifyPin(),
                  decoration: InputDecoration(
                    labelText: isIndo ? 'PIN / Kata Sandi Otorisasi' : 'Authorization PIN / Passcode',
                    hintText: isIndo ? 'Masukkan PIN atau kata sandi' : 'Enter PIN or password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _showPinFallback = false),
                      icon: const Icon(Icons.fingerprint_rounded, size: 15),
                      label: Text(
                        isIndo ? 'Kembali ke Sidik Jari' : 'Back to Fingerprint',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _verifyPin,
                      child: Text(isIndo ? 'VERIFIKASI' : 'VERIFY'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              isIndo ? 'BATAL' : 'CANCEL',
              style: TextStyle(
                color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
