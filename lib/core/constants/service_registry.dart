import 'package:flutter/material.dart';

class ServiceDefinition {
  final String id;
  final String name;
  final String portDisplay;
  final String category; // 'Database', 'Web Server', 'Runtime', 'AI Engine', 'Mail', 'System'
  final IconData icon;
  final Color color;
  final String description;
  final String defaultLogPath;
  final String pgrepPattern;
  final List<String> systemdUnits;

  const ServiceDefinition({
    required this.id,
    required this.name,
    required this.portDisplay,
    required this.category,
    required this.icon,
    required this.color,
    required this.description,
    this.defaultLogPath = '',
    required this.pgrepPattern,
    this.systemdUnits = const [],
  });
}

class ServiceRegistry {
  static const List<ServiceDefinition> knownServices = [
    ServiceDefinition(
      id: 'mysqld',
      name: 'MySQL / MariaDB',
      portDisplay: 'Port 3306',
      category: 'Database',
      icon: Icons.storage_rounded,
      color: Color(0xFF00E5FF),
      description: 'Relational database cluster for healthcare records and app data.',
      defaultLogPath: '/var/log/mariadb/mariadb.log',
      pgrepPattern: 'mysqld',
      systemdUnits: ['mysqld', 'mariadb', 'mysql'],
    ),
    ServiceDefinition(
      id: 'sshd',
      name: 'OpenSSH Daemon',
      portDisplay: 'Port 22',
      category: 'System',
      icon: Icons.terminal_rounded,
      color: Color(0xFF00E676),
      description: 'Encrypted remote administration daemon with key authentication.',
      defaultLogPath: '/var/log/secure',
      pgrepPattern: 'sshd',
      systemdUnits: ['sshd', 'ssh'],
    ),
    ServiceDefinition(
      id: 'httpd',
      name: 'Apache Web Server',
      portDisplay: 'Port 80 / 443',
      category: 'Web Server',
      icon: Icons.language_rounded,
      color: Color(0xFFFF9100),
      description: 'High-traffic HTTP/HTTPS web application server.',
      defaultLogPath: '/etc/apache2/logs/error_log',
      pgrepPattern: 'httpd',
      systemdUnits: ['httpd', 'apache2'],
    ),
    ServiceDefinition(
      id: 'nginx',
      name: 'NGINX Reverse Proxy',
      portDisplay: 'Port 8080 / 8443',
      category: 'Web Server',
      icon: Icons.alt_route_rounded,
      color: Color(0xFF00C853),
      description: 'High-performance edge reverse proxy and SSL gateway.',
      defaultLogPath: '/var/log/nginx/error.log',
      pgrepPattern: 'nginx',
      systemdUnits: ['nginx'],
    ),
    ServiceDefinition(
      id: 'redis-server',
      name: 'Redis Cache Store',
      portDisplay: 'Port 6379',
      category: 'Database',
      icon: Icons.memory_rounded,
      color: Color(0xFFFF5252),
      description: 'In-memory key-value cache and pub/sub message broker.',
      defaultLogPath: '/var/log/redis/redis.log',
      pgrepPattern: 'redis-server',
      systemdUnits: ['redis', 'redis-server'],
    ),
    ServiceDefinition(
      id: 'php-fpm',
      name: 'PHP FastCGI Engine',
      portDisplay: 'UNIX Socket',
      category: 'Runtime',
      icon: Icons.code_rounded,
      color: Color(0xFF7C4DFF),
      description: 'FastCGI Process Manager executing application backend workloads.',
      defaultLogPath: '/var/log/php-fpm/error.log',
      pgrepPattern: 'php-fpm',
      systemdUnits: ['ea-php81-php-fpm', 'php-fpm', 'ea-php80-php-fpm', 'ea-php82-php-fpm'],
    ),
    ServiceDefinition(
      id: 'node',
      name: 'Node.js App Server',
      portDisplay: 'Port 3200',
      category: 'Runtime',
      icon: Icons.javascript_rounded,
      color: Color(0xFF64DD17),
      description: 'Node.js microservices and asynchronous API endpoints.',
      defaultLogPath: '/var/log/node.log',
      pgrepPattern: 'node',
      systemdUnits: ['node'],
    ),
    ServiceDefinition(
      id: 'ollama',
      name: 'Ollama AI Engine',
      portDisplay: 'Port 11434',
      category: 'AI Engine',
      icon: Icons.psychology_rounded,
      color: Color(0xFFFF4081),
      description: 'Self-hosted on-premise Large Language Model inference engine.',
      defaultLogPath: '/var/log/ollama.log',
      pgrepPattern: 'ollama',
      systemdUnits: ['ollama'],
    ),
    ServiceDefinition(
      id: 'dovecot',
      name: 'Dovecot Mail Server',
      portDisplay: 'Port 993 / 995',
      category: 'Mail',
      icon: Icons.mark_email_read_rounded,
      color: Color(0xFF40C4FF),
      description: 'Secure IMAP/POP3 mail storage and delivery service.',
      defaultLogPath: '/var/log/maillog',
      pgrepPattern: 'dovecot',
      systemdUnits: ['dovecot'],
    ),
    ServiceDefinition(
      id: 'exim',
      name: 'Exim SMTP Agent',
      portDisplay: 'Port 25 / 587',
      category: 'Mail',
      icon: Icons.send_rounded,
      color: Color(0xFFFFAB00),
      description: 'MTA handling outbound email delivery and queue dispatch.',
      defaultLogPath: '/var/log/exim_mainlog',
      pgrepPattern: 'exim',
      systemdUnits: ['exim'],
    ),
    ServiceDefinition(
      id: 'pure-ftpd',
      name: 'Pure-FTPd Daemon',
      portDisplay: 'Port 21',
      category: 'System',
      icon: Icons.folder_shared_rounded,
      color: Color(0xFF00B0FF),
      description: 'Secure authenticated FTP file transfer daemon.',
      defaultLogPath: '/var/log/messages',
      pgrepPattern: 'pure-ftpd',
      systemdUnits: ['pure-ftpd'],
    ),
    ServiceDefinition(
      id: 'named',
      name: 'PowerDNS / Named',
      portDisplay: 'Port 53',
      category: 'System',
      icon: Icons.dns_rounded,
      color: Color(0xFFE040FB),
      description: 'Authoritative DNS name server resolving domains and queries.',
      defaultLogPath: '/var/log/messages',
      pgrepPattern: 'named|pdns_server',
      systemdUnits: ['pdns', 'named'],
    ),
  ];

  static ServiceDefinition getById(String id) {
    final lower = id.toLowerCase();
    return knownServices.firstWhere(
      (s) => s.id == lower || lower.contains(s.id),
      orElse: () => ServiceDefinition(
        id: id,
        name: id.toUpperCase(),
        portDisplay: 'Active',
        category: 'Service',
        icon: Icons.layers_rounded,
        color: const Color(0xFF00E5FF),
        description: 'Monitored server daemon process.',
        pgrepPattern: id,
        systemdUnits: [id],
      ),
    );
  }
}
