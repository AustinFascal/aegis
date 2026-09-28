import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/aegis_logo.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isReplay;
  const OnboardingScreen({super.key, this.isReplay = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onSkip(SettingsProvider settings) async {
    if (widget.isReplay) {
      Navigator.of(context).pop();
      return;
    }
    await settings.skipOnboarding();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _onSaveAndStart(SettingsProvider settings) async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.isReplay) {
      await settings.updateProfile(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }

    await settings.completeOnboarding(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
    );
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final isIndo = settings.isIndonesian;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isReplay
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AegisLogo(size: 24, showGlow: false),
            const SizedBox(width: 8),
            Text(
              'AEGIS',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          // Language toggle
          TextButton.icon(
            onPressed: () {
              settings.setLanguage(isIndo ? 'en' : 'id');
            },
            icon: const Icon(Icons.language_rounded, size: 16),
            label: Text(
              isIndo ? 'EN' : 'ID',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          // Skip Button
          TextButton(
            onPressed: () => _onSkip(settings),
            child: Text(
              widget.isReplay
                  ? (isIndo ? 'TUTUP' : 'CLOSE')
                  : (isIndo ? 'LEWATI' : 'SKIP'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Page Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildWelcomeSlide(context, settings, isDark, isIndo),
                  _buildPentestSlide(context, settings, isDark, isIndo),
                  _buildProfileSetupSlide(context, settings, isDark, isIndo),
                ],
              ),
            ),

            // Bottom Navigation & Progress Indicator
            _buildBottomControls(context, settings, isDark, isIndo),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSlide(
      BuildContext context, SettingsProvider settings, bool isDark, bool isIndo) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              const AegisLogo(size: 88, showGlow: true),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'INFRASTRUCTURE SECURITY SENTINEL',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isIndo ? 'Pertahanan Server Real-Time' : 'Real-Time Server Defense',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isIndo
                    ? 'Sistem pemantauan keamanan server cerdas dengan audit forensik zero-trust & perlindungan hardware vault lokal.'
                    : 'Intelligent server security sentinel with zero-trust forensic audits & local hardware vault protection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Key feature cards
              _buildFeatureTile(
                context,
                icon: Icons.radar_rounded,
                title: isIndo ? 'Telemetri Servis Real-Time' : 'Real-Time Service Telemetry',
                desc: isIndo
                    ? 'Pantau OpenSSH, NGINX, MySQL, Redis, Docker & PostgreSQL secara langsung.'
                    : 'Monitor OpenSSH, NGINX, MySQL, Redis, Docker & PostgreSQL live.',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildFeatureTile(
                context,
                icon: Icons.shield_rounded,
                title: isIndo ? 'Deteksi & Mitigasi Otomatis' : 'Auto Detection & Mitigation',
                desc: isIndo
                    ? 'Identifikasi brute-force seketika dan isolasi IP penyerang dengan satu ketukan.'
                    : 'Instantly identify brute-force attacks and isolate malicious IPs in one tap.',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildFeatureTile(
                context,
                icon: Icons.lock_outline_rounded,
                title: isIndo ? 'Enkripsi Vault AES-256' : 'AES-256 Encrypted Vault',
                desc: isIndo
                    ? 'Kredensial SSH & kebijakan tersimpan aman di hardware perangkat Anda.'
                    : 'SSH credentials & policies stay strictly on your local device vault.',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPentestSlide(
      BuildContext context, SettingsProvider settings, bool isDark, bool isIndo) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.science_rounded,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'PENETRATION TESTING LAB',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isIndo ? 'Simulasi Serangan Terisolasi' : 'Isolated Threat Simulations',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isIndo
                    ? 'Uji respons sistem peringatan dini tanpa risiko terhadap IP fisik atau jaringan perangkat operator.'
                    : 'Verify your alert engine and mitigation pipelines safely without risking your physical device IP.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              _buildFeatureTile(
                context,
                icon: Icons.public_off_rounded,
                title: isIndo ? 'Isolasi IP Perangkat 100%' : '100% Device IP Isolation',
                desc: isIndo
                    ? 'Simulasi hanya menggunakan IP threat actor yang dipilih. IP fisik Anda tidak akan pernah diblokir.'
                    : 'Simulations strictly use selected threat actor IPs. Your physical IP is never banned.',
                isDark: isDark,
                accentColor: AppColors.primary,
              ),
              const SizedBox(height: 10),
              _buildFeatureTile(
                context,
                icon: Icons.terminal_rounded,
                title: isIndo ? '21+ Profil Ancaman Global' : '21+ Global Threat Profiles',
                desc: isIndo
                    ? 'Uji SSH brute-force, MySQL credential stuffing, probe NGINX, dan Redis injection.'
                    : 'Test SSH brute-force, MySQL credential stuffing, NGINX probes, and Redis injection.',
                isDark: isDark,
                accentColor: AppColors.primary,
              ),
              const SizedBox(height: 10),
              _buildFeatureTile(
                context,
                icon: Icons.fingerprint_rounded,
                title: isIndo ? 'Verifikasi Sidik Jari Asli' : 'Native Device Fingerprint',
                desc: isIndo
                    ? 'Aksi kritis dilindungi sensor biometrik default bawaan perangkat Anda.'
                    : 'Critical actions protected by your device default biometric fingerprint reader.',
                isDark: isDark,
                accentColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSetupSlide(
      BuildContext context, SettingsProvider settings, bool isDark, bool isIndo) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.badge_outlined,
                        size: 36,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isIndo ? 'Setup Profil Operator' : 'Operator Profile Setup',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isIndo
                      ? 'Lengkapi informasi dasar Anda untuk identitas lokal. Hanya memerlukan Nama, Email, dan Nomor Telepon.'
                      : 'Provide basic identity details for local audit trails. Only requires Name, Email, and Phone Number.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),

                // Guest Info Notice Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141E33) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isIndo
                              ? 'Anda dapat melewati langkah ini. Jika dilewati, akun akan otomatis diatur sebagai Guest User di Pengaturan.'
                              : 'You can skip this step. If skipped, you will appear as Guest User in Settings.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Operator Full Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: isIndo ? 'Nama Lengkap Operator' : 'Operator Full Name',
                    hintText: isIndo ? 'contoh: Austin Fascal' : 'e.g. Austin Fascal',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return isIndo ? 'Nama wajib diisi' : 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: isIndo ? 'Alamat Email' : 'Email Address',
                    hintText: isIndo ? 'contoh: operator@cethokaryo.id' : 'e.g. operator@cethokaryo.id',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty && !v.contains('@')) {
                      return isIndo ? 'Format email tidak valid' : 'Invalid email format';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Phone Field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: isIndo ? 'Nomor Telepon' : 'Phone Number',
                    hintText: isIndo ? 'contoh: +62 812-3456-7890' : 'e.g. +62 812-3456-7890',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons on Profile Setup
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _onSkip(settings),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          isIndo ? 'LEWATI (TAMU)' : 'SKIP AS GUEST',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _onSaveAndStart(settings),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          widget.isReplay
                              ? (isIndo ? 'SIMPAN PROFIL' : 'SAVE PROFILE')
                              : (isIndo ? 'SIMPAN & MULAI' : 'SAVE & LAUNCH'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildFeatureTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
    Color? accentColor,
  }) {
    final theme = Theme.of(context);
    final color = accentColor ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(
      BuildContext context, SettingsProvider settings, bool isDark, bool isIndo) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button or placeholder
          if (_currentPage > 0)
            TextButton.icon(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(
                isIndo ? 'KEMBALI' : 'BACK',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            )
          else
            const SizedBox(width: 70),

          // Dots Indicator
          Row(
            children: List.generate(3, (index) {
              final isCurrent = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isCurrent ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          // Next button on page 0 & 1, or spacer on page 2
          if (_currentPage < 2)
            ElevatedButton(
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isIndo ? 'LANJUTKAN' : 'NEXT',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            )
          else
            const SizedBox(width: 70),
        ],
      ),
    );
  }
}
