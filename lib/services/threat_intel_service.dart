import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'penetration_test_service.dart';

class IpThreatIntel {
  final String ipAddress;
  final bool isPublic;
  final int ipVersion;
  final bool isWhitelisted;
  final int abuseConfidenceScore; // 0 - 100
  final String countryCode;
  final String countryName;
  final String usageType;
  final String isp;
  final String domain;
  final List<String> hostnames;
  final bool isTor;
  final int totalReports;
  final int numDistinctUsers;
  final DateTime? lastReportedAt;
  final bool isSimulated;
  final DateTime queriedAt;

  const IpThreatIntel({
    required this.ipAddress,
    required this.isPublic,
    this.ipVersion = 4,
    this.isWhitelisted = false,
    required this.abuseConfidenceScore,
    this.countryCode = '',
    this.countryName = '',
    this.usageType = 'Internet Service Provider',
    this.isp = 'Unknown ISP',
    this.domain = '',
    this.hostnames = const [],
    this.isTor = false,
    this.totalReports = 0,
    this.numDistinctUsers = 0,
    this.lastReportedAt,
    this.isSimulated = false,
    required this.queriedAt,
  });

  bool get isHighRisk => abuseConfidenceScore >= 50;
  bool get isMediumRisk => abuseConfidenceScore >= 20 && abuseConfidenceScore < 50;
  bool get isLowRisk => abuseConfidenceScore < 20;

  Color getRiskColor(bool isDark) {
    if (abuseConfidenceScore >= 50) {
      return isDark ? AppColors.danger : AppColors.dangerLight;
    } else if (abuseConfidenceScore >= 20) {
      return isDark ? AppColors.warning : AppColors.warningLight;
    } else {
      return isDark ? AppColors.success : AppColors.successLight;
    }
  }

  String getRiskLevelText({required bool isIndonesian}) {
    if (abuseConfidenceScore >= 80) {
      return isIndonesian ? 'BAHAYA TINGGI (MALICIOUS)' : 'CRITICAL THREAT';
    } else if (abuseConfidenceScore >= 50) {
      return isIndonesian ? 'RISIKO TINGGI (SUSPICIOUS)' : 'HIGH RISK';
    } else if (abuseConfidenceScore >= 20) {
      return isIndonesian ? 'RISIKO SEDANG (FLAGGED)' : 'MODERATE RISK';
    } else {
      return isIndonesian ? 'REPUTASI BERSIH (CLEAN)' : 'CLEAN / LOW RISK';
    }
  }

  factory IpThreatIntel.fromJson(Map<String, dynamic> json, {bool isSimulated = false}) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    DateTime? lastRep;
    if (data['lastReportedAt'] != null) {
      try {
        lastRep = DateTime.parse(data['lastReportedAt'].toString());
      } catch (_) {}
    }

    return IpThreatIntel(
      ipAddress: data['ipAddress']?.toString() ?? '',
      isPublic: data['isPublic'] == true || data['isPublic'] == null,
      ipVersion: (data['ipVersion'] as num?)?.toInt() ?? 4,
      isWhitelisted: data['isWhitelisted'] == true,
      abuseConfidenceScore: (data['abuseConfidenceScore'] as num?)?.toInt() ?? 0,
      countryCode: data['countryCode']?.toString() ?? '',
      countryName: data['countryName']?.toString() ?? '',
      usageType: data['usageType']?.toString() ?? 'Internet Service Provider',
      isp: data['isp']?.toString() ?? 'Unknown ISP',
      domain: data['domain']?.toString() ?? '',
      hostnames: (data['hostnames'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      isTor: data['isTor'] == true,
      totalReports: (data['totalReports'] as num?)?.toInt() ?? 0,
      numDistinctUsers: (data['numDistinctUsers'] as num?)?.toInt() ?? 0,
      lastReportedAt: lastRep,
      isSimulated: isSimulated,
      queriedAt: DateTime.now(),
    );
  }
}

class ThreatIntelService {
  static final ThreatIntelService _instance = ThreatIntelService._internal();
  factory ThreatIntelService() => _instance;
  ThreatIntelService._internal();

  final Map<String, IpThreatIntel> _cache = {};

  // Testing hook: allows injecting a custom fetcher function
  @visibleForTesting
  Future<Map<String, dynamic>> Function(String ip, String apiKey)? customHttpFetcher;

