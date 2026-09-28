import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../../core/constants/app_colors.dart';
import '../../models/server_profile.dart';
import '../../providers/server_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/ssh_service.dart';
import '../widgets/two_factor_auth_dialog.dart';

enum TerminalConnectionState {
  connecting,
  connected,
  disconnected,
  error,
}

enum AegisTerminalThemeType {
  cyberOled,
  matrixGreen,
  monokaiPro,
  nordGlacier,
}

class AegisTerminalThemes {
  static const TerminalTheme cyberOled = TerminalTheme(
    cursor: Color(0xFF00E5FF),
    selection: Color(0x5500E5FF),
    foreground: Color(0xFFE2E8F0),
    background: Color(0xFF050811),
    black: Color(0xFF1E293B),
    red: Color(0xFFFF3366),
    green: Color(0xFF00FF9D),
    yellow: Color(0xFFFFD600),
    blue: Color(0xFF00B0FF),
    magenta: Color(0xFFD946EF),
    cyan: Color(0xFF00E5FF),
    white: Color(0xFFE2E8F0),
    brightBlack: Color(0xFF475569),
    brightRed: Color(0xFFFF6B8B),
    brightGreen: Color(0xFF5CFFBA),
    brightYellow: Color(0xFFFFE55C),
    brightBlue: Color(0xFF40C4FF),
    brightMagenta: Color(0xFFF472B6),
    brightCyan: Color(0xFF80F0FF),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0x8800E5FF),
    searchHitBackgroundCurrent: Color(0xCC00FF9D),
    searchHitForeground: Color(0xFF000000),
  );

  static const TerminalTheme matrixGreen = TerminalTheme(
    cursor: Color(0xFF4ADE80),
    selection: Color(0x5522C55E),
    foreground: Color(0xFF22C55E),
    background: Color(0xFF030A05),
    black: Color(0xFF0D1F12),
    red: Color(0xFFEF4444),
    green: Color(0xFF16A34A),
    yellow: Color(0xFFEAB308),
    blue: Color(0xFF0EA5E9),
    magenta: Color(0xFF10B981),
    cyan: Color(0xFF059669),
    white: Color(0xFF86EFAC),
    brightBlack: Color(0xFF1B4324),
    brightRed: Color(0xFFF87171),
    brightGreen: Color(0xFF4ADE80),
    brightYellow: Color(0xFFFACC15),
    brightBlue: Color(0xFF38BDF8),
    brightMagenta: Color(0xFF34D399),
    brightCyan: Color(0xFF10B981),
    brightWhite: Color(0xFFDCFCE7),
    searchHitBackground: Color(0x8816A34A),
    searchHitBackgroundCurrent: Color(0xCC4ADE80),
    searchHitForeground: Color(0xFF000000),
  );

  static const TerminalTheme monokaiPro = TerminalTheme(
    cursor: Color(0xFFFFD866),
    selection: Color(0x55FFD866),
    foreground: Color(0xFFFCFCFA),
    background: Color(0xFF2D2A2E),
    black: Color(0xFF19181A),
    red: Color(0xFFFF6188),
    green: Color(0xFFA9DC76),
    yellow: Color(0xFFFFD866),
    blue: Color(0xFF78DCE8),
    magenta: Color(0xFFAB9DF2),
    cyan: Color(0xFF78DCE8),
    white: Color(0xFFFCFCFA),
    brightBlack: Color(0xFF727072),
    brightRed: Color(0xFFFF6188),
    brightGreen: Color(0xFFA9DC76),
    brightYellow: Color(0xFFFFD866),
    brightBlue: Color(0xFF78DCE8),
    brightMagenta: Color(0xFFAB9DF2),
    brightCyan: Color(0xFF78DCE8),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0x88FFD866),
    searchHitBackgroundCurrent: Color(0xCCA9DC76),
    searchHitForeground: Color(0xFF000000),
  );

  static const TerminalTheme nordGlacier = TerminalTheme(
    cursor: Color(0xFF88C0D0),
    selection: Color(0x5588C0D0),
    foreground: Color(0xFFECEFF4),
    background: Color(0xFF2E3440),
    black: Color(0xFF3B4252),
    red: Color(0xFFBF616A),
    green: Color(0xFFA3BE8C),
    yellow: Color(0xFFEBCB8B),
    blue: Color(0xFF81A1C1),
    magenta: Color(0xFFB48EAD),
    cyan: Color(0xFF88C0D0),
    white: Color(0xFFE5E9F0),
    brightBlack: Color(0xFF4C566A),
    brightRed: Color(0xFFBF616A),
    brightGreen: Color(0xFFA3BE8C),
    brightYellow: Color(0xFFEBCB8B),
    brightBlue: Color(0xFF81A1C1),
    brightMagenta: Color(0xFFB48EAD),
    brightCyan: Color(0xFF8FBCBB),
    brightWhite: Color(0xFFECEFF4),
    searchHitBackground: Color(0x8888C0D0),
    searchHitBackgroundCurrent: Color(0xCCA3BE8C),
    searchHitForeground: Color(0xFF000000),
  );

  static TerminalTheme getTheme(AegisTerminalThemeType type) {
    switch (type) {
      case AegisTerminalThemeType.cyberOled:
        return cyberOled;
      case AegisTerminalThemeType.matrixGreen:
        return matrixGreen;
      case AegisTerminalThemeType.monokaiPro:
        return monokaiPro;
      case AegisTerminalThemeType.nordGlacier:
        return nordGlacier;
    }
  }

  static Color getThemeBackgroundColor(AegisTerminalThemeType type) {
    return getTheme(type).background;
  }

  static String getThemeName(AegisTerminalThemeType type) {
    switch (type) {
      case AegisTerminalThemeType.cyberOled:
        return 'Cyber OLED';
      case AegisTerminalThemeType.matrixGreen:
        return 'Matrix Green';
      case AegisTerminalThemeType.monokaiPro:
        return 'Monokai Pro';
      case AegisTerminalThemeType.nordGlacier:
        return 'Nord Glacier';
    }
  }

  static Color getThemePreviewColor(AegisTerminalThemeType type) {
    switch (type) {
      case AegisTerminalThemeType.cyberOled:
        return const Color(0xFF00E5FF);
      case AegisTerminalThemeType.matrixGreen:
        return const Color(0xFF22C55E);
      case AegisTerminalThemeType.monokaiPro:
        return const Color(0xFFFFD866);
      case AegisTerminalThemeType.nordGlacier:
        return const Color(0xFF88C0D0);
    }
  }

  static String getThemeDescription(AegisTerminalThemeType type, bool isIndo) {
    switch (type) {
      case AegisTerminalThemeType.cyberOled:
        return isIndo ? 'OLED Hitam Pekat & Neon Sian' : 'Deep OLED Black & Neon Cyan';
      case AegisTerminalThemeType.matrixGreen:
        return isIndo ? 'Retro Phosphor CRT Hijau' : 'Retro Green Phosphor CRT';
      case AegisTerminalThemeType.monokaiPro:
        return isIndo ? 'Palet Warna Lembut Developer' : 'Warm Developer Pastel Palette';
      case AegisTerminalThemeType.nordGlacier:
        return isIndo ? 'Arktik Dingin & Biru Lembut' : 'Arctic Slate & Calm Blues';
    }
  }
}

