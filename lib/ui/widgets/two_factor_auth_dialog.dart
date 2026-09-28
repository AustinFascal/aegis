import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../../core/constants/app_colors.dart";
import "../../providers/settings_provider.dart";
import "package:provider/provider.dart";

/// A dedicated dialog that prompts the user to enter their 2FA / OTP verification code
/// when an SSH session requires keyboard-interactive authentication (e.g. Google Authenticator / Duo).
class TwoFactorAuthDialog extends StatefulWidget {
  final String username;
  final String serverName;
  final String? promptText;

  const TwoFactorAuthDialog({
    super.key,
    required this.username,
    required this.serverName,
    this.promptText,
  });

  /// Displays the dialog and returns the entered 6-8 digit verification code,
  /// or null if the user cancelled.
  static Future<String?> show(
    BuildContext context, {
    required String username,
    required String serverName,
    String? promptText,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TwoFactorAuthDialog(
        username: username,
        serverName: serverName,
        promptText: promptText,
      ),
    );
  }

  @override
  State<TwoFactorAuthDialog> createState() => _TwoFactorAuthDialogState();
}

class _TwoFactorAuthDialogState extends State<TwoFactorAuthDialog> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _codeController.text.trim();
    if (code.isNotEmpty) {
      Navigator.of(context).pop(code);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? "";
    final digits = text.replaceAll(RegExp(r"[^0-9]"), "");
    if (digits.isNotEmpty) {
      setState(() {
        _codeController.text = digits;
      });
      if (digits.length >= 6) {
        _submit();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    SettingsProvider? settings;
    try {
      settings = context.watch<SettingsProvider>();
    } catch (_) {}
    final isIndo = settings?.isIndonesian ?? true;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: (isDark ? AppColors.primary : AppColors.primaryLight).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Icon & Badge
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isDark ? AppColors.primary : AppColors.primaryLight).withValues(alpha: 0.15),
                      border: Border.all(
                        color: (isDark ? AppColors.primary : AppColors.primaryLight).withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.phonelink_lock_rounded,
                      size: 32,
                      color: isDark ? AppColors.primary : AppColors.primaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  isIndo ? "Verifikasi 2FA Diperlukan" : "2FA Verification Required",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  isIndo ? "Server meminta kode verifikasi untuk pengguna ${widget.username} di ${widget.serverName}." : "Server requests verification code for ${widget.username} on ${widget.serverName}.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  ),
                ),

                if (widget.promptText != null && widget.promptText!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Text(
                      widget.promptText!.trim(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: "monospace",
                        fontSize: 11,
                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Verification Code Input
                TextFormField(
                  controller: _codeController,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "monospace",
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: isDark ? AppColors.primary : AppColors.primaryLight,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: InputDecoration(
                    hintText: "000000",
                    hintStyle: TextStyle(
                      fontFamily: "monospace",
                      fontSize: 24,
                      letterSpacing: 6,
                      color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                    ),
                    prefixIcon: const Icon(Icons.pin_rounded),
                    suffixIcon: IconButton(
                      tooltip: isIndo ? "Tempel dari clipboard" : "Paste from clipboard",
                      icon: const Icon(Icons.content_paste_rounded, size: 20),
                      onPressed: _pasteFromClipboard,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) {
                    final clean = v?.trim() ?? "";
                    if (clean.isEmpty) {
                      return isIndo ? "Masukkan kode verifikasi" : "Enter verification code";
                    }
                    if (clean.length < 6) {
                      return isIndo ? "Kode harus minimal 6 digit" : "Code must be at least 6 digits";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isIndo ? "Buka Google Authenticator / aplikasi 2FA di HP Anda." : "Open Google Authenticator or 2FA app on your device.",
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(isIndo ? "BATAL" : "CANCEL"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _submit();
                          }
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(isIndo ? "VERIFIKASI" : "VERIFY"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