  /// Checks whether an IP address belongs to internal private/loopback/link-local ranges
  static bool isPrivateOrInternalIp(String ip) {
    final cleanIp = ip.trim().toLowerCase();
    if (cleanIp == 'localhost' ||
        cleanIp == '127.0.0.1' ||
        cleanIp == '::1' ||
        cleanIp.startsWith('127.')) {
      return true;
    }

    // IPv4 RFC 1918 & RFC 3927 Link-Local
    final parts = cleanIp.split('.');
    if (parts.length == 4) {
      final first = int.tryParse(parts[0]);
      final second = int.tryParse(parts[1]);
      if (first != null && second != null) {
        if (first == 10) return true; // 10.0.0.0/8
        if (first == 172 && (second >= 16 && second <= 31)) return true; // 172.16.0.0/12
        if (first == 192 && second == 168) return true; // 192.168.0.0/16
        if (first == 169 && second == 254) return true; // 169.254.0.0/16 (Link Local)
      }
    }

    // IPv6 Unique Local Address (ULA) & Link Local
    if (cleanIp.startsWith('fc') ||
        cleanIp.startsWith('fd') ||
        cleanIp.startsWith('fe80')) {
      return true;
    }

    return false;
  }

  /// Query threat intelligence for an IP address.
  /// If [apiKey] is not provided or network is unavailable, falls back to simulated threat intelligence.
  Future<IpThreatIntel> checkIp({
    required String ip,
    String? apiKey,
    bool forceRefresh = false,
  }) async {
    final cleanIp = ip.trim();

    // 1. Private/Internal IP Handling
    if (isPrivateOrInternalIp(cleanIp)) {
      return IpThreatIntel(
        ipAddress: cleanIp,
        isPublic: false,
        abuseConfidenceScore: 0,
        usageType: 'Internal Private Subnet (RFC 1918)',
        isp: 'Local / Enterprise Intranet',
        domain: 'lan.local',
        countryCode: 'LAN',
        countryName: 'Local Network',
        isWhitelisted: true,
        queriedAt: DateTime.now(),
      );
    }

    // 2. Cache check
    if (!forceRefresh && _cache.containsKey(cleanIp)) {
      return _cache[cleanIp]!;
    }

    // 3. If API Key is configured, attempt real AbuseIPDB API check
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      try {
        final intel = await _queryAbuseIpDbApi(cleanIp, apiKey.trim());
        _cache[cleanIp] = intel;
        return intel;
      } catch (e) {
        debugPrint('[ThreatIntelService] API query failed: $e, falling back to simulated intelligence.');
      }
    }

    // 4. Fallback simulation (offline, simulated pen-test, or no API key)
    final simulatedIntel = _generateSimulatedThreatIntel(cleanIp);
    _cache[cleanIp] = simulatedIntel;
    return simulatedIntel;
  }

