import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'badge_api.dart' as badge;

import '../config.dart';

class NotificationService extends ChangeNotifier {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  AndroidNotificationChannel? _androidChannel;
  bool _initialized = false;
  bool get initialized => _initialized;
  bool _adminSubscribed = false;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _currentToken;

  Future<void> init() async {
    if (_initialized) return;
    await _setupLocalNotifications();
    try {
      await _fcm.setAutoInitEnabled(true);
    } catch (_) {}
    try {
      await _fcm.requestPermission();
    } catch (_) {}
    await _ensureTopicSubscription();
    _tokenRefreshSub ??= _fcm.onTokenRefresh.listen((token) async {
      await _handleTokenRefresh(token);
    }, onError: (_) {});
    _initialized = true;
    notifyListeners();
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    _androidChannel = const AndroidNotificationChannel(
      'articles_channel',
      'Articles',
      description: 'Notifications for new articles',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel!);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'];
    final body = notification?.body ?? message.data['body'];
    if (title == null && body == null) return;

    final androidDetails = AndroidNotificationDetails(
      _androidChannel?.id ?? 'articles_channel',
      _androidChannel?.name ?? 'Articles',
      channelDescription: _androidChannel?.description,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _local.show(
      notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: message.data['articleId'],
    );
  }

  Future<void> setBadgeCount(int count) async {
    try {
      await badge.setBadgeCount(count);
    } catch (_) {}
  }

  Future<void> subscribeAdmins(bool subscribe) async {
    if (subscribe && !_adminSubscribed) {
      await _fcm.subscribeToTopic('${AppConfig.articlesTopic}-admins');
      _adminSubscribed = true;
    }
    if (!subscribe && _adminSubscribed) {
      await _fcm.unsubscribeFromTopic('${AppConfig.articlesTopic}-admins');
      _adminSubscribed = false;
    }
  }

  Future<void> _ensureTopicSubscription() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await _subscribeTokenToArticles(token);
    } catch (_) {}
  }

  Future<void> _handleTokenRefresh(String token) async {
    final previous = _currentToken;
    await _subscribeTokenToArticles(token);
    if (previous != null && previous != token) {
      try {
        await FirebaseFirestore.instance
            .collection('fcmTokens')
            .doc(previous)
            .set({
              'active': false,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> _subscribeTokenToArticles(String token) async {
    _currentToken = token;
    try {
      await _fcm.subscribeToTopic(AppConfig.articlesTopic);
    } catch (_) {}
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('fcmTokens').doc(token).set({
        'uid': uid,
        'topics': {AppConfig.articlesTopic: true},
        'platform': describeEnum(defaultTargetPlatform),
        'active': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    super.dispose();
  }
}