class TerminalScreen extends StatefulWidget {
  final ServerProfile server;

  const TerminalScreen({
    super.key,
    required this.server,
  });

  @override
  State<TerminalScreen> createState() => TerminalScreenState();
}

class TerminalScreenState extends State<TerminalScreen> {
  final SshService _sshService = SshService();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final FocusNode _terminalFocusNode = FocusNode();
  final TerminalController _terminalController = TerminalController();

  late final Terminal _terminal;
  Terminal get terminal => _terminal;

  SSHClient? _client;
  SSHSession? _shellSession;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  TerminalConnectionState _connectionState = TerminalConnectionState.connecting;
  String? _errorMessage;
  final List<String> _commandHistory = [];
  int _historyIndex = -1;

  double _fontSize = 13.0;
  AegisTerminalThemeType _themeType = AegisTerminalThemeType.cyberOled;
  bool _isFullscreen = false;
  bool _showNodeBanner = true;

  // Quick command shortcuts for rapid SecOps & DevOps diagnostics
  static const List<Map<String, String>> _quickCommands = [
    {'label': 'htop', 'cmd': 'htop'},
    {'label': 'aegis status', 'cmd': 'systemctl status aegis-agent --no-pager'},
    {'label': 'fail2ban', 'cmd': 'sudo fail2ban-client status'},
    {'label': 'auth log', 'cmd': 'sudo tail -n 25 /var/log/secure 2>/dev/null || sudo tail -n 25 /var/log/auth.log'},
    {'label': 'uptime', 'cmd': 'uptime'},
    {'label': 'disk (df)', 'cmd': 'df -h'},
    {'label': 'memory (free)', 'cmd': 'free -m'},
    {'label': 'processes', 'cmd': 'ps aux --sort=-%mem | head -n 10'},
    {'label': 'docker', 'cmd': 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker not running"'},
    {'label': 'firewall', 'cmd': 'sudo iptables -L INPUT -n -v --line-numbers | head -n 20'},
    {'label': 'netstat', 'cmd': 'sudo netstat -tulpn 2>/dev/null || sudo ss -tulpn'},
    {'label': 'uname', 'cmd': 'uname -a'},
    {'label': 'clear', 'cmd': 'clear'},
  ];

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);