  /// Performs real HTTPS REST query to AbuseIPDB Check API v2
  Future<IpThreatIntel> _queryAbuseIpDbApi(String ip, String apiKey) async {
    if (customHttpFetcher != null) {
      final json = await customHttpFetcher!(ip, apiKey);
      return IpThreatIntel.fromJson(json, isSimulated: false);
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);

    try {
      final uri = Uri.https('api.abuseipdb.com', '/api/v2/check', {
        'ipAddress': ip,
        'maxAgeInDays': '90',
        'verbose': 'true',
      });

      final request = await client.getUrl(uri).timeout(const Duration(seconds: 6));
      request.headers.set('Key', apiKey);
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(const Duration(seconds: 6));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        return IpThreatIntel.fromJson(json, isSimulated: false);
      } else if (response.statusCode == 429) {
        throw HttpException('AbuseIPDB Rate Limit Exceeded (Free tier: 1,000 checks/day): $responseBody');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw HttpException('Invalid or Unauthorized AbuseIPDB API Key: $responseBody');
      } else {
        throw HttpException('AbuseIPDB API Error (${response.statusCode}): $responseBody');
      }
    } finally {
      client.close();
    }
  }

  /// Verify whether an AbuseIPDB API key is valid by testing Google DNS (8.8.8.8)
  Future<bool> verifyApiKey(String apiKey) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) return false;

    if (customHttpFetcher != null) {
      try {
        await customHttpFetcher!('8.8.8.8', cleanKey);
        return true;
      } catch (_) {
        return false;
      }
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);

    try {
      final uri = Uri.https('api.abuseipdb.com', '/api/v2/check', {
        'ipAddress': '8.8.8.8',
        'maxAgeInDays': '90',
      });

      final request = await client.getUrl(uri).timeout(const Duration(seconds: 6));
      request.headers.set('Key', cleanKey);
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(const Duration(seconds: 6));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Generates synthetic threat intelligence for demo evaluation and penetration testing origins
  IpThreatIntel _generateSimulatedThreatIntel(String ip) {
    // Check known simulated threat origins from PenetrationTestService
    for (final origin in PenetrationTestService.threatOrigins) {
      if (origin['ip'] == ip) {
        final category = origin['category'] ?? 'Suspicious Host';
        final isTor = category.toLowerCase().contains('tor');
        final isC2 = category.toLowerCase().contains('c2') || category.toLowerCase().contains('botnet');
        final score = isTor || isC2 ? 100 : 85;
        final reports = isTor ? 642 : (isC2 ? 981 : 324);
        final distinctUsers = (reports * 0.35).round();

        return IpThreatIntel(
          ipAddress: ip,
          isPublic: true,
          ipVersion: 4,
          isWhitelisted: false,
          abuseConfidenceScore: score,
          countryCode: origin['country'] ?? 'XX',
          countryName: origin['city'] ?? 'Unknown City',
          usageType: category,
          isp: origin['asn'] ?? 'Autonomous Security Fleet',
          domain: isTor ? 'tor-exit.net' : (isC2 ? 'c2-cluster.net' : 'scanner-bot.org'),
          isTor: isTor,
          totalReports: reports,
          numDistinctUsers: distinctUsers,
          lastReportedAt: DateTime.now().subtract(const Duration(minutes: 14)),
          isSimulated: true,
          queriedAt: DateTime.now(),
        );
      }
    }

    // Well-known public DNS / Benign IPs
    if (ip == '8.8.8.8' || ip == '8.8.4.4') {
      return IpThreatIntel(
        ipAddress: ip,
        isPublic: true,
        abuseConfidenceScore: 0,
        countryCode: 'US',
        countryName: 'United States',
        usageType: 'Data Center/Web Hosting/Transit',
        isp: 'Google LLC',
        domain: 'google.com',
        isWhitelisted: true,
        totalReports: 0,
        numDistinctUsers: 0,
        isSimulated: true,
        queriedAt: DateTime.now(),
      );
    }
    if (ip == '1.1.1.1' || ip == '1.0.0.1') {
      return IpThreatIntel(
        ipAddress: ip,
        isPublic: true,
        abuseConfidenceScore: 0,
        countryCode: 'US',
        countryName: 'United States',
        usageType: 'Data Center/Web Hosting/Transit',
        isp: 'Cloudflare, Inc.',
        domain: 'cloudflare.com',
        isWhitelisted: true,
        totalReports: 0,
        numDistinctUsers: 0,
        isSimulated: true,
        queriedAt: DateTime.now(),
      );
    }

    // Generic simulated assessment derived from IP octets
    final parts = ip.split('.');
    int syntheticScore = 15;
    if (parts.length == 4) {
      final lastOctet = int.tryParse(parts[3]) ?? 1;
      syntheticScore = (lastOctet * 37) % 95;
    }

    return IpThreatIntel(
      ipAddress: ip,
      isPublic: true,
      abuseConfidenceScore: syntheticScore,
      countryCode: 'ID',
      countryName: 'Indonesia',
      usageType: 'Fixed Line ISP / Data Center',
      isp: 'Telkom Indonesia / Indosat Fleet',
      domain: 'telkom.co.id',
      isWhitelisted: syntheticScore < 20,
      totalReports: syntheticScore > 20 ? syntheticScore * 3 : 0,
      numDistinctUsers: syntheticScore > 20 ? (syntheticScore * 1.2).round() : 0,
      lastReportedAt: syntheticScore > 20 ? DateTime.now().subtract(const Duration(hours: 6)) : null,
      isSimulated: true,
      queriedAt: DateTime.now(),
    );
  }

  /// Clears in-memory IP threat intel cache
  void clearCache() {
    _cache.clear();
  }
}
