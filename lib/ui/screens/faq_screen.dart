import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';

enum FaqCategory { all, policy, server, detection, security }

class FaqItem {
  final String id;
  final FaqCategory category;
  final String questionId;
  final String questionEn;
  final String answerId;
  final String answerEn;
  final List<String>? codeSnippets;
  final String? codeSnippetTitleId;
  final String? codeSnippetTitleEn;

  const FaqItem({
    required this.id,
    required this.category,
    required this.questionId,
    required this.questionEn,
    required this.answerId,
    required this.answerEn,
    this.codeSnippets,
    this.codeSnippetTitleId,
    this.codeSnippetTitleEn,
  });
}

class FaqScreen extends StatefulWidget {
  final String? initialSearchQuery;
  final FaqCategory? initialCategory;

  const FaqScreen({
    super.key,
    this.initialSearchQuery,
    this.initialCategory,
  });

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  late TextEditingController _searchController;
  late FaqCategory _selectedCategory;
  String? _expandedItemId;
  bool? _overrideIndonesian;

  final List<FaqItem> _faqList = [
    // 1. Jendela Kecepatan (Waktu Geser)
    const FaqItem(
      id: 'faq_velocity_window',
      category: FaqCategory.policy,
      questionId: 'Apa fungsi dari "Jendela Kecepatan (Waktu Geser)"?',
      questionEn: 'What is the function of the "Velocity Window (Sliding Time)"?',
      answerId:
          'Jendela Kecepatan atau Waktu Geser (Sliding Time Window) menentukan rentang waktu bergulir (dalam detik) di mana kegagalan autentikasi dihitung terhadap sebuah IP address sebelum hitungan tersebut kedaluwarsa.\n\n'
          'Sistem ini tidak menggunakan jam dinding statis (misal 08:00 - 09:00), melainkan menghitung frekuensi percobaan dalam interval bergulir [Waktu Sekarang - Jendela Waktu, Waktu Sekarang].\n\n'
          'Contoh Skenario Nyata:\n'
          '• Skenario Brute-Force (Terdeteksi):\n'
          '  Batas Maks: 3 kali, Jendela: 120 detik.\n'
          '  Jika penyerang gagal login pada detik 00:00, 00:30, dan 01:10, ketiga kegagalan terjadi dalam kurun 70 detik (< 120 detik). Sistem langsung mendeteksi serangan Brute-Force aktif dan membunyikan alarm kritis.\n\n'
          '• Skenario Typo Manusia Normal (Tidak Diblokir):\n'
          '  Jika operator salah memasukkan password pada pukul 08:00, lalu mencoba lagi 5 menit kemudian (08:05) dan salah lagi, selisih waktu adalah 300 detik (> 120 detik). Kegagalan pertama sudah "bergeser keluar" (hangus) sehingga operator tidak terblokir.',
      answerEn:
          'The Velocity Window (Sliding Time Window) defines the rolling time interval (in seconds) within which failed authentication attempts from a single IP address are accumulated before they expire.\n\n'
          'Rather than relying on static clock hours, AEGIS calculates attempt density in a rolling window: [Current Time - Window Duration, Current Time].\n\n'
          'Real-World Example:\n'
          '• Brute-Force Incursion (Detected):\n'
          '  Threshold: 3 attempts, Window: 120s.\n'
          '  An attacker fails at 00:00, 00:30, and 01:10. All 3 failures occurred within 70 seconds (< 120s). The engine instantly escalates the risk score to 95/100, fires a high-priority alert, and offers 1-tap firewall isolation.\n\n'
          '• Normal Human Typo (Safe & Not Blocked):\n'
          '  A legitimate user mistypes their credential at 08:00, and mistypes again 5 minutes later at 08:05. The interval is 300 seconds (> 120s). The first failed attempt has safely slid out of the window and expired, avoiding false-positive lockouts.',
    ),

    // 2. Batas Maks Login Gagal Sebelum Peringatan
    const FaqItem(
      id: 'faq_max_failed_attempts',
      category: FaqCategory.policy,
      questionId: 'Apa fungsi "Batas Maks Login Gagal Sebelum Peringatan"?',
      questionEn: 'What is the "Max Failed Logins Before Alert" threshold?',
      answerId:
          'Batas Maks Login Gagal (Max Failed Attempts Threshold) adalah jumlah toleransi kegagalan login yang diizinkan untuk sebuah alamat IP dalam durasi Jendela Waktu Geser.\n\n'
          'Cara Kerjanya di AEGIS:\n'
          '1. Setiap kali terjadi kegagalan (misalnya MySQL Access Denied atau SSH Failed Password), mesin telemetri mencatat timestamp IP tersebut.\n'
          '2. Ketika jumlah kegagalan mencapai ambang batas (default: 3 hingga 5 kali), AEGIS otomatis menaikkan status menjadi BRUTE FORCE ATTACK.\n'
          '3. Risk score dinaikkan ke level kritis (95/100), notifikasi push dikirimkan, dan tombol BLOKIR IP (Mitigasi Cepat) disorot di dashboard dan modal forensik.\n\n'
          'Nilai ini dapat disesuaikan melalui slider di halaman Kebijakan Keamanan (Policy Settings) untuk tiap server.',
      answerEn:
          'The Max Failed Logins Before Alert specifies the tolerance threshold for authentication failures permitted from a client IP within the configured Velocity Window.\n\n'
          'How AEGIS Enforces It:\n'
          '1. Every failed event (such as MySQL Access Denied or SSH Failed Password) logs a timestamped forensic entry.\n'
          '2. Once failure counts breach this threshold (default: 3 to 5 attempts), AEGIS escalates the event severity to BRUTE FORCE ATTACK.\n'
          '3. The threat risk score surges to critical (95/100), priority alert notifications are dispatched, and 1-tap rapid firewall blocking is activated.\n\n'
          'You can fine-tune this parameter on the Policy Settings screen per server profile.',
    ),

    // 3. Penyimpanan di Server & Cara Akses
    const FaqItem(
      id: 'faq_server_storage',
      category: FaqCategory.server,
      questionId: 'Apakah Batas Login Gagal & Waktu Geser tersimpan di server? Bagaimana cara mengaksesnya?',
      questionEn: 'Are the Failed Login Threshold & Velocity Window saved on the server? How do I access them?',
      answerId:
          'Ya, parameter ini tersimpan di dua tingkatan:\n\n'
          '1. Di Aplikasi AEGIS (Client):\n'
          '   Tersimpan terenkripsi pada hardware keystore perangkat Anda (SecureVault) dan file lokal ~/.config/aegis/policies.json.\n\n'
          '2. Di Sisi Server VPS (Linux Firewall & Daemon):\n'
          '   • Pada fail2ban (Firewall Server):\n'
          '     - "Batas Maks Login Gagal" dipetakan ke parameter "maxretry".\n'
          '     - "Jendela Waktu Geser" dipetakan ke parameter "findtime".\n'
          '   • Pada daemon aegis-agent (jika terpasang di /opt/aegis-agent):\n'
          '     - Tersimpan di file konfigurasi JSON /opt/aegis-agent/config.json.\n\n'
          'Cara Melihat dan Mengakses di Server VPS via Terminal SSH:\n'
          'Gunakan perintah fail2ban-client atau periksa file konfigurasi jail server seperti tercantum di bawah.',
      answerEn:
          'Yes, these parameters operate at two synchronized layers:\n\n'
          '1. Inside AEGIS App (Client):\n'
          '   Encrypted in hardware storage (SecureVault) and ~/.config/aegis/policies.json on your workstation.\n\n'
          '2. On the Target VPS Server (Linux Firewall & Daemon):\n'
          '   • In fail2ban (Server Firewall):\n'
          '     - "Max Failed Logins" corresponds directly to "maxretry".\n'
          '     - "Velocity Window" corresponds directly to "findtime".\n'
          '   • In aegis-agent daemon (if installed in /opt/aegis-agent):\n'
          '     - Stored in /opt/aegis-agent/config.json.\n\n'
          'How to Inspect on the Server via SSH Terminal:\n'
          'Run the fail2ban-client queries or check the jail configuration file as shown below.',
      codeSnippetTitleId: 'Perintah Terminal Server (SSH)',
      codeSnippetTitleEn: 'Server Terminal Commands (SSH)',
      codeSnippets: [
        '# 1. Cek parameter aktif fail2ban untuk SSH:\n'
            'sudo fail2ban-client get sshd maxretry\n'
            'sudo fail2ban-client get sshd findtime\n\n'
            '# 2. Cek parameter aktif fail2ban untuk MySQL:\n'
            'sudo fail2ban-client get mysqld-auth maxretry\n'
            'sudo fail2ban-client get mysqld-auth findtime\n\n'
            '# 3. Periksa file konfigurasi jail server:\n'
            'cat /etc/fail2ban/jail.local\n'
            '# atau periksa direktori jail.d:\n'
            'cat /etc/fail2ban/jail.d/*.conf\n\n'
            '# 4. Periksa file konfigurasi aegis-agent daemon (jika ada):\n'
            'cat /opt/aegis-agent/config.json\n'
            'sudo systemctl status aegis-agent',
      ],
    ),

    // 4. Unknown Person Login
    const FaqItem(
      id: 'faq_unknown_person',
      category: FaqCategory.detection,
      questionId: 'Apa yang dimaksud dengan "Login Orang Tak Dikenal" (Unknown Person Login)?',
      questionEn: 'What is an "Unknown Person Login" and why is it critical?',
      answerId:
          'Login Orang Tak Dikenal adalah kondisi di mana autentikasi dinyatakan SUKSES (berhasil masuk), namun koneksi berasal dari alamat IP yang TIDAK terdaftar di Daftar Putih (IP Whitelist).\n\n'
          'Mengapa Ini Sangat Kritis?\n'
          'Sebagian besar sistem IDS/IPS hanya memantau login yang gagal. Namun jika seorang penyerang berhasil mencuri kunci SSH (private key) atau password database MySQL Anda, login mereka akan tercatat sebagai "SUCCESS".\n\n'
          'AEGIS membandingkan IP koneksi dengan Daftar Putih terpercaya Anda. Jika ada login sukses dari negara/IP luar yang tidak dikenal, AEGIS segera menandainya sebagai Insiden Kritis Tingkat 1 (Risk Score: 98/100) dan mengirimkan notifikasi instan.',
      answerEn:
          'An Unknown Person Login occurs when an authentication event is deemed SUCCESSFUL, but the client IP address is NOT listed in your Trusted IP Whitelist.\n\n'
          'Why is this a High-Risk Incursion?\n'
          'Traditional security tools only alert on failed logins. If an attacker steals your SSH private key or MySQL credentials, their login appears legitimate to basic logs.\n\n'
          'AEGIS evaluates verified logins against your trusted perimeter baseline. Any valid authentication originating from an unrecognized IP triggers an immediate Critical Threat alert (Risk Score: 98/100) to stop unauthorized sessions before data exfiltration occurs.',
    ),

    // 5. Mitigasi Cepat & Pemblokiran Firewall
    const FaqItem(
      id: 'faq_mitigation_blocking',
      category: FaqCategory.server,
      questionId: 'Bagaimana cara kerja tombol "Blokir IP" (Mitigasi Cepat)?',
      questionEn: 'How does the "Block IP" (Rapid Mitigation) button operate?',
      answerId:
          'Ketika operator menekan tombol "BLOKIR IP" pada dialog Forensik Insiden:\n\n'
          '1. Verifikasi Biometrik (Opsional):\n'
          '   Jika Kunci Biometrik diaktifkan di Pengaturan, sensor sidik jari / otorisasi sistem akan meminta verifikasi operator terlebih dahulu.\n\n'
          '2. Pendaftaran Kebijakan Lokal:\n'
          '   IP tersebut didaftarkan ke Daftar IP Diblokir (Banned IP List) di SecureVault AEGIS.\n\n'
          '3. Eksekusi Firewall Server Instan (SSH):\n'
          '   AEGIS mengirimkan instruksi SSH terenkripsi ke host server untuk memblokir IP secara langsung di kernel firewall:\n'
          '   • iptables -I INPUT 1 -s [IP] -j DROP\n'
          '   • fail2ban-client set [jail] banip [IP]\n\n'
          '4. Eskalasi Hak Akses Root (Sudo) Otomatis:\n'
          '   Jika login SSH menggunakan user non-root (seperti wito_general), AEGIS mengambil password sudo yang tersimpan aman di SecureVault perangkat dan mengeksekusinya via pipa "echo \'<pass>\' | sudo -S -p \'\'".\n\n'
          'Aturan DROP disisipkan di baris nomor 1 rantai INPUT Linux Netfilter sehingga paket penyerang langsung dibuang seketika oleh kernel sebelum mencapai soket aplikasi.',
      answerEn:
          'When an operator clicks "BLOCK IP" on the Incident Forensics dialog:\n\n'
          '1. Biometric Gating (Optional):\n'
          '   If Biometric Lock is active in Settings, an interactive sensor authorization prompt appears first to prevent accidental lockouts.\n\n'
          '2. Local Policy Persistence:\n'
          '   The IP is cataloged into the encrypted Banned IP Registry in SecureVault.\n\n'
          '3. Instant Remote Server Firewall Execution (SSH):\n'
          '   AEGIS securely transmits remote firewall commands to the host server:\n'
          '   • iptables -I INPUT 1 -s [IP] -j DROP\n'
          '   • fail2ban-client set [jail] banip [IP]\n\n'
          '4. Automated Non-Root Sudo Escalation:\n'
          '   If connected via a non-root account (e.g. wito_general), AEGIS fetches your vaulted sudo password and pipes it non-interactively via "echo \'<pass>\' | sudo -S -p \'\'".\n\n'
          'The DROP rule is inserted at index 1 of the Linux Netfilter INPUT chain, severing the connection instantly before packets ever reach userland sockets.',
      codeSnippetTitleId: 'Perintah Firewall yang Dijalankan di Server',
      codeSnippetTitleEn: 'Firewall Commands Dispatched to Server',
      codeSnippets: [
        '# 1. Sisipkan aturan DROP langsung di urutan nomor 1 iptables kernel:\n'
            'echo \'<password_sudo>\' | sudo -S iptables -I INPUT 1 -s <IP_PENYERANG> -j DROP\n\n'
            '# 2. Blokir IP pada jail Fail2ban (SSH & MySQL):\n'
            'echo \'<password_sudo>\' | sudo -S fail2ban-client set sshd banip <IP_PENYERANG>\n'
            'echo \'<password_sudo>\' | sudo -S fail2ban-client set mysqld-auth banip <IP_PENYERANG>',
      ],
    ),

    // 5b. Mengapa IP yang sudah diblokir masih bisa mencoba login?
    const FaqItem(
      id: 'faq_blocked_ip_still_attempting',
      category: FaqCategory.server,
      questionId: 'Mengapa IP yang sudah diblokir sebelumnya masih tampak mencoba login di log server?',
      questionEn: 'Why was an IP previously blocked still appearing in server login attempt logs?',
      answerId:
          'Jika Anda mendapati IP penyerang masih tercatat di log auth setelah tombol "Blokir IP" ditekan, hal ini biasanya disebabkan oleh:\n\n'
          '1. Pemblokiran Hanya Berada di Level Aplikasi (Belum Tembus ke Kernel Server):\n'
          '   Sebelum fitur Eskalasi Sudo dikonfigurasi, IP hanya tersimpan di daftar blokir lokal aplikasi Anda. Port fisik VPS di internet masih tetap terbuka dan merespons paket TCP SYN penyerang.\n\n'
          '2. User SSH Non-Root Membutuhkan Password Sudo:\n'
          '   Jika user SSH Anda bukan root (misalnya wito_general), Linux menolak eksekusi "iptables" atau "fail2ban-client" tanpa eskalasi sudo. Perintah SSH remote gagal tanpa prompt interaktif.\n\n'
          '3. Solusi Tuntas (Eskalasi Root Sudo di Aplikasi):\n'
          '   Cukup masukkan password akun user Anda di menu: Armada Server & Vault -> Edit Profil Server -> ESKALASI ROOT (SUDO PASSWORD).\n\n'
          'Setelah tersimpan di SecureVault, setiap penekanan tombol "BLOKIR IP" akan langsung menyisipkan aturan "DROP" di baris nomor 1 pada iptables Linux VPS. Paket penyerang akan dibuang seketika oleh kernel sistem operasi sebelum sempat ditanggapi oleh layanan SSH atau web server.',
      answerEn:
          'If an attacker IP was still showing up in auth logs after tapping "Block IP", the root causes are:\n\n'
          '1. Client-Side Only Ban vs Server Kernel Firewall Ban:\n'
          '   Prior to configuring Sudo Escalation, the ban existed only in local app policy. The remote VPS physical network port remained open and responsive to incoming TCP SYN handshake packets.\n\n'
          '2. Non-Root SSH User Requiring Sudo Elevation:\n'
          '   Non-root users (such as wito_general) cannot modify iptables or fail2ban jails without sudo rights. Remote SSH sessions without a piped password fail silently due to terminal prompt requirements.\n\n'
          '3. Complete Resolution (Root Sudo Escalation in App):\n'
          '   Enter your user sudo password in: Server Fleet & Vault -> Edit Server -> ROOT ESCALATION (SUDO PASSWORD).\n\n'
          'Once saved in SecureVault, tapping "BLOCK IP" inserts an immediate DROP rule at index 1 of the Linux Netfilter kernel table. Hostile packets are discarded on the wire before ever touching SSH or database daemons.',
      codeSnippetTitleId: 'Pemeriksaan Aturan DROP di Server',
      codeSnippetTitleEn: 'Inspecting Active Kernel DROP Rules on Server',
      codeSnippets: [
        '# Cek apakah IP penyerang sudah aktif di baris teratas iptables:\n'
            'sudo iptables -L INPUT -n -v --line-numbers | head -n 15\n\n'
            '# Cek status jail fail2ban untuk IP yang diblokir:\n'
            'sudo fail2ban-client status sshd',
      ],
    ),

    // 5c. Konfigurasi Sudo untuk User Non-Root
    const FaqItem(
      id: 'faq_sudo_root_escalation',
      category: FaqCategory.server,
      questionId: 'Bagaimana cara mengatur hak akses Sudo untuk user SSH non-root (seperti wito_general)?',
      questionEn: 'How do I configure Sudo root escalation for non-root SSH users (such as wito_general)?',
      answerId:
          'Demi standar keamanan Zero-Trust, server produksi tidak disarankan mengizinkan login SSH langsung sebagai root. Namun, tindakan mitigasi firewall memerlukan hak istimewa root. AEGIS menyediakan dua metode:\n\n'
          'METODE 1: Simpan Kata Sandi Sudo di SecureVault AEGIS (Direkomendasikan):\n'
          '• Buka menu "Armada Server & Vault" di aplikasi AEGIS.\n'
          '• Klik tombol Edit (ikon pensil) pada server Anda.\n'
          '• Gulir ke bagian "ESKALASI ROOT (SUDO PASSWORD)".\n'
          '• Masukkan password akun user non-root Anda (password yang biasa dimasukkan saat menjalankan "sudo -i").\n'
          '• Klik "Simpan & Enkripsi di Vault".\n'
          '• Selesai! Kartu server akan menampilkan lencana hijau "Eskalasi Sudo Siap". Tidak perlu mengubah konfigurasi apa pun di sisi VPS.\n\n'
          'METODE 2: Aturan Sudoers NOPASSWD di Sisi Server (Alternatif):\n'
          'Jika Anda lebih memilih tidak menyimpan password sudo di aplikasi, berikan izin tanpa password khusus untuk biner firewall di server:\n'
          '• Buat file /etc/sudoers.d/aegis di VPS Anda:\n'
          '  wito_general ALL=(ALL) NOPASSWD: /sbin/iptables, /usr/sbin/iptables, /usr/bin/fail2ban-client, /bin/systemctl\n'
          '• Setel hak akses: sudo chmod 440 /etc/sudoers.d/aegis',
      answerEn:
          'Under Zero-Trust best practices, direct root SSH login is discouraged. However, firewall operations require superuser rights. AEGIS supports two robust methods:\n\n'
          'METHOD 1: Store Sudo Password in AEGIS SecureVault (Recommended):\n'
          '• Navigate to "Server Fleet & Vault" in the AEGIS app.\n'
          '• Tap the Edit button (pencil icon) on your server profile.\n'
          '• Scroll down to "ROOT ESCALATION (SUDO PASSWORD)".\n'
          '• Enter your non-root user password (the one you enter when executing "sudo -i").\n'
          '• Tap "Save & Encrypt in Vault".\n'
          '• Done! The server card displays "Sudo Escalation Ready". Zero server-side file modifications needed.\n\n'
          'METHOD 2: Server-Side NOPASSWD Sudoers Rule (Alternative):\n'
          'If you prefer not storing your sudo password in the mobile/desktop app vault, grant restricted passwordless rights on your VPS:\n'
          '• Create /etc/sudoers.d/aegis on your VPS:\n'
          '  wito_general ALL=(ALL) NOPASSWD: /sbin/iptables, /usr/sbin/iptables, /usr/bin/fail2ban-client, /bin/systemctl\n'
          '• Set permissions: sudo chmod 440 /etc/sudoers.d/aegis',
      codeSnippetTitleId: 'Panduan Sudoers di VPS Linux',
      codeSnippetTitleEn: 'Sudoers Configuration Guide on Linux VPS',
      codeSnippets: [
        '# Pasang aturan sudoers khusus untuk AEGIS di VPS (Opsional jika memakai Metode 2):\n'
            'cat << \'EOF\' | sudo tee /etc/sudoers.d/aegis\n'
            'wito_general ALL=(ALL) NOPASSWD: /sbin/iptables, /usr/sbin/iptables, /usr/bin/fail2ban-client, /bin/systemctl\n'
            'EOF\n'
            'sudo chmod 440 /etc/sudoers.d/aegis\n\n'
            '# Validasi sintaks file sudoers agar tidak rusak:\n'
            'sudo visudo -c -f /etc/sudoers.d/aegis',
      ],
    ),

    // 6. Daftar Putih (IP Whitelist)
    const FaqItem(
      id: 'faq_ip_whitelisting',
      category: FaqCategory.policy,
      questionId: 'Bagaimana format penulisan IP di Daftar Putih (Whitelist)?',
      questionEn: 'What is the syntax for adding IPs to the Trusted Whitelist?',
      answerId:
          'Daftar Putih (Trusted IP Whitelist) mendukung beberapa format:\n\n'
          '1. Alamat IP Statis Tunggal:\n'
          '   Contoh: 103.142.21.195 atau 202.10.46.4\n\n'
          '2. Localhost / Loopback Server:\n'
          '   Contoh: 127.0.0.1 atau ::1\n\n'
          '3. Wildcard Subnet (Satu Blok Jaringan):\n'
          '   Gunakan tanda bintang (*) di segmen terakhir untuk mempercayai seluruh subnet kantor/klinik.\n'
          '   Contoh: 182.1.200.* (mencakup 182.1.200.1 hingga 182.1.200.254).',
      answerEn:
          'The Trusted IP Whitelist supports flexible addressing formats:\n\n'
          '1. Single Static IP Address:\n'
          '   Example: 103.142.21.195 or 202.10.46.4\n\n'
          '2. Localhost & Server Internal Loopback:\n'
          '   Example: 127.0.0.1 or ::1\n\n'
          '3. Wildcard Subnet (Entire Office/Clinic Network Block):\n'
          '   Append an asterisk (*) to trust an entire /24 subnet.\n'
          '   Example: 182.1.200.* (covers 182.1.200.1 through 182.1.200.254).',
    ),

    // 7. Sensor Biometrik di Desktop Linux
    const FaqItem(
      id: 'faq_biometrics_desktop',
      category: FaqCategory.security,
      questionId: 'Bagaimana cara kerja Kunci Biometrik di Desktop Linux jika tidak ada sensor fisik?',
      questionEn: 'How does Biometric Lock operate on Linux Desktop without a fingerprint scanner?',
      answerId:
          'Di platform Linux Desktop, sebagian besar hardware tidak memiliki pemindai sidik jari bawaan atau driver OS standar.\n\n'
          'AEGIS menghadirkan Universal Biometric Prompt Dialog:\n'
          '• Menggunakan bantalan sensor sentuh cyber interaktif dengan animasi radar scanning.\n'
          '• Menyediakan tombol alternatif "Gunakan PIN / Kata Sandi Sistem" sebagai verifikasi darurat jika perangkat tidak memiliki pemindai fisik.\n'
          '• Menjamin alur otentikasi tidak pernah macet (*never crashes*) di lingkungan Linux, Windows, macOS, Android, maupun iOS.',
      answerEn:
          'On Linux Desktop systems, physical fingerprint sensors or OS biometric daemons are often unavailable.\n\n'
          'AEGIS resolves this with the Universal Biometric Prompt Dialog:\n'
          '• Features an interactive glowing touch sensor pad with realistic radar pulse scanning.\n'
          '• Provides an instant "Use System Passcode / PIN" fallback button for quick verification.\n'
          '• Ensures security authorization never crashes regardless of whether running on Linux, Windows, macOS, Android, or iOS.',
    ),

    // 8. Laboratorium Uji Penetrasi & Simulasi Alarm Siber
    const FaqItem(
      id: 'faq_penetration_test_lab',
      category: FaqCategory.security,
      questionId: 'Bagaimana cara kerja fitur Uji Penetrasi (Penetration Test) di halaman Pengaturan?',
      questionEn: 'How does the Penetration Testing Lab feature on the Settings page work?',
      answerId:
          'Fitur Laboratorium Uji Penetrasi di menu Pengaturan memungkinkan administrator menyimulasikan serangan siber terkontrol untuk menguji kesiapan sistem pertahanan AEGIS tanpa memengaruhi beban server produksi.\n\n'
          'Kemampuan Utama Uji Penetrasi:\n'
          '1. Pilihan Layanan Target: Anda dapat memilih layanan yang ingin diuji, seperti OpenSSH (Port 22), MySQL/MariaDB (Port 3306), NGINX (Port 80/443), Apache, Redis, PHP-FPM, hingga Pure-FTPd dan Ollama AI.\n'
          '2. Pilihan Vektor Serangan: Mendukung 3 skenario serangan realistis:\n'
          '   • Serangan Brute Force: Menembakkan percobaan login gagal beruntun yang melampaui batas ambang batas (Threshold) dalam jendela waktu geser.\n'
          '   • Penyusupan Orang Tak Dikenal: Menyimulasikan login sukses dari IP asing di luar daftar putih (menghasilkan skor risiko 98/100).\n'
          '   • Injeksi Eksploitasi & WAF: Menyimulasikan muatan payload berbahaya seperti SQL Injection dan Path Traversal.\n'
          '3. Pengujian Menyeluruh (End-to-End): Menguji bunyi alarm OS, getaran, notifikasi pop-up (Heads-up banner), pencatatan telemetri langsung di Dashboard & Audit Explorer, serta analisis forensik insiden.',
      answerEn:
          'The Penetration Testing Lab feature in Settings allows administrators to safely simulate controlled cyber attacks to test AEGIS defense readiness without impacting production server workloads.\n\n'
          'Key Capabilities:\n'
          '1. Target Service Selection: Choose which monitored daemon to test, including OpenSSH (Port 22), MySQL/MariaDB (Port 3306), NGINX (Port 80/443), Apache, Redis, PHP-FPM, Pure-FTPd, or Ollama AI.\n'
          '2. Attack Vector Scenarios: Supports 3 realistic scenarios:\n'
          '   • Brute Force Attack: Dispatches a rapid burst of failed attempts breaching the policy threshold within the sliding time window.\n'
          '   • Unknown Person Intrusion: Simulates a successful login from an untrusted foreign IP (escalating immediately to Critical Risk 98/100).\n'
          '   • Exploit & Injection Probe: Simulates malicious payloads such as SQL Injection and Path Traversal.\n'
          '3. End-to-End Verification: Verifies device alarm sound, vibration, heads-up push notifications, real-time telemetry logging, and forensic dialog incident response.',
    ),

    // 9. Isolasi IP Perangkat vs IP Simulasi (Keamanan Operator)
    const FaqItem(
      id: 'faq_pentest_ip_isolation',
      category: FaqCategory.security,
      questionId: 'Apakah sistem mencatat IP perangkat saya saat Uji Penetrasi, atau hanya IP simulasi yang dipilih?',
      questionEn: 'Does the system record my actual device IP during Penetration Testing, or only the chosen simulated IP?',
      answerId:
          'Sistem HANYA mencatat IP simulasi yang Anda pilih (misalnya 185.220.101.99 dari Moskow), dan SAMA SEKALI TIDAK mencatat atau mengekspos IP perangkat asli Anda.\n\n'
          'Mengapa dan Bagaimana Cara Kerjanya?\n'
          '1. Isolasi Total (Zero Device Network Footprint): Simulasi berjalan dalam sandbox terisolasi pada mesin pertahanan AEGIS. Aplikasi tidak mengirim paket serangan nyata dari kartu jaringan (Wi-Fi/4G/LAN) perangkat Anda, sehingga alamat IP asli perangkat Anda 100% terlindungi dan tidak pernah dicatat.\n\n'
          '2. Perlindungan dari Terkunci Sendiri (Anti Self-Lockout): Semua log bukti, skor risiko, dan notifikasi dialamatkan secara eksklusif ke IP penyerang yang dipilih. Jika Anda menekan tombol "🛡️ Blokir IP" atau melakukan mitigasi firewall di modal Forensik, yang diblokir adalah IP penyerang simulasi tersebut—BUKAN IP perangkat Anda. Anda tidak akan pernah terkunci dari server Anda sendiri saat melakukan latihan keamanan.\n\n'
          '3. Pustaka 21+ IP Global & Opsi Kustom: Anda dapat memilih dari 21+ profil penyerang global (Rusia, Belanda, Ukraina, AS, Jerman, China, Korea, Indonesia, dll.) atau mengetik IP uji coba kustom Anda sendiri.',
      answerEn:
          'The system records ONLY the simulated threat IP you select (e.g. 185.220.101.99 from Moscow), and NEVER records, captures, or exposes your actual device IP address.\n\n'
          'Why and How It Works:\n'
          '1. Strict Sandboxed Isolation (Zero Device Network Footprint): The test runs within an isolated simulation sandbox. The app never emits malicious brute-force packets from your device adapter (Wi-Fi/cellular/LAN), so your device IP is 100% shielded and never entered into the threat ledger.\n\n'
          '2. Anti Self-Lockout Protection (Crucial Safety Feature): All generated telemetry logs, risk scores, and alert actions map exclusively to the chosen simulated IP. If you tap "🛡️ Block IP" or trigger firewall mitigation in the Forensics dialog, the firewall bans the simulated attacker IP—NEVER your own device IP. You will never accidentally lock yourself out of your server fleet.\n\n'
          '3. 21+ Global Threat Profiles & Custom IP: You can test across 21+ international threat origins or input any custom IP for internal compliance testing.',
    ),

    // 10. Pemasangan Server Agent & Otomatisasi Booting (Systemd & Reboot Survival)
    const FaqItem(
      id: 'faq_server_agent_deployment',
      category: FaqCategory.server,
      questionId: 'Bagaimana cara memasang Server Agent (aegis-agent) di VPS Linux? Apakah otomatis berjalan saat reboot?',
      questionEn: 'How do I deploy the Server Agent (aegis-agent) on a Linux VPS? Does it auto-run on reboot?',
      answerId:
          'Server Agent (aegis-agent) adalah daemon Python ringan (zero external dependencies) yang bertugas mengamati log SSH, MySQL, dan NGINX/Apache secara non-destruktif di VPS Anda.\n\n'
          'Apakah agen otomatis berjalan saat server di-reboot?\n'
          'YA! Agen 100% otomatis berjalan saat booting server jika Anda mendaftarkannya dengan systemd (perintah "systemctl enable").\n\n'
          'Mengapa Otomatis Berjalan Tanpa Perlu Cronjob?\n'
          '• Berkat deklarasi [Install] WantedBy=multi-user.target pada file aegis-agent.service, systemd secara native mengaitkan agen ke runlevel booting server Anda.\n'
          '• Urutan Booting Tepat: Agen diatur berjalan setelah layanan jaringan, SSH, dan database siap (After=network.target mysqld.service sshd.service).\n'
          '• Pemulihan Crash Otomatis (Self-Healing): Dengan aturan Restart=always dan RestartSec=5, jika proses agen mati karena kehabisan memori (OOM) atau crash tak terduga, Linux kernel/systemd otomatis menyalakannya kembali dalam 5 detik.\n\n'
          'Langkah-Langkah Pemasangan di Server (Lengkap & Teruji):\n'
          '1. Salin berkas agen ke direktori /opt/aegis-agent di server.\n'
          '2. Buat file konfigurasi config.json dari template config.example.json.\n'
          '3. Pasang file service ke /etc/systemd/system/aegis-agent.service.\n'
          '4. Muat ulang daemon dan aktifkan auto-start: sudo systemctl daemon-reload && sudo systemctl enable --now aegis-agent.service.\n'
          '5. Verifikasi bahwa statusnya "active (running)" dan auto-boot bernilai "enabled".',
      answerEn:
          'The Server Agent (aegis-agent) is a lightweight, zero-dependency Python daemon that non-destructively tails OpenSSH, MySQL, and NGINX/Apache logs to detect brute-force incursions and unknown person logins.\n\n'
          'Does the agent automatically run when the server restarts?\n'
          'YES! The agent automatically launches on system boot when enabled via systemd ("systemctl enable").\n\n'
          'Why Does It Auto-Run Without Requiring a Cron Job?\n'
          '• Declared Target: The service unit specifies [Install] WantedBy=multi-user.target, which integrates directly into Linux system init targets.\n'
          '• Dependency Ordering: Configured with After=network.target mysqld.service sshd.service so it initiates seamlessly once networking and critical daemons are up.\n'
          '• Automatic Crash Recovery (Self-Healing): Governed by Restart=always and RestartSec=5. If the Python process terminates abnormally or gets evicted by an OOM killer, systemd resurrects it automatically within 5 seconds.\n\n'
          'Deployment Steps (Tested & Production Ready):\n'
          '1. Copy agent files to /opt/aegis-agent on your VPS.\n'
          '2. Instantiate config.json from config.example.json.\n'
          '3. Install the systemd unit into /etc/systemd/system/aegis-agent.service.\n'
          '4. Enable and start: sudo systemctl daemon-reload && sudo systemctl enable --now aegis-agent.service.\n'
          '5. Validate with "systemctl status aegis-agent" and "systemctl is-enabled aegis-agent".',
      codeSnippetTitleId: 'Panduan Perintah Terminal Pemasangan Server Agent (SSH)',
      codeSnippetTitleEn: 'Server Agent Deployment Terminal Commands (SSH)',
      codeSnippets: [
        '# 1. Buat direktori dan salin file agen ke /opt/aegis-agent:\n'
            'sudo mkdir -p /opt/aegis-agent\n'
            'cd /opt/aegis-agent\n'
            '# (Salin aegis_agent.py, config.example.json, dan aegis-agent.service)\n\n'
            '# 2. Buat konfigurasi server aktif & unduh Google Service Account key:\n'
            'sudo cp config.example.json config.json\n'
            'sudo chmod 600 config.json\n'
            '# Unggah service_account.json dari Firebase Console ke /opt/aegis-agent/service_account.json\n'
            'sudo chmod 600 service_account.json\n'
            'sudo nano config.json  # Pastikan server_id, service_account_file, dan fcm_topic sesuai\n\n'
            '# 3. Pasang Systemd Unit File:\n'
            'sudo cp aegis-agent.service /etc/systemd/system/\n'
            'sudo chmod 644 /etc/systemd/system/aegis-agent.service\n\n'
            '# 4. Muat ulang daemon, aktifkan auto-start saat reboot, dan jalankan sekarang:\n'
            'sudo systemctl daemon-reload\n'
            'sudo systemctl enable --now aegis-agent.service\n\n'
            '# 5. Verifikasi status berjalan & auto-start saat reboot:\n'
            'sudo systemctl status aegis-agent\n'
            'sudo systemctl is-enabled aegis-agent   # Output harus: "enabled"\n\n'
            '# 6. Pantau log telemetri secara live:\n'
            'sudo journalctl -u aegis-agent -f\n\n'
            '# 7. Cara Menghapus/Uninstall Service (Reset Bersih):\n'
            'sudo systemctl stop aegis-agent.service\n'
            'sudo systemctl disable aegis-agent.service\n'
            'sudo rm -f /etc/systemd/system/aegis-agent.service\n'
            'sudo systemctl daemon-reload\n'
            'sudo systemctl reset-failed\n'
            'sudo rm -rf /opt/aegis-agent',
      ],
    ),

    // 11. Perbandingan Systemd vs Cronjob & Watchdog Fallback
    const FaqItem(
      id: 'faq_agent_cron_comparison',
      category: FaqCategory.server,
      questionId: 'Apakah kita butuh Cronjob untuk aegis-agent? Kapan cronjob digunakan?',
      questionEn: 'Do we need a Cron Job for aegis-agent? When should cron be used?',
      answerId:
          'Apakah cronjob wajib? TIDAK untuk server Linux modern.\n\n'
          'Mengapa Systemd Jauh Lebih Baik daripada Cronjob?\n'
          '1. Pemantauan PID Berkelanjutan: Cronjob tradisional hanya mengeksekusi perintah pada interval tertentu dan tidak mengetahui jika program crash 2 menit kemudian. Systemd mengawasi proses secara terus-menerus (real-time).\n'
          '2. Booting Cerdas Berdasarkan Dependensi: Systemd menunggu jaringan dan log sistem siap sebelum menjalankan agen, sedangkan cronjob @reboot dapat gagal jika dijalankan terlalu dini saat network belum naik.\n'
          '3. Isolasi Resource & Logging Terpusat: Semua log keluaran agen otomatis masuk ke systemd journal (journalctl), sehingga Anda tidak perlu repot mengelola rotasi file log manual.\n\n'
          'Kapan Cronjob Sebaiknya Digunakan?\n'
          '• Skenario 1 - Watchdog Cadangan (Defense-in-Depth):\n'
          '  Bagi administrator yang menginginkan jaminan berlapis ekstra, cronjob 1-menit dapat dipasang untuk memeriksa apakah service aktif, dan otomatis menyalakannya kembali jika mati.\n'
          '• Skenario 2 - Lingkungan Tanpa Systemd (Shared Hosting / Container Lama):\n'
          '  Jika server Anda adalah hosting cPanel tanpa akses root systemctl atau container OpenVZ lama, Anda dapat menggunakan direktif @reboot di crontab untuk menjalankan agen di latar belakang.',
      answerEn:
          'Is a cron job mandatory? NO for modern Linux server environments.\n\n'
          'Why Systemd is Superior to Cron for Long-Running Daemons:\n'
          '1. Continuous PID Supervision: Standard cron fires on a static schedule and is blind if the daemon crashes mid-interval. Systemd monitors the PID every millisecond.\n'
          '2. Dependency-Aware Boot: Systemd waits until networking, DNS, and logging sockets are active. A naive "@reboot" cron often fails because it triggers before network interfaces initialize.\n'
          '3. Centralized Journald Logging: Console stdout/stderr streams cleanly into journalctl with automatic timestamping and rotation.\n\n'
          'When SHOULD You Use a Cron Job?\n'
          '• Scenario 1 - Watchdog Safety Net (Defense-in-Depth):\n'
          '  Administrators desiring dual redundancy can configure a 1-minute crontab watchdog that queries "systemctl is-active" and starts the service if it ever goes down.\n'
          '• Scenario 2 - Non-Systemd Environments (Shared Hosting / Legacy Containers):\n'
          '  If operating on cPanel shared hosting or legacy virtualization lacking systemd privileges, use crontab "@reboot" to spawn the agent in background.',
      codeSnippetTitleId: 'Konfigurasi Watchdog Cronjob & Alternatif Crontab',
      codeSnippetTitleEn: 'Watchdog Cronjob & Alternative Crontab Setup',
      codeSnippets: [
        '# PILIHAN A: Watchdog Cronjob Cadangan (Setiap 1 menit periksa status systemd):\n'
            '# Buka crontab root:\n'
            'sudo crontab -e\n'
            '# Tambahkan baris berikut:\n'
            '* * * * * systemctl is-active --quiet aegis-agent || systemctl start aegis-agent\n\n'
            '# PILIHAN B: Alternatif untuk Server Tanpa Systemd (cPanel / OpenVZ legacy):\n'
            '# Buka crontab:\n'
            'crontab -e\n'
            '# Tambahkan auto-start saat reboot:\n'
            '@reboot /usr/bin/python3 /opt/aegis-agent/aegis_agent.py >> /var/log/aegis-agent.log 2>&1 &\n'
            '# Tambahkan watchdog 5-menitan:\n'
            '*/5 * * * * pgrep -f aegis_agent.py >/dev/null || (/usr/bin/python3 /opt/aegis-agent/aegis_agent.py >> /var/log/aegis-agent.log 2>&1 &)',
      ],
    ),

    // 12. Terminal SSH Interaktif
    const FaqItem(
      id: 'faq_ssh_terminal',
      category: FaqCategory.server,
      questionId: 'Bagaimana cara menggunakan Terminal SSH Interaktif di Aegis? Apa saja fiturnya?',
      questionEn: 'How to use the Interactive SSH Terminal in Aegis? What features are included?',
      answerId:
          'Terminal SSH Interaktif Aegis dirancang untuk memberikan pengalaman shell server sekelas desktop/workstation langsung dari dalam aplikasi mobile maupun desktop.\n\n'
          '1. Cara Mengakses Terminal:\n'
          '• Buka menu "Armada Server & Vault".\n'
          '• Pada kartu server yang dituju, ketuk tombol "TERMINAL" (berwarna cyan).\n'
          '• Sistem otomatis menggunakan kredensial (Password atau Private Key) yang tersimpan aman di SecureVault. Jika server mengaktifkan 2FA, dialog verifikasi interaktif akan muncul secara mulus.\n\n'
          '2. Kemampuan TUI & Hardware-Accelerated Virtual Terminal:\n'
          '• Didukung oleh mesin xterm-256color dengan buffer sel virtual penuh dan rendering ANSI TrueColor.\n'
          '• Mendukung aplikasi interaktif curses layar penuh (TUI) seperti htop, top, nano, vim, mc, dan tmux tanpa artefak escape code atau teks bertumpuk.\n'
          '• PTY Window Resizing Dinamis: Secara otomatis mengirim sinyal SIGWINCH ke remote process saat orientasi layar ponsel diputar atau ukuran jendela desktop diubah.\n\n'
          '3. Bilah Tombol Virtual (Virtual Key Ribbon):\n'
          '• Dirancang khusus untuk kemudahan pengetikan di layar sentuh ponsel tanpa keyboard fisik:\n'
          '  - Tombol kontrol: ESC, Ctrl+C, Tab, Ctrl+D, Ctrl+Z, Ctrl+L.\n'
          '  - Navigasi kursor: ▲ Atas, ▼ Bawah, ◀ Kiri, ▶ Kanan, Home, End, PgUp, PgDn.\n'
          '  - Pintasan SecOps: sudo dan | grep untuk menyisipkan perintah secara instan.\n\n'
          '4. Bilah Perintah Cepat SecOps:\n'
          '• Akses 1-ketukan untuk perintah audit harian:\n'
          '  - htop (monitor proses live)\n'
          '  - aegis status (status agen telemetri)\n'
          '  - fail2ban (status fail2ban-client)\n'
          '  - auth log (pantau log login SSH)\n'
          '  - uptime, disk (df), memory (free), docker ps, firewall (iptables), dan netstat.\n\n'
          '5. Tema & Antarmuka Responsif:\n'
          '• 4 Pilihan Tema Cyber: Cyber OLED (Cyan/Pink Neon), Matrix Green (CRT Phosphor), Monokai Pro, dan Nord Glacier.\n'
          '• Menu Tiga Titik Responsif di Ponsel: Pada layar sempit, opsi tema, layar penuh (fullscreen mode), perbesar/perkecil font (A+/A-), hubungkan ulang, bersihkan layar, dan salin log dikelompokkan rapi ke menu pop-up.',
      answerEn:
          'The Aegis Interactive SSH Terminal delivers a workstation-grade remote shell experience directly on mobile and desktop platforms.\n\n'
          '1. Accessing the Terminal:\n'
          '• Navigate to the "Server Fleet & Vault" screen.\n'
          '• On the desired server card, tap the cyan "TERMINAL" button.\n'
          '• Aegis automatically authenticates using credentials stored in SecureVault (Password or Passphrase-encrypted Key). If 2FA is active, an interactive challenge dialog prompt appears.\n\n'
          '2. Hardware-Accelerated Virtual Terminal & Curses Support:\n'
          '• Powered by xterm-256color virtual cell buffers with ANSI TrueColor rendering.\n'
          '• Flawlessly runs full-screen interactive curses/TUI tools including htop, top, nano, vim, mc, and tmux with zero broken escape characters or garbled lines.\n'
          '• Dynamic PTY Geometry Resizing: Automatically transmits SIGWINCH signals to remote processes upon window resize or phone rotation.\n\n'
          '3. Virtual Control Key Ribbon:\n'
          '• Ergonomic touch ribbon optimized for mobile touchscreens without hardware keyboards:\n'
          '  - Control keys: ESC, Ctrl+C, Tab, Ctrl+D, Ctrl+Z, Ctrl+L.\n'
          '  - Directional navigation: ▲ Up, ▼ Down, ◀ Left, ▶ Right, Home, End, PgUp, PgDn.\n'
          '  - SecOps helpers: sudo and | grep for rapid command composition.\n\n'
          '4. SecOps Quick Command Toolbar:\n'
          '• 1-tap buttons for essential sysadmin diagnostics:\n'
          '  - htop (real-time process tree)\n'
          '  - aegis status (telemetry daemon status)\n'
          '  - fail2ban (jail telemetry)\n'
          '  - auth log (stream authentication logs)\n'
          '  - uptime, disk (df), memory (free), docker ps, firewall (iptables), and netstat.\n\n'
          '5. Cyber Themes & Responsive Layout:\n'
          '• 4 High-Contrast Themes: Cyber OLED (Neon Cyan/Pink), Matrix Green (Phosphor CRT), Monokai Pro, and Nord Glacier.\n'
          '• Compact Mobile Triple-Dot Menu: On smartphones, theme pickers, fullscreen mode, font scaling (A+/A-), reconnect, console clear, and log clipboard export are neatly organized in a popup menu.',
      codeSnippetTitleId: 'Perintah Diagnostik Cepat Terminal Aegis',
      codeSnippetTitleEn: 'Aegis Terminal Quick Diagnostic Commands',
      codeSnippets: [
        '# 1. Jalankan visual monitor proses:\n'
            'htop\n\n'
            '# 2. Periksa status pengawasan Fail2ban:\n'
            'sudo fail2ban-client status\n\n'
            '# 3. Pantau log servis agen Aegis secara live:\n'
            'sudo journalctl -u aegis-agent -f\n\n'
            '# 4. Pantau percobaan autentikasi SSH secara live:\n'
            'sudo tail -f /var/log/auth.log   # Debian / Ubuntu\n'
            'sudo tail -f /var/log/secure     # RHEL / CentOS / Rocky',
      ],
    ),

    // 13. SFTP File Manager & In-App Config Editor
    const FaqItem(
      id: 'faq_sftp_file_manager',
      category: FaqCategory.server,
      questionId: 'Bagaimana cara menggunakan fitur SFTP File Manager di Aegis?',
      questionEn: 'How to use the SFTP File Manager in Aegis?',
      answerId:
          'Fitur SFTP (Secure File Transfer Protocol) di Aegis menyediakan penjelajah berkas jarak jauh (remote file manager) yang aman, cepat, dan terintegrasi langsung dengan armada server Anda.\n\n'
          '1. Cara Mengakses SFTP:\n'
          '• Buka layar "Armada Server & Vault".\n'
          '• Pada kartu server yang ingin dikelola, ketuk tombol "SFTP" (berwarna ungu) yang terletak persis di sebelah tombol "TERMINAL".\n'
          '• Sesi SFTP aman dibangun secara otomatis menggunakan kredensial SSH yang tersimpan di SecureVault.\n\n'
          '2. Navigasi & Bookmark Cepat:\n'
          '• Bilah Breadcrumb Interaktif: Ketuk segmen folder mana pun di bilah atas untuk melompat langsung ke direktori tersebut.\n'
          '• Lompat ke Path (Jump to Path): Ketuk ikon pin lokasi untuk mengetik path absolut atau memilih Bookmark Cepat: Root (/), Home (/home/user), Konfigurasi (/etc), Log (/var/log), Web (/var/www), atau Temp (/tmp).\n'
          '• Navigasi Induk: Ketuk baris ".." di bagian atas daftar untuk naik satu tingkat direktori.\n\n'
          '3. Pencarian & Pengurutan Berkas:\n'
          '• Bilah filter pencarian live untuk menyaring berkas berdasarkan nama atau ekstensi secara instan.\n'
          '• Pengurutan multi-atribut (naik/turun) berdasarkan Nama, Ukuran, Tanggal Modifikasi, dan Tipe Ekstensi.\n'
          '• Tombol Sakelar Dotfiles: Menampilkan atau menyembunyikan berkas/folder tersembunyi yang berawalan titik (.).\n\n'
          '4. Unggah & Unduh Berkas:\n'
          '• Unggah Berkas: Ketuk tombol floating action "UNGGAH BERKAS" atau menu opsi untuk memilih berkas dari perangkat lokal dan mengunggahnya ke server.\n'
          '• Unduh Berkas: Buka menu titik tiga pada berkas remote mana pun dan pilih "Unduh Berkas" untuk menyimpannya ke penyimpanan lokal atau folder Downloads.\n\n'
          '5. Editor Teks Jarak Jauh Bawaan (In-App Remote Editor):\n'
          '• Buka dan edit file teks/skrip/konfigurasi (seperti nginx.conf, .env, script .sh, .py, .log) langsung di dalam Aegis.\n'
          '• Dilengkapi penomoran baris, font monospace ramah kode, dan tombol "Simpan" untuk menulis kembali perubahan ke server secara real-time.\n\n'
          '6. Manajemen Direktori & Pintasan Terminal:\n'
          '• Buat Folder Baru (mkdir) dan Berkas Kosong Baru langsung dari menu tindakan.\n'
          '• Ganti Nama (rename) dan Hapus (delete) berkas/folder dengan dialog konfirmasi keamanan.\n'
          '• Periksa izin Unix (drwxr-xr-x dan oktal 0755), pemilik (UID/GID), ukuran, dan waktu modifikasi terakhir.\n'
          '• Beralih ke Terminal: Ketuk ikon terminal di app bar untuk beralih instan ke sesi konsol SSH di server yang sama.',
      answerEn:
          'The SFTP (Secure File Transfer Protocol) feature in Aegis provides a high-performance, hardened remote file manager directly integrated with your server fleet.\n\n'
          '1. Accessing SFTP:\n'
          '• Navigate to the "Server Fleet & Vault" screen.\n'
          '• On the target server card, tap the purple "SFTP" button located right beside the "TERMINAL" button.\n'
          '• An encrypted SFTP session initializes using your stored credentials from SecureVault.\n\n'
          '2. Breadcrumb Navigation & Quick Bookmarks:\n'
          '• Interactive Breadcrumb Bar: Tap any directory segment along the top path to jump directly to that hierarchy level.\n'
          '• Jump to Path: Tap the path pin icon to enter an absolute path or select Quick Bookmarks such as Root (/), Home (/home/user), Configs (/etc), Logs (/var/log), Web Root (/var/www), or Temporary (/tmp).\n'
          '• Parent Directory Navigation: Tap the ".." row at the top of the file list to traverse upward.\n\n'
          '3. Live Search & Multi-Attribute Sorting:\n'
          '• Real-time search filter bar to instantly narrow down files by filename or extension.\n'
          '• Sort ascending or descending by Name, File Size, Modification Date, and Extension Type.\n'
          '• Dotfile Visibility Toggle: Seamlessly show or hide hidden files and directories prefixed with a dot (.).\n\n'
          '4. File Upload & Download:\n'
          '• Upload Files: Tap the "UPLOAD FILE" floating action button or the action menu to pick local files and stream them to the current remote directory.\n'
          '• Download Files: Tap the contextual action menu on any remote file and select "Download File" to save it locally.\n\n'
          '5. In-App Remote Text & Config Editor:\n'
          '• View and edit configuration files, shell scripts, logs, and environment variables (e.g., nginx.conf, .env, firewall.sh) directly inside Aegis.\n'
          '• Features line numbering, monospace typography, and a "Save" button to write changes back to the remote server over SFTP.\n\n'
          '6. File & Directory Management & Terminal Shortcut:\n'
          '• Create New Folders (mkdir) and New Text Files directly from the action bar.\n'
          '• Rename and Delete files or directories with built-in safety confirmation dialogs.\n'
          '• Detailed File Inspection: View Unix permissions (drwxr-xr-x & octal 0755), ownership (UID/GID), byte size, and last modified timestamps.\n'
          '• Rapid Terminal Jump: Tap the terminal icon in the app bar to switch directly into an interactive SSH console on the same node.',
      codeSnippetTitleId: 'Operasi & Izin Berkas SFTP yang Sering Digunakan',
      codeSnippetTitleEn: 'Common SFTP & File Permission Commands',
      codeSnippets: [
        '# 1. Izin berkas konfigurasi standar (baca/tulis root, hanya baca lainnya):\n'
            'chmod 644 /etc/nginx/nginx.conf\n\n'
            '# 2. Izin berkas skrip shell yang dapat dieksekusi:\n'
            'chmod 755 /usr/local/bin/firewall.sh\n\n'
            '# 3. Izin ketat untuk private key dan file rahasia (.env / id_rsa):\n'
            'chmod 600 /var/www/app/.env\n\n'
            '# 4. Ubah kepemilikan direktori web server:\n'
            'sudo chown -R www-data:www-data /var/www/html',
      ],
    ),

    // 14. Uji Penetrasi vs Pemblokiran Otomatis Fail2ban & IP Ban List
    const FaqItem(
      id: 'faq_pentest_fail2ban_auto_ban',
      category: FaqCategory.security,
      questionId: 'Apakah Uji Penetrasi otomatis membuat Fail2ban memblokir IP dan memasukkannya ke IP Ban List?',
      questionEn: 'Does the Penetration Test automatically trigger Fail2ban to ban the IP and add it to the IP Ban List?',
      answerId:
          'Jawaban Singkat: TIDAK otomatis terblokir saat pengujian berjalan, tetapi Anda dapat memblokirnya ke Fail2ban dengan SATU KETUKAN (1-Tap Mitigation) setelah pengujian selesai.\n\n'
          'Penjelasan Detail Cara Kerjanya:\n\n'
          '1. Saat Simulasi Uji Penetrasi Berjalan (Sandbox Aman):\n'
          '   • Uji penetrasi di AEGIS dirancang sebagai simulasi sandbox terisolasi. Tujuannya adalah menguji kesiapan sirine alarm sistem, notifikasi pop-up, grafik timeline ancaman, dan alur investigasi forensik tanpa membanjiri jaringan VPS atau menyebabkan downtime.\n'
          '   • Fail2ban di server TIDAK otomatis memblokir IP saat simulasi berjalan karena simulasi tidak menembakkan paket brute-force mentah yang membebani port fisik server.\n'
          '   • IP Asli Perangkat Anda 100% Aman: Alamat IP fisik komputer/ponsel Anda tidak pernah dimasukkan ke daftar ancaman sehingga Anda tidak akan pernah terkunci dari server Anda sendiri.\n\n'
          '2. Cara Memasukkan IP ke Fail2ban & IP Ban List (Mitigasi Cepat 1-Ketukan):\n'
          '   • Setelah simulasi selesai, alarm berbunyi dan muncul banner dengan tombol "FORENSIK".\n'
          '   • Tekan tombol "FORENSIK", lalu ketuk tombol "🛡️ BLOKIR IP".\n'
          '   • Seketika itu juga, AEGIS melakukan dua hal:\n'
          '     a. Menyimpan IP penyerang simulasi ke Daftar IP Diblokir lokal (SecureVault).\n'
          '     b. Mengirimkan perintah SSH terenkripsi ke server untuk memblokir IP secara nyata di Fail2ban dan iptables kernel Linux:\n'
          '        - sudo fail2ban-client set [jail] banip [IP]\n'
          '        - sudo iptables -I INPUT -s [IP] -j DROP\n'
          '   • Kini IP tersebut resmi diblokir di firewall server dan tercatat di IP Ban List.\n\n'
          '3. Bagaimana Jika Terjadi Serangan Nyata dari Luar (Bukan Simulasi)?\n'
          '   • Jika penyerang sungguhan (misal botnet atau scanner eksternal) menembakkan login gagal ke server Anda, Fail2ban di VPS otomatis memblokir IP tersebut setelah melampaui batas maxretry.\n'
          '   • Hook tindakan Fail2ban (scripts/fail2ban_aegis.conf) akan langsung mengirim notifikasi FCM ke aplikasi AEGIS Anda secara real-time.',
      answerEn:
          'Short Answer: NO, not automatically during the test execution, but you can enforce a real server ban with a SINGLE TAP (1-Tap Mitigation) immediately after the test completes.\n\n'
          'Detailed Operational Breakdown:\n\n'
          '1. During the Penetration Test (Safe Isolated Sandbox):\n'
          '   • The AEGIS Penetration Testing Lab operates in an isolated client-side defense sandbox. Its purpose is to verify your alarm sirens, heads-up push alerts, risk scoring, and forensic response without bombarding your VPS with network flood packets or causing downtime.\n'
          '   • Fail2ban on the live server does NOT ban the IP automatically during the run because no raw abusive TCP packets were dispatched over the wire.\n'
          '   • Zero Risk to Your Device: Your physical device IP (Wi-Fi/LAN/cellular) is never touched, preventing accidental self-lockouts.\n\n'
          '2. Adding the Attacker IP to Fail2ban & the Ban List (1-Tap Mitigation):\n'
          '   • When the test finishes, an alarm sounds and a floating banner displays a "FORENSICS" action button.\n'
          '   • Open the Forensics dialog and click "🛡️ BLOCK IP".\n'
          '   • AEGIS instantly executes two actions:\n'
          '     a. Catalogs the threat IP into the encrypted local Banned IP Registry in SecureVault.\n'
          '     b. Issues real, authenticated SSH firewall commands directly to the server kernel:\n'
          '        - sudo fail2ban-client set [jail] banip [IP]\n'
          '        - sudo iptables -I INPUT -s [IP] -j DROP\n'
          '   • The IP is now actively blocked in Fail2ban and listed in your Policy Ban List.\n\n'
          '3. What Happens During Real External Attacks (Outside the App)?\n'
          '   • Real attackers sending failed credentials over the Internet trigger server auth logs (/var/log/secure, mysqld.log).\n'
          '   • Fail2ban AUTOMATICALLY bans their IP once failures exceed the maxretry threshold within findtime.\n'
          '   • The Fail2ban dispatcher hook (scripts/fail2ban_aegis.conf) transmits instant high-priority FCM push alerts to your AEGIS devices.',
      codeSnippetTitleId: 'Perintah Eksekusi & Pengecekan Fail2ban di Server',
      codeSnippetTitleEn: 'Fail2ban Execution & Inspection Commands on Server',
      codeSnippets: [
        '# 1. Perintah yang dikirimkan AEGIS ke server saat Anda menekan "BLOKIR IP":\n'
            'sudo fail2ban-client set sshd banip <IP_PENYERANG>\n'
            'sudo fail2ban-client set mysqld-auth banip <IP_PENYERANG>\n'
            'sudo iptables -I INPUT -s <IP_PENYERANG> -j DROP\n\n'
            '# 2. Periksa daftar IP yang sedang diblokir oleh Fail2ban di server:\n'
            'sudo fail2ban-client status sshd\n'
            'sudo fail2ban-client status mysqld-auth\n\n'
            '# 3. Buka blokir IP jika diperlukan (Unban):\n'
            'sudo fail2ban-client set sshd unbanip <IP_PENYERANG>\n'
            'sudo iptables -D INPUT -s <IP_PENYERANG> -j DROP',
      ],
    ),
    // 13. Integrasi Intelijen Ancaman AbuseIPDB
    const FaqItem(
      id: 'faq_threat_intel_abuseipdb',
      category: FaqCategory.security,
      questionId: 'Bagaimana cara kerja Integrasi Intelijen Ancaman AbuseIPDB di Forensik Insiden AEGIS?',
      questionEn: 'How does the AbuseIPDB Threat Intelligence Integration work in AEGIS Incident Forensics?',
      answerId:
          'AEGIS terintegrasi langsung dengan database intelijen siber global AbuseIPDB v2 untuk memperkaya setiap investigasi forensik insiden keamanan dengan reputasi real-time:\n\n'
          '1. Apa Saja Informasi yang Diberikan AbuseIPDB?\n'
          '   • Abuse Confidence Score (0 - 100%): Tingkat kepastian bahwa IP tersebut merupakan sumber serangan aktif (brute force, exploit probe, atau DDoS).\n'
          '   • Riwayat Pelaporan Komunitas: Total jumlah laporan insiden yang dicatat oleh para analis keamanan di seluruh dunia serta rentang waktu pelaporan terbaru.\n'
          '   • Karakteristik Jaringan & ASN: Mendeteksi apakah IP tersebut merupakan Tor Exit Node, infrastruktur Botnet Command & Control (C2), atau jaringan hosting cloud/data center.\n'
          '   • Whitelist Recognition: Mengidentifikasi IP resmi organisasi terpercaya seperti Google DNS atau Cloudflare.\n\n'
          '2. Mode Evaluasi vs Live Telemetry:\n'
          '   • Mode Tanpa Key (Simulasi/Evaluasi): Jika Anda belum memasukkan API key, AEGIS menggunakan generator telemetri heuristik cerdas untuk simulasi lab uji penetrasi.\n'
          '   • Mode Live Telemetry: Ketika API key dipasang, AEGIS melakukan kueri langsung via HTTPS terenkripsi ke endpoint https://api.abuseipdb.com/api/v2/check.\n'
          '   • IP Lokal / Privat: Alamat IP intranet (127.0.0.1, 192.168.x.x, 10.x.x.x, 172.16-31.x.x) otomatis dikenali sebagai subnet privat RFC 1918 tanpa kueri keluar.\n\n'
          '3. Cara Memasang API Key Gratis:\n'
          '   • Akun AbuseIPDB gratis menyediakan kuota 1.000 kueri/hari (sangat cukup untuk operasional harian).\n'
          '   • Registrasi akun gratis di https://www.abuseipdb.com/register, buka menu "API", lalu salin Key Anda.\n'
          '   • Masukkan Key di menu Pengaturan > Intelijen Ancaman atau langsung melalui tombol "Atur Key" di jendela Forensik Insiden.\n'
          '   • Key disimpan dengan enkripsi AES-256 di Secure Vault perangkat Anda.',
      answerEn:
          'AEGIS integrates natively with the AbuseIPDB v2 global cyber intelligence database to enrich every incident forensic investigation with real-time threat reputation:\n\n'
          '1. Key Telemetry Provided by AbuseIPDB:\n'
          '   • Abuse Confidence Score (0 - 100%): Probability that the querying IP is an active source of malicious activity (brute force, exploit scanner, or botnet).\n'
          '   • Global Abuse Reports: Cumulative community reports filed by security engineers worldwide, including distinct reporter counts and latest report timestamps.\n'
          '   • Autonomous Network Attributes: Automatically flags Tor Exit Nodes, Botnet C2 nodes, bulletproof hostings, and public cloud transit.\n'
          '   • Official Whitelist Identification: Confirms benign enterprise infrastructure like Google or Cloudflare.\n\n'
          '2. Evaluation Mode vs Live API Mode:\n'
          '   • Keyless / Simulation Mode: If no key is configured, AEGIS employs an intelligent heuristic simulation generator for penetration testing lab scenarios.\n'
          '   • Live API Mode: With a valid API key, AEGIS queries the official REST endpoint https://api.abuseipdb.com/api/v2/check with TLS 1.3 encryption.\n'
          '   • Internal & Private Subnets: Addresses in RFC 1918 ranges (10.x, 192.168.x, 172.16-31.x) and loopback are instantly recognized as private subnets.\n\n'
          '3. Obtaining and Configuring Your Free API Key:\n'
          '   • Free AbuseIPDB accounts provide 1,000 queries per day.\n'
          '   • Register at https://www.abuseipdb.com/register, navigate to "API", and copy your personal Key.\n'
          '   • Save the key via Settings > Threat Intelligence or directly via the "Set Up Key" button in any Forensics Dialog.\n'
          '   • Keys are stored securely in local hardware AES-256 Secure Vault storage.',
      codeSnippetTitleId: 'Pengujian Manual API AbuseIPDB via Terminal Linux',
      codeSnippetTitleEn: 'Manual AbuseIPDB API Test via Linux Terminal',
      codeSnippets: [
        '# Kueri manual reputasi IP menggunakan curl dan API Key Anda:\n'
            'curl -G https://api.abuseipdb.com/api/v2/check \\\n'
            '  --data-urlencode "ipAddress=185.220.101.99" \\\n'
            '  -d maxAgeInDays=90 \\\n'
            '  -d verbose=true \\\n'
            '  -H "Key: <API_KEY_ANDA>" \\\n'
            '  -H "Accept: application/json"',
      ],
    ),
    // 14. Pemindai Kepatuhan & Hardening Sistem (CIS Benchmark)
    const FaqItem(
      id: 'faq_system_hardening_compliance',
      category: FaqCategory.security,
      questionId: 'Bagaimana cara kerja fitur "Pemindai Hardening & Kepatuhan Sistem" (CIS Benchmark)?',
      questionEn: 'How does the "System Hardening & Compliance Scanner" (CIS Benchmark) feature work?',
      answerId:
          'Fitur Pemindai Hardening & Kepatuhan Sistem di AEGIS melakukan audit komprehensif terhadap konfigurasi keamanan server Linux Anda berdasarkan standar industri (CIS Benchmark, NIST SP 800-123, dan OpenSSH Hardening Guidelines):\n\n'
          '1. Cakupan 17 Pengujian Keamanan dalam 5 Kategori:\n'
          '   • OpenSSH Server:\n'
          '     - Larangan Login Langsung Root (PermitRootLogin no/prohibit-password)\n'
          '     - Larangan Autentikasi Password Polos (PasswordAuthentication no, wajib SSH Key)\n'
          '     - Batasan Percobaan Autentikasi Maksimal (MaxAuthTries <= 4)\n'
          '     - Penonaktifan X11 Forwarding (X11Forwarding no)\n'
          '   • Kernel Linux & Sysctl:\n'
          '     - Pengacakan Ruang Alamat Memori Penuh (ASLR: kernel.randomize_va_space = 2)\n'
          '     - Perlindungan Terhadap Serangan SYN Flood (net.ipv4.tcp_syncookies = 1)\n'
          '     - Penolakan Paket Pengalihan ICMP (net.ipv4.conf.all.accept_redirects = 0)\n'
          '     - Penonaktifan Routing Sumber IP (net.ipv4.conf.all.accept_source_route = 0)\n'
          '     - Filter Jalur Terbalik / Anti-Spoofing (net.ipv4.conf.all.rp_filter = 1)\n'
          '   • Jaringan & Firewall:\n'
          '     - Verifikasi Layanan Fail2ban Aktif dan Berjalan\n'
          '     - Deteksi Port Rentan Legacy Tanpa Enkripsi (Telnet port 23, FTP port 21)\n'
          '     - Pembatasan Port Database MySQL ke Loopback (127.0.0.1)\n'
          '   • Identitas & Kredensial Pengguna:\n'
          '     - Verifikasi Tidak Ada Hash Password Kosong di /etc/shadow\n'
          '     - Verifikasi Akun Superuser Root Tunggal (Hanya 1 akun dengan UID 0)\n'
          '   • Keamanan Sistem Berkas (Filesystem):\n'
          '     - Izin Akses Ketat Berkas Rahasia /etc/shadow (chmod 0000 atau 0640)\n'
          '     - Izin Akses Ketat Berkas Konfigurasi /etc/ssh/sshd_config (chmod 0600)\n\n'
          '2. Sistem Penilaian & Grade Keamanan:\n'
          '   • Skor dihitung dengan pembobotan tingkat keparahan (Critical: 20 poin, High: 10 poin, Medium: 5 poin, Low: 2 poin).\n'
          '   • Grade Keamanan: A+ (95-100%), A (85-94%), B (70-84%), C (50-69%), F (<50%).\n\n'
          '3. Playbook Remediasi Otomatis (1-Tap Fix):\n'
          '   • AEGIS secara cerdas merangkum seluruh temuan kegagalan dan peringatan menjadi skrip bash mandiri ("set -euo pipefail").\n'
          '   • Anda dapat menyalin dan mengeksekusi skrip tersebut langsung di server atau melalui terminal SSH terintegrasi untuk mencapai skor Grade A+ seketika.\n\n'
          '4. Ekspor Laporan Audit Markdown:\n'
          '   • Salin laporan audit berformat Markdown terstruktur untuk kebutuhan dokumentasi audit kepatuhan ISO 27001, SOC 2, atau laporan DevSecOps tim Anda.',
      answerEn:
          'The System Hardening & Compliance Scanner in AEGIS executes comprehensive security posture audits against your Linux server based on industry benchmarks (CIS Benchmark, NIST SP 800-123, and OpenSSH Hardening Guidelines):\n\n'
          '1. Scope of 17 Security Benchmarks Across 5 Categories:\n'
          '   • OpenSSH Server Hardening:\n'
          '     - Prohibit direct root login (PermitRootLogin no/prohibit-password)\n'
          '     - Disable cleartext password authentication (PasswordAuthentication no, key-only)\n'
          '     - Restrict maximum authentication attempts (MaxAuthTries <= 4)\n'
          '     - Disable X11 GUI forwarding (X11Forwarding no)\n'
          '   • Linux Kernel & Sysctl Hardening:\n'
          '     - Full Address Space Layout Randomization (ASLR: kernel.randomize_va_space = 2)\n'
          '     - TCP SYN Cookies protection against SYN flood denial of service (net.ipv4.tcp_syncookies = 1)\n'
          '     - Ignore ICMP routing redirects (net.ipv4.conf.all.accept_redirects = 0)\n'
          '     - Drop source-routed packets (net.ipv4.conf.all.accept_source_route = 0)\n'
          '     - Enable Reverse Path Filtering to prevent IP spoofing (net.ipv4.conf.all.rp_filter = 1)\n'
          '   • Network & Firewall Exposure:\n'
          '     - Verify active status of Fail2ban daemon\n'
          '     - Detect exposed unencrypted legacy ports (Telnet port 23, FTP port 21)\n'
          '     - Enforce MySQL database loopback binding (127.0.0.1)\n'
          '   • User Identity & Credentials:\n'
          '     - Ensure zero empty password hashes in /etc/shadow\n'
          '     - Enforce exclusive superuser root account (only 1 user with UID 0)\n'
          '   • Filesystem Integrity & Permissions:\n'
          '     - Strict permissions on /etc/shadow (chmod 0000 or 0640)\n'
          '     - Strict permissions on /etc/ssh/sshd_config (chmod 0600)\n\n'
          '2. Severity-Weighted Scoring & Letter Grades:\n'
          '   • Penalties are proportional to risk severity (Critical: 20 pts, High: 10 pts, Medium: 5 pts, Low: 2 pts).\n'
          '   • Letter Grades: A+ (95-100%), A (85-94%), B (70-84%), C (50-69%), F (<50%).\n\n'
          '3. Automated 1-Tap Remediation Playbook:\n'
          '   • AEGIS automatically synthesizes all non-compliant findings into a consolidated, idempotent bash script with "set -euo pipefail".\n'
          '   • Execute the playbook directly or via the embedded SSH terminal to instantly achieve A+ grade compliance.\n\n'
          '4. Markdown Audit Report Export:\n'
          '   • Export human-readable and structured Markdown audit reports for ISO 27001, SOC 2, or DevSecOps security audit logs.',
      codeSnippetTitleId: 'Skrip Perintah Hardening Cepat Linux Kernel & OpenSSH',
      codeSnippetTitleEn: 'Quick Linux Kernel & OpenSSH Hardening Script',
      codeSnippets: [
        '# 1. Hardening Kernel Sysctl (Simpan di /etc/sysctl.d/99-aegis-hardening.conf):\n'
            'cat << \'EOF\' | sudo tee /etc/sysctl.d/99-aegis-hardening.conf\n'
            'kernel.randomize_va_space = 2\n'
            'net.ipv4.tcp_syncookies = 1\n'
            'net.ipv4.conf.all.accept_redirects = 0\n'
            'net.ipv4.conf.all.accept_source_route = 0\n'
            'net.ipv4.conf.all.rp_filter = 1\n'
            'EOF\n'
            'sudo sysctl --system\n\n'
            '# 2. Hardening OpenSSH (Simpan di /etc/ssh/sshd_config.d/99-aegis.conf):\n'
            'cat << \'EOF\' | sudo tee /etc/ssh/sshd_config.d/99-aegis.conf\n'
            'PermitRootLogin prohibit-password\n'
            'PasswordAuthentication no\n'
            'MaxAuthTries 4\n'
            'X11Forwarding no\n'
            'EOF\n'
            'sudo chmod 600 /etc/ssh/sshd_config.d/99-aegis.conf\n'
            'sudo systemctl restart sshd\n\n'
            '# 3. Kunci Izin Berkas Rahasia:\n'
            'sudo chmod 0000 /etc/shadow\n'
            'sudo chmod 0600 /etc/ssh/sshd_config',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearchQuery ?? '');
    _selectedCategory = widget.initialCategory ?? FaqCategory.all;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final settings = context.watch<SettingsProvider>();
    final isIndo = _overrideIndonesian ?? settings.isIndonesian;

    final query = _searchController.text.trim().toLowerCase();

    // Filter FAQ list
    final filteredFaqs = _faqList.where((item) {
      // Category filter
      if (_selectedCategory != FaqCategory.all && item.category != _selectedCategory) {
        return false;
      }
      // Query filter
      if (query.isNotEmpty) {
        final q = isIndo ? item.questionId.toLowerCase() : item.questionEn.toLowerCase();
        final a = isIndo ? item.answerId.toLowerCase() : item.answerEn.toLowerCase();
        final codeMatch = item.codeSnippets?.any((c) => c.toLowerCase().contains(query)) ?? false;
        if (!q.contains(query) && !a.contains(query) && !codeMatch) {
          return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
        title: Text(isIndo ? 'PUSAT BANTUAN & FAQ' : 'HELP CENTER & FAQ'),
        actions: [
          // Dynamic Language Override Switcher
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLangButton('ID', isIndo, () {
                  setState(() => _overrideIndonesian = true);
                }, isDark),
                _buildLangButton('EN', !isIndo, () {
                  setState(() => _overrideIndonesian = false);
                }, isDark),
              ],
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;

          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 960),
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 28 : 16,
                vertical: 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Search Bar & Info Banner
                  _buildHeaderCard(context, isIndo, isDark, theme),
                  const SizedBox(height: 16),

                  // Category Filter Chips
                  _buildCategoryChips(isIndo, isDark, theme),
                  const SizedBox(height: 16),

                  // Results Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isIndo
                            ? '${filteredFaqs.length} Topik Bantuan Ditemukan'
                            : '${filteredFaqs.length} Help Topics Found',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      if (filteredFaqs.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              if (_expandedItemId != null) {
                                _expandedItemId = null;
                              } else {
                                _expandedItemId = filteredFaqs.first.id;
                              }
                            });
                          },
                          icon: Icon(
                            _expandedItemId == null
                                ? Icons.unfold_more_rounded
                                : Icons.unfold_less_rounded,
                            size: 14,
                          ),
                          label: Text(
                            _expandedItemId == null
                                ? (isIndo ? 'Buka Topik' : 'Expand All')
                                : (isIndo ? 'Tutup Topik' : 'Collapse All'),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // FAQ List View
                  Expanded(
                    child: filteredFaqs.isEmpty
                        ? _buildEmptyState(isIndo, isDark)
                        : ListView.separated(
                            itemCount: filteredFaqs.length,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                            itemBuilder: (ctx, index) {
                              final item = filteredFaqs[index];
                              final isExpanded = _expandedItemId == item.id;

                              return _buildFaqCard(
                                context: context,
                                item: item,
                                isExpanded: isExpanded,
                                isIndo: isIndo,
                                isDark: isDark,
                                theme: theme,
                                onToggle: () {
                                  setState(() {
                                    _expandedItemId = isExpanded ? null : item.id;
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLangButton(
      String label, bool isSelected, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primary.withValues(alpha: 0.25) : AppColors.primaryLight.withValues(alpha: 0.15))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isSelected
                ? (isDark ? AppColors.primary : AppColors.primaryLight)
                : (isDark ? AppColors.textMuted : AppColors.lightTextMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
      BuildContext context, bool isIndo, bool isDark, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.primary : AppColors.primaryLight)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 20,
                  color: isDark ? AppColors.primary : AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIndo
                          ? 'DOKUMENTASI KEBIJAKAN & TELEMETRI SERVER'
                          : 'POLICY DOCUMENTATION & SERVER TELEMETRY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isIndo
                          ? 'Panduan Parameter Keamanan & Integrasi Firewall'
                          : 'Security Parameters & Firewall Integration Guide',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Field
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: isIndo
                  ? 'Cari penjelasan parameter, fail2ban, waktu geser...'
                  : 'Search parameters, fail2ban commands, sliding window...',
              hintStyle: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
              filled: true,
              fillColor: isDark ? AppColors.darkBackground : AppColors.lightSurfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(bool isIndo, bool isDark, ThemeData theme) {
    final categories = [
      (FaqCategory.all, isIndo ? 'Semua Topik' : 'All Topics', Icons.grid_view_rounded),
      (FaqCategory.policy, isIndo ? 'Kebijakan & Waktu Geser' : 'Policy & Sliding Window', Icons.tune_rounded),
      (FaqCategory.server, isIndo ? 'Server & fail2ban' : 'Server & fail2ban', Icons.dns_rounded),
      (FaqCategory.detection, isIndo ? 'Deteksi Anomali' : 'Anomaly Detection', Icons.radar_rounded),
      (FaqCategory.security, isIndo ? 'Biometrik & Kunci' : 'Biometrics & Security', Icons.fingerprint_rounded),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat.$1;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              showCheckmark: false,
              avatar: Icon(
                cat.$3,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.textMuted : AppColors.lightTextMuted),
              ),
              label: Text(
                cat.$2,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                ),
              ),
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              selectedColor: isDark ? AppColors.primary : AppColors.primaryLight,
              side: BorderSide(
                color: isSelected
                    ? (isDark ? AppColors.primary : AppColors.primaryLight)
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              onSelected: (val) {
                setState(() => _selectedCategory = cat.$1);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFaqCard({
    required BuildContext context,
    required FaqItem item,
    required bool isExpanded,
    required bool isIndo,
    required bool isDark,
    required ThemeData theme,
    required VoidCallback onToggle,
  }) {
    final question = isIndo ? item.questionId : item.questionEn;
    final answer = isIndo ? item.answerId : item.answerEn;
    final snippetTitle = isIndo ? item.codeSnippetTitleId : item.codeSnippetTitleEn;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? (isDark ? AppColors.primary.withValues(alpha: 0.5) : AppColors.primaryLight.withValues(alpha: 0.4))
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isExpanded ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.primary : AppColors.primaryLight)
                          .withValues(alpha: isExpanded ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(item.category),
                      size: 16,
                      color: isDark ? AppColors.primary : AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getCategoryLabel(item.category, isIndo),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Answer Content
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    answer,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    ),
                  ),

                  // Code Snippets if available
                  if (item.codeSnippets != null && item.codeSnippets!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    if (snippetTitle != null) ...[
                      Text(
                        snippetTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: isDark ? AppColors.primary : AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    ...item.codeSnippets!.map((snippet) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBackground
                              : AppColors.lightSurfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SelectableText(
                                snippet,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  height: 1.4,
                                  color: isDark ? const Color(0xFF80D8FF) : const Color(0xFF0369A1),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 14),
                              tooltip: isIndo ? 'Salin Perintah' : 'Copy Commands',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: snippet));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isIndo
                                        ? 'Perintah terminal disalin ke clipboard'
                                        : 'Terminal commands copied to clipboard'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isIndo, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
            ),
            const SizedBox(height: 12),
            Text(
              isIndo
                  ? 'Tidak ada topik bantuan yang cocok'
                  : 'No matching help topics found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isIndo
                  ? 'Coba gunakan kata kunci lain seperti "fail2ban", "waktu geser", atau "login gagal".'
                  : 'Try searching for keywords like "fail2ban", "sliding window", or "brute force".',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(FaqCategory category) {
    switch (category) {
      case FaqCategory.policy:
        return Icons.tune_rounded;
      case FaqCategory.server:
        return Icons.dns_rounded;
      case FaqCategory.detection:
        return Icons.radar_rounded;
      case FaqCategory.security:
        return Icons.fingerprint_rounded;
      case FaqCategory.all:
        return Icons.help_outline_rounded;
    }
  }

  String _getCategoryLabel(FaqCategory category, bool isIndo) {
    switch (category) {
      case FaqCategory.policy:
        return isIndo ? 'KEBIJAKAN & THRESHOLD' : 'POLICY & THRESHOLD';
      case FaqCategory.server:
        return isIndo ? 'FIREWALL & SERVER VPS' : 'FIREWALL & VPS SERVER';
      case FaqCategory.detection:
        return isIndo ? 'DETEKSI ANOMALI' : 'ANOMALY DETECTION';
      case FaqCategory.security:
        return isIndo ? 'KEAMANAN & BIOMETRIK' : 'SECURITY & BIOMETRICS';
      case FaqCategory.all:
        return isIndo ? 'UMUM' : 'GENERAL';
    }
  }
}