    // Synchronize terminal output with remote SSH session
    _terminal.onOutput = (data) {
      _sendRaw(data);
    };

    // Synchronize terminal resize (SIGWINCH) for curses/htop layout reflow
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _shellSession?.resizeTerminal(width, height, pixelWidth, pixelHeight);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initConnection();
    });
  }

  @override
  void dispose() {
    _disconnect();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _terminalFocusNode.dispose();
    super.dispose();
  }

  void _disconnect() {
    try {
      _stdoutSub?.cancel();
      _stderrSub?.cancel();
      _shellSession?.close();
      _client?.close();
    } catch (_) {}
    _stdoutSub = null;
    _stderrSub = null;
    _shellSession = null;
    _client = null;
  }

  void _writeBanner() {
    _terminal.write('\x1b[1;36m════════════════════════════════════════════════════════════\x1b[0m\r\n');
    _terminal.write('\x1b[1;32m⚡ AEGIS SECURE CONSOLE [v2.0] - INITIATING TERMINAL LINK\x1b[0m\r\n');
    _terminal.write('\x1b[1;37m🎯 Target Node: ${widget.server.username}@${widget.server.host}:${widget.server.port}\x1b[0m\r\n');
    _terminal.write('\x1b[0;33m🔒 Auth Mode: ${widget.server.authType.name.toUpperCase()} | PTY: xterm-256color\x1b[0m\r\n');
    _terminal.write('\x1b[1;36m════════════════════════════════════════════════════════════\x1b[0m\r\n\r\n');
  }

  Future<void> _initConnection() async {
    if (!mounted) return;

    setState(() {
      _connectionState = TerminalConnectionState.connecting;
      _errorMessage = null;
    });

    _terminal.buffer.clear();
    _terminal.buffer.setCursor(0, 0);
    _writeBanner();
    _terminal.write('\x1b[0;33mConnecting to SSH gateway...\x1b[0m\r\n');

    final serverProvider = context.read<ServerProvider>();

    try {
      final credential = await serverProvider.getCredentialForServer(widget.server);
      final totpSecret = await serverProvider.get2FASecretForServer(widget.server);

      if (credential == null || credential.trim().isEmpty) {
        setState(() {
          _connectionState = TerminalConnectionState.error;
          _errorMessage = 'Kredensial belum dikonfigurasi untuk "${widget.server.name}". Masukkan Private Key atau Password di menu Server.';
        });
        _terminal.write('\r\n\x1b[1;31m❌ ERROR: Kredensial SSH tidak ditemukan di Secure Vault.\x1b[0m\r\n');
        _terminal.write('\x1b[0;36m👉 Silakan ketuk tombol "KONFIGURASI" pada kartu server untuk memasang kunci.\x1b[0m\r\n');
        return;
      }

      final client = await _sshService.connectClient(
        profile: widget.server,
        credential: credential,
        totpSecret: totpSecret,
        onPrompt2FA: (prompt) async {
          if (!mounted) return null;
          return TwoFactorAuthDialog.show(
            context,
            username: widget.server.username,
            serverName: widget.server.name,
            promptText: prompt,
          );
        },
      );

      _client = client;

      // Allocate interactive pseudo-terminal (PTY) with initial columns/rows
      final ptyWidth = _terminal.viewWidth > 0 ? _terminal.viewWidth : 80;
      final ptyHeight = _terminal.viewHeight > 0 ? _terminal.viewHeight : 24;

      final session = await client.shell(
        pty: SSHPtyConfig(
          width: ptyWidth,
          height: ptyHeight,
          type: 'xterm-256color',
        ),
      );

      _shellSession = session;

      _stdoutSub = session.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
            (text) => _terminal.write(text),
            onError: (err) => _terminal.write('\r\n\x1b[1;31m[STDOUT ERROR: $err]\x1b[0m\r\n'),
            onDone: () => _handleSessionClosed(),
          );

      _stderrSub = session.stderr
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
            (text) => _terminal.write(text),
            onError: (err) => _terminal.write('\r\n\x1b[1;31m[STDERR ERROR: $err]\x1b[0m\r\n'),
          );

      if (mounted) {
        setState(() {
          _connectionState = TerminalConnectionState.connected;
        });
        _terminal.write('\r\n\x1b[1;32m🟢 Terhubung ke ${widget.server.name} (${widget.server.host}).\x1b[0m\r\n\r\n');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionState = TerminalConnectionState.error;
          _errorMessage = e.toString();
        });
        _terminal.write('\r\n\x1b[1;31m❌ KONEKSI GAGAL: $e\x1b[0m\r\n');
        _terminal.write('\x1b[0;33mPeriksa konektivitas jaringan, port SSH, dan kredensial server.\x1b[0m\r\n');
      }
    }
  }

  void _handleSessionClosed() {
    if (!mounted) return;
    setState(() {
      _connectionState = TerminalConnectionState.disconnected;
    });
    _terminal.write('\r\n\x1b[1;33m🔌 Sesi terminal ditutup oleh remote host.\x1b[0m\r\n');
  }

  void _sendRaw(String data) {
    if (_shellSession != null) {
      _shellSession!.write(Uint8List.fromList(utf8.encode(data)));
    }
  }

  Future<void> _submitCommand([String? overrideCmd]) async {
    final rawCmd = overrideCmd ?? _inputController.text;
    final cmd = rawCmd.trim();

    if (cmd.isEmpty) {
      _sendRaw('\n');
      return;
    }

    if (cmd == 'clear' || cmd == 'cls') {
      _clearTerminal();
      return;
    }

    // Add to local history
    _commandHistory.remove(cmd);
    _commandHistory.add(cmd);
    _historyIndex = -1;

    _inputController.clear();
    _sendRaw('$cmd\n');
  }

  void _clearTerminal() {
    setState(() {
      _showNodeBanner = false;
    });
    _terminal.buffer.clear();
    _terminal.buffer.setCursor(0, 0);
    _inputController.clear();
  }

  void _sendKey(String keySequence) {
    _sendRaw(keySequence);
  }

  void _navigateHistory(bool up) {
    if (_commandHistory.isEmpty) {
      // If no history in input field, send arrow key escape code to PTY
      _sendRaw(up ? '\x1b[A' : '\x1b[B');
      return;
    }

    if (up) {
      if (_historyIndex == -1) {
        _historyIndex = _commandHistory.length - 1;
      } else if (_historyIndex > 0) {
        _historyIndex--;
      }
    } else {
      if (_historyIndex != -1) {
        if (_historyIndex < _commandHistory.length - 1) {
          _historyIndex++;
        } else {
          _historyIndex = -1;
          _inputController.clear();
          return;
        }
      }
    }

    if (_historyIndex >= 0 && _historyIndex < _commandHistory.length) {
      final text = _commandHistory[_historyIndex];
      _inputController.text = text;
      _inputController.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    final isIndo = settings.isIndonesian;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 650;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070B12) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.primary : AppColors.primaryLight).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.terminal_rounded,
                size: isCompact ? 16 : 18,
                color: isDark ? AppColors.primary : AppColors.primaryLight,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.server.name,
                    style: TextStyle(
                      fontSize: isCompact ? 13 : 14,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    '${widget.server.username}@${widget.server.host}:${widget.server.port}',
                    style: TextStyle(
                      fontSize: isCompact ? 9 : 10,
                      fontFamily: 'monospace',
                      color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Connection status pill (compact on phone)
          _buildStatusPill(isIndo, isCompact: isCompact),
          const SizedBox(width: 2),

          // Quick actions visible on wider screens (desktop / tablet >= 650px)
          if (!isCompact) ...[
            IconButton(
              icon: Icon(
                _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                size: 20,
              ),
              tooltip: _isFullscreen
                  ? (isIndo ? 'Keluar Layar Penuh' : 'Exit Fullscreen')
                  : (isIndo ? 'Layar Penuh' : 'Fullscreen Mode'),
              onPressed: () => setState(() => _isFullscreen = !_isFullscreen),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: isIndo ? 'Hubungkan Ulang' : 'Reconnect',
              onPressed: () {
                _disconnect();
                _initConnection();
              },
            ),
          ],

          // Triple Dot Menu: Consolidates all features cleanly, essential on smaller devices / phones
          _buildTripleDotMenu(context, isDark, isIndo, isCompact: isCompact),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Error banner if connection failed
          if (_connectionState == TerminalConnectionState.error && _errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: isDark ? AppColors.danger.withValues(alpha: 0.2) : AppColors.dangerLight.withValues(alpha: 0.15),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 16, color: isDark ? AppColors.danger : AppColors.dangerLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.danger : AppColors.dangerLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Top Info Banner (Displays target node status & quick info)
          if (_showNodeBanner && !_isFullscreen)
            Container(
              margin: const EdgeInsets.fromLTRB(8, 6, 8, 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.primary : AppColors.primaryLight).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (isDark ? AppColors.primary : AppColors.primaryLight).withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 15,
                    color: isDark ? AppColors.primary : AppColors.primaryLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AEGIS SECURE CONSOLE [v2.0]',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: isDark ? AppColors.primary : AppColors.primaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          '${widget.server.username}@${widget.server.host}:${widget.server.port}  •  xterm-256color',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _showNodeBanner = false),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Quick Commands Ribbon
          if (!_isFullscreen) _buildQuickCommandsBar(isDark),

          // Main Terminal Output Display with xterm.dart TerminalView
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: _isFullscreen ? 0 : 8,
                vertical: _isFullscreen ? 0 : 4,
              ),
              decoration: BoxDecoration(
                color: AegisTerminalThemes.getThemeBackgroundColor(_themeType),
                borderRadius: BorderRadius.circular(_isFullscreen ? 0 : 10),
                border: _isFullscreen
                    ? null
                    : Border.all(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                      ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_isFullscreen ? 0 : 10),
                child: TerminalView(
                  _terminal,
                  controller: _terminalController,
                  theme: AegisTerminalThemes.getTheme(_themeType),
                  textStyle: TerminalStyle(
                    fontSize: _fontSize,
                    fontFamily: 'monospace',
                    height: 1.25,
                  ),
                  focusNode: _terminalFocusNode,
                  autofocus: true,
                  autoResize: true,
                  alwaysShowCursor: true,
                  cursorType: TerminalCursorType.block,
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
          ),

          // Virtual Navigation Keys Ribbon (Mobile & Touch ergonomics)
          _buildVirtualKeysBar(isDark),

          // Terminal Input Row (Collapsible in Fullscreen mode)
          if (!_isFullscreen) _buildInputRow(context, isDark),
        ],
      ),
    );
  }

  Widget _buildTripleDotMenu(
    BuildContext context,
    bool isDark,
    bool isIndo, {
    required bool isCompact,
  }) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
      ),
      tooltip: isIndo ? 'Menu Terminal' : 'Terminal Menu',
      position: PopupMenuPosition.under,
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
        ),
      ),
      onSelected: (value) {
        switch (value) {
          case 'theme':
            _showThemePickerDialog(context, isDark, isIndo);
            break;
          case 'fullscreen':
            setState(() => _isFullscreen = !_isFullscreen);
            break;
          case 'reconnect':
            _disconnect();
            _initConnection();
            break;
          case 'font_inc':
            if (_fontSize < 22) setState(() => _fontSize += 1.0);
            break;
          case 'font_dec':
            if (_fontSize > 9) setState(() => _fontSize -= 1.0);
            break;
          case 'clear':
            _clearTerminal();
            break;
          case 'copy':
            final text = _terminal.buffer.getText();
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isIndo ? 'Output konsol disalin ke clipboard' : 'Console output copied to clipboard'),
                duration: const Duration(seconds: 1),
              ),
            );
            break;
          case 'toggle_banner':
            setState(() => _showNodeBanner = !_showNodeBanner);
            break;
        }
      },
      itemBuilder: (context) => [
        // 1. Theme selector
        PopupMenuItem<String>(
          value: 'theme',
          child: Row(
            children: [
              Icon(Icons.palette_outlined, size: 18, color: isDark ? AppColors.primary : AppColors.primaryLight),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isIndo ? 'Pilih Tema' : 'Terminal Theme',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AegisTerminalThemes.getThemePreviewColor(_themeType),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),

        // 2. Fullscreen toggle
        PopupMenuItem<String>(
          value: 'fullscreen',
          child: Row(
            children: [
              Icon(
                _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                size: 18,
                color: isDark ? AppColors.primary : AppColors.primaryLight,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isFullscreen
                      ? (isIndo ? 'Keluar Layar Penuh' : 'Exit Fullscreen')
                      : (isIndo ? 'Layar Penuh' : 'Fullscreen Mode'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // 3. Reconnect
        PopupMenuItem<String>(
          value: 'reconnect',
          child: Row(
            children: [
              Icon(Icons.refresh_rounded, size: 18, color: isDark ? AppColors.primary : AppColors.primaryLight),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isIndo ? 'Hubungkan Ulang' : 'Reconnect',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        const PopupMenuDivider(),

        // 4. Increase Font
        PopupMenuItem<String>(
          value: 'font_inc',
          child: Row(
            children: [
              Icon(Icons.text_increase_rounded, size: 18, color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isIndo ? 'Perbesar Font (A+)' : 'Increase Font (A+)',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Text(
                '${_fontSize.toInt()}pt',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        ),

        // 5. Decrease Font
        PopupMenuItem<String>(
          value: 'font_dec',
          child: Row(
            children: [
              Icon(Icons.text_decrease_rounded, size: 18, color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isIndo ? 'Perkecil Font (A-)' : 'Decrease Font (A-)',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        const PopupMenuDivider(),

        // 6. Copy All Output
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy_all_rounded, size: 18, color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isIndo ? 'Salin Log Konsol' : 'Copy All Output',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // 7. Clear Console
        PopupMenuItem<String>(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.delete_sweep_rounded, size: 18, color: isDark ? AppColors.danger : AppColors.dangerLight),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isIndo ? 'Bersihkan Konsol' : 'Clear Console',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.danger : AppColors.dangerLight,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 8. Toggle Info Banner
        PopupMenuItem<String>(
          value: 'toggle_banner',
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: isDark ? AppColors.textMuted : AppColors.lightTextMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _showNodeBanner
                      ? (isIndo ? 'Sembunyikan Info Node' : 'Hide Node Info')
                      : (isIndo ? 'Tampilkan Info Node' : 'Show Node Info'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showThemePickerDialog(BuildContext context, bool isDark, bool isIndo) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0B132B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.primary : AppColors.primaryLight).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  size: 20,
                  color: isDark ? AppColors.primary : AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isIndo ? 'Pilih Tema Terminal' : 'Terminal Theme',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: AegisTerminalThemeType.values.map((type) {
                final isSelected = _themeType == type;
                final previewColor = AegisTerminalThemes.getThemePreviewColor(type);
                final bgColor = AegisTerminalThemes.getThemeBackgroundColor(type);
                final name = AegisTerminalThemes.getThemeName(type);
                final desc = AegisTerminalThemes.getThemeDescription(type, isIndo);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() => _themeType = type);
                      Navigator.of(dialogCtx).pop();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? previewColor.withValues(alpha: 0.15) : previewColor.withValues(alpha: 0.1))
                            : (isDark ? const Color(0xFF131D2E) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? previewColor : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Miniature terminal preview tile
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: previewColor.withValues(alpha: 0.6)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '>_',
                              style: TextStyle(
                                color: previewColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? previewColor : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded, size: 18, color: previewColor)
                          else
                            Icon(Icons.radio_button_unchecked_rounded, size: 18, color: isDark ? Colors.white24 : Colors.black26),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(isIndo ? 'Tutup' : 'Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusPill(bool isIndo, {required bool isCompact}) {
    Color color;
    String label;

    switch (_connectionState) {
      case TerminalConnectionState.connected:
        color = AppColors.success;
        label = 'ONLINE';
        break;
      case TerminalConnectionState.connecting:
        color = AppColors.warning;
        label = isCompact ? '...' : (isIndo ? 'KONEKSI...' : 'CONNECTING...');
        break;
      case TerminalConnectionState.disconnected:
        color = AppColors.danger;
        label = isCompact ? 'OFF' : (isIndo ? 'TERPUTUS' : 'DISCONNECTED');
        break;
      case TerminalConnectionState.error:
        color = AppColors.danger;
        label = 'ERROR';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isCompact ? 5 : 6,
            height: isCompact ? 5 : 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 8.5 : 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCommandsBar(bool isDark) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _quickCommands.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final item = _quickCommands[i];
          final isHtop = item['label'] == 'htop';
          return ActionChip(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            backgroundColor: isHtop
                ? (isDark ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : const Color(0xFF0284C7).withValues(alpha: 0.15))
                : (isDark ? const Color(0xFF131D2E) : const Color(0xFFE2E8F0)),
            side: BorderSide(
              color: isHtop
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.5)
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
              width: 0.8,
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isHtop) ...[
                  const Icon(Icons.speed_rounded, size: 12, color: Color(0xFF00E5FF)),
                  const SizedBox(width: 4),
                ],
                Text(
                  item['label']!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: isHtop
                        ? const Color(0xFF00E5FF)
                        : (isDark ? AppColors.primary : AppColors.primaryLight),
                  ),
                ),
              ],
            ),
            onPressed: () => _submitCommand(item['cmd']),
          );
        },
      ),
    );
  }

  Widget _buildVirtualKeysBar(bool isDark) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKeyButton('ESC', () => _sendKey('\x1b'), isDark),
            const SizedBox(width: 6),
            _buildKeyButton('Ctrl+C', () => _sendKey('\x03'), isDark, isHighlight: true),
            const SizedBox(width: 6),
            _buildKeyButton('Tab', () => _sendKey('\t'), isDark),
            const SizedBox(width: 6),
            _buildKeyButton('▲ Up', () => _navigateHistory(true), isDark),
            const SizedBox(width: 6),
            _buildKeyButton('▼ Down', () => _navigateHistory(false), isDark),
            const SizedBox(width: 6),
            _buildKeyButton('◀ Left', () => _sendKey('\x1b[D'), isDark),
            const SizedBox(width: 6),
            _buildKeyButton('▶ Right', () => _sendKey('\x1b[C'), isDark),
            const SizedBox(width: 6),
            _buildKeyButton('sudo', () {
              if (!_inputController.text.startsWith('sudo ')) {
                _inputController.text = 'sudo ${_inputController.text}';
                _inputController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _inputController.text.length),
                );
              }
            }, isDark),
            const SizedBox(width: 6),
            _buildKeyButton('| grep', () {
              _inputController.text = '${_inputController.text} | grep ';
              _inputController.selection = TextSelection.fromPosition(
                TextPosition(offset: _inputController.text.length),
              );
            }, isDark),
            const SizedBox(width: 6),
            _buildKeyButton('Clear', _clearTerminal, isDark),
            const SizedBox(width: 6),
            _buildKeyButton('Ctrl+D', () => _sendKey('\x04'), isDark),
            const SizedBox(width: 6),
            _buildKeyButton('Ctrl+Z', () => _sendKey('\x1a'), isDark),
            const SizedBox(width: 6),
            _buildKeyButton('Ctrl+L', () => _sendKey('\x0c'), isDark),
            const SizedBox(width: 6),
            _buildKeyButton('PgUp', () => _sendKey('\x1b[5~'), isDark),
            const SizedBox(width: 6),
            _buildKeyButton('PgDn', () => _sendKey('\x1b[6~'), isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyButton(String label, VoidCallback onTap, bool isDark, {bool isHighlight = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isHighlight
              ? (isDark ? AppColors.danger.withValues(alpha: 0.2) : AppColors.dangerLight.withValues(alpha: 0.15))
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isHighlight
                ? AppColors.danger.withValues(alpha: 0.4)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: isHighlight
                ? AppColors.danger
                : (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Prompt tag
            Text(
              '# ',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark ? const Color(0xFF00E5FF) : AppColors.primaryLight,
              ),
            ),

            // Input field
            Expanded(
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocusNode,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter command or tap terminal...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                ),
                onSubmitted: (_) => _submitCommand(),
              ),
            ),

            // Send/Run Button
            IconButton(
              icon: Icon(
                Icons.keyboard_return_rounded,
                color: isDark ? const Color(0xFF00E5FF) : AppColors.primaryLight,
                size: 20,
              ),
              onPressed: () => _submitCommand(),
              tooltip: 'Execute Command',
            ),
          ],
        ),
      ),
    );
  }
}

