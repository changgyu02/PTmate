import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'User/login.dart'; // 로그인 페이지
import 'Checklist/check_diet.dart'; // 식단 관리 체크 페이지

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null); // 날짜 포맷 초기화
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul')); // 한국 시간대 설정
  await _initializeNotifications(); // 푸시 알림 초기화

  // 저장된 알림 시간 가져와서 앱 실행 시 자동 예약
  final prefs = await SharedPreferences.getInstance();
  final hour = prefs.getInt('notification_hour') ?? 20;
  final minute = prefs.getInt('notification_minute') ?? 0;
  _scheduleDailyNotification(hour, minute);

  runApp(const MyApp());
}

// **푸시 알림 초기화**
Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings settings =
  InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(settings);

  // Android 8.0(API 26) 이상에서 알림 채널 생성
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'daily_notification', // 채널 ID
    'Daily Notifications', // 채널 이름
    description: '매일 일정 시간에 알림을 보냅니다.', // 설명
    importance: Importance.max, // 중요도 높음
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

// ✅ **알림 예약**
Future<void> _scheduleDailyNotification(int hour, int minute) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'daily_notification', 'Daily Notification',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  final now = tz.TZDateTime.now(tz.local);
  final scheduleTime = tz.TZDateTime(
    tz.local, now.year, now.month, now.day, hour, minute,
  );

  // 현재 시간보다 이전이면 다음 날로 예약
  final adjustedTime =
  scheduleTime.isBefore(now) ? scheduleTime.add(const Duration(days: 1)) : scheduleTime;

  debugPrint("예약된 알림 시간: ${adjustedTime.toString()}"); // ✅ 디버깅 로그

  await flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    '운동 및 식단 기록',
    '오늘의 식단과 운동을 기록해주세요!',
    adjustedTime,
    notificationDetails,
    uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PTmate',
      theme: ThemeData(
        primaryColor: Colors.lightBlueAccent,
      ),
      home: const App(), // 초기 페이지를 결정하는 App 위젯
    );
  }
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkLoginStatus(), // 로그인 상태 확인
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !(snapshot.data ?? false)) {
          return const LoginPage();
        }
        return const CheckDietPage();
      },
    );
  }

  // 로그인 상태 확인
  Future<bool> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }
}