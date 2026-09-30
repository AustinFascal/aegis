import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationActionData {
  final String actionId; // 'block_ip', 'trust_ip', or 'view'
  final String payload; // client IP or event details

  const NotificationActionData({
    required this.actionId,
    required this.payload,
  });
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🛡️ [Aegis] Background FCM alert received: ${message.messageId}');
  final data = message.data;
  final notification = message.notification;

  final title = notification?.title ?? data['title'] ?? '🚨 AEGIS Security Incursion Alert';
  final body = notification?.body ?? data['body'] ?? 'Suspicious access detected on server';
  final ip = data['ip'] ?? '';

  final localNotifications = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await localNotifications.initialize(
    settings: const InitializationSettings(android: androidInit),
  );

  final androidDetails = AndroidNotificationDetails(
    'aegis_security_channel',
    'AEGIS Security Alerts',
    channelDescription: 'High-priority alerts for unauthorized access or unknown logins',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'Security Alert',
    enableVibration: true,
    styleInformation: BigTextStyleInformation(body),
    actions: const <AndroidNotificationAction>[
      AndroidNotificationAction(
        'block_ip',
        '🛡️ Block IP',
        showsUserInterface: true,
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        'trust_ip',
        '✅ Trust',
        showsUserInterface: true,
        cancelNotification: true,
      ),
    ],
  );

  await localNotifications.show(
    id: message.hashCode,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(android: androidDetails),
    payload: ip,
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  final StreamController<NotificationActionData> _actionController =
      StreamController<NotificationActionData>.broadcast();
  Stream<NotificationActionData> get onNotificationAction => _actionController.stream;

  final StreamController<Map<String, dynamic>> _fcmEventController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onFcmEvent => _fcmEventController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Initialize Flutter Local Notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxInit = LinuxInitializationSettings(defaultActionName: 'Open AEGIS');

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      linux: linuxInit,
    );

    try {
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            _actionController.add(NotificationActionData(
              actionId: response.actionId ?? 'view',
              payload: response.payload!,
            ));
          }
        },
      );
    } catch (e) {
      debugPrint('[NotificationService] Local notifications unavailable on this platform: $e');
    }

    // 2. Initialize FCM (Safely handling platforms where Firebase isn't yet configured)
    try {
      if (Firebase.apps.isNotEmpty) {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          criticalAlert: true,
        );

        _fcmToken = await messaging.getToken();
        debugPrint('🛡️ AEGIS FCM TOKEN: $_fcmToken');
        await messaging.subscribeToTopic('aegis_alerts');

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final notification = message.notification;
          final data = message.data;
          final title = notification?.title ?? data['title'] ?? '🚨 AEGIS Security Alert';
          final body = notification?.body ?? data['body'] ?? '';
          final ip = data['ip'] ?? '';

          final eventMap = Map<String, dynamic>.from(data);
          eventMap['title'] = title;
          eventMap['body'] = body;
          _fcmEventController.add(eventMap);

          final notifId = ip.isNotEmpty ? (ip.hashCode.abs() % 100000) : message.hashCode;

          showSecurityAlert(
            id: notifId,
            title: title,
            body: body,
            payload: ip.isNotEmpty ? ip : (data['action'] ?? ''),
            isCritical: true,
          );
        });

        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          final notification = message.notification;
          final data = message.data;
          final title = notification?.title ?? data['title'] ?? '🚨 AEGIS Security Alert';
          final body = notification?.body ?? data['body'] ?? '';
          final ip = data['ip'] ?? '';

          final eventMap = Map<String, dynamic>.from(data);
          eventMap['title'] = title;
          eventMap['body'] = body;
          _fcmEventController.add(eventMap);
          _actionController.add(NotificationActionData(actionId: 'view', payload: ip));
        });

        final initialMsg = await messaging.getInitialMessage();
        if (initialMsg != null) {
          final notification = initialMsg.notification;
          final data = initialMsg.data;
          final title = notification?.title ?? data['title'] ?? '🚨 AEGIS Security Alert';
          final body = notification?.body ?? data['body'] ?? '';
          final ip = data['ip'] ?? '';

          final eventMap = Map<String, dynamic>.from(data);
          eventMap['title'] = title;
          eventMap['body'] = body;
          _fcmEventController.add(eventMap);
          _actionController.add(NotificationActionData(actionId: 'view', payload: ip));
        }
      }
    } catch (e) {
      debugPrint('FCM initialization skipped or waiting for config: $e');
    }

    _isInitialized = true;
  }

  Future<void> showSecurityAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool isCritical = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'aegis_security_channel',
      'AEGIS Security Alerts',
      channelDescription: 'High-priority alerts for unauthorized access or unknown logins',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Security Alert',
      enableVibration: true,
      tag: payload != null && payload.isNotEmpty ? payload : null,
      styleInformation: BigTextStyleInformation(body),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'block_ip',
          '🛡️ Block IP',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'trust_ip',
          '✅ Trust',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const linuxDetails = LinuxNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
    );

    try {
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NotificationService] Local notification skipped or headless: $e');
    }
  }

  /// Sends a realistic simulated security alert to test heads-up display & actions
  Future<void> sendTestAlert({String clientIp = '185.220.101.5'}) async {
    await showSecurityAlert(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🚨 CRITICAL: Unknown Person Access',
      body: 'User "root" logged in to SSHD from untrusted IP $clientIp (Moscow, RU)!',
      payload: clientIp,
      isCritical: true,
    );
  }
}
