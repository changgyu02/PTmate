import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';
import 'package:project_ptmate/User/login.dart'; // 로그인 페이지 import

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

class UserInfoPage extends StatefulWidget {
  const UserInfoPage({super.key});

  @override
  UserInfoPageState createState() => UserInfoPageState();
}

class UserInfoPageState extends State<UserInfoPage> {
  Map<String, String?> userInfo = {};
  bool isLoading = true;
  String? userId;

  String? _selectedEmailDomain = "naver.com";
  String _selectedMonth = "1월";
  String? qrCode;
  int? endTime;

  final TextEditingController _emailLocalController = TextEditingController();
  final TextEditingController _emailDomainController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _dayController = TextEditingController();

  TimeOfDay? _selectedTime; // 사용자가 선택한 알림 시간

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadNotificationTime();
    _initializeNotifications();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('_id');

    if (id == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    setState(() {
      userId = id;
    });

    await _fetchUserInfo();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings settings =
    InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // 사용자가 알림을 클릭했을 때 실행할 로직
        debugPrint("알림 클릭됨: ${response.payload}");
      },
    );
  }

  // 저장된 알림 시간 불러오기
  Future<void> _loadNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('notification_hour') ?? 20;
    final minute = prefs.getInt('notification_minute') ?? 0;
    setState(() {
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  // 매일 설정된 시간에 푸시 알림 예약
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

    // 현재 시간보다 이전이면 다음 날로 설정
    final adjustedTime = scheduleTime.isBefore(now)
        ? scheduleTime.add(const Duration(days: 1))
        : scheduleTime;

    debugPrint("예약된 알림 시간: ${adjustedTime.toString()}"); // 로그 추가

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      '운동 및 식단 기록',
      '오늘의 식단과 운동을 기록해주세요!',
      adjustedTime,
      notificationDetails,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 정확한 시간 매칭
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // 정확한 예약 실행
    );
  }


  Future<void> _saveNotificationTime() async {
    if (_selectedTime != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('notification_hour', _selectedTime!.hour);
      await prefs.setInt('notification_minute', _selectedTime!.minute);

      _scheduleDailyNotification(_selectedTime!.hour, _selectedTime!.minute); // 알림 예약
    }
  }

  Future<void> _fetchUserInfo() async {
    if (userId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
            'https://4729-192-203-145-70.ngrok-free.app/userinfo?_id=$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          userInfo = {
            "name": data["name"],
            "email": data["email"],
            "birth": data["birth"],
            "_id": data["_id"],
          };
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateUserInfo(String field, String newValue) async {
    if (userId == null) return;

    try {
      final response = await http.patch(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/userinfo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "_id": userId,
          field: newValue,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          userInfo[field] = newValue;
        });
        if (mounted) {
          Navigator.pop(context); // 다이얼로그 닫기
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("수정 실패: ${response.body}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("서버에 연결할 수 없습니다.")),
        );
      }
    }
  }

  Future<void> _updatePassword(String currentPassword,
      String newPassword) async {
    if (userId == null) return;

    try {
      final response = await http.patch(
        Uri.parse(
            'https://4729-192-203-145-70.ngrok-free.app/userinfo/password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "_id": userId,
          "current_password": currentPassword,
          "new_password": newPassword,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("비밀번호 변경 실패")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("서버에 연결할 수 없습니다.")),
        );
      }
    }
  }

  Future<void> _generateQRCode() async {
    if (userId == null) {
      debugPrint("ID가 없음. QR 생성 불가.");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("https://4729-192-203-145-70.ngrok-free.app/generate_qr"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"_id": userId}),
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);

      // QR 코드 데이터가 존재하는지 확인
      if (!data.containsKey("qr_data") || data["qr_data"] == null) {
        debugPrint("서버 응답에 QR 코드 정보가 없음!");
        return;
      }

      final String newQrData = data["qr_data"];
      final String otp = data["otp"];
      final String expiresAtString = data["expires_at"];

      debugPrint("서버에서 받은 최신 OTP: $otp");

      final DateTime expiresAt = DateTime.parse(expiresAtString);
      final int expiresAtMillis = expiresAt.millisecondsSinceEpoch;

      setState(() {
        qrCode = newQrData;
        endTime = expiresAtMillis;
      });

      debugPrint("QR 코드 업데이트 완료: $qrCode");
    } catch (e) {
      debugPrint("QR 코드 오류: $e");
    }
  }

  void _showQRCodeDialog() async {
    await _generateQRCode(); // QR 코드 생성 요청 후 최신 데이터 업데이트

    if (!mounted) return;

    Future.delayed(const Duration(milliseconds: 500), () { // UI 강제 업데이트
      if (mounted) {
        setState(() {});
      }
    });

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("QR 코드 로그인"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (qrCode != null && qrCode!.isNotEmpty) ...[
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: QrImageView(
                        data: qrCode!,
                        version: QrVersions.auto,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (endTime != null)
                      CountdownTimer(
                        endTime: endTime!,
                        textStyle: const TextStyle(fontSize: 20, color: Colors.red),
                        onEnd: () {
                          setState(() {
                            qrCode = null;
                            endTime = null;
                          });
                        },
                      ),
                    const SizedBox(height: 10),
                    const Text("QR 코드가 3분 후에 만료됩니다."),
                  ] else ...[
                    const Center(
                      child: CircularProgressIndicator(), // 로딩 표시 추가
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "QR 코드 생성 중... 잠시만 기다려 주세요.",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text("닫기"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(String field, String? currentValue) {
    final TextEditingController controller = TextEditingController(
        text: currentValue);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("$field 수정"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: "새 $field 입력"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () {
                final newValue = controller.text.trim();
                if (newValue.isNotEmpty) {
                  _updateUserInfo(field, newValue);
                }
              },
              child: const Text("변경"),
            ),
          ],
        );
      },
    );
  }

  void _showEditEmailDialog() {
    final emailParts = (userInfo["email"] ?? "").split("@");
    _emailLocalController.text = emailParts.isNotEmpty ? emailParts[0] : "";
    _selectedEmailDomain = emailParts.length > 1 ? emailParts[1] : "naver.com";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("이메일 수정"),
          content: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _emailLocalController,
                  decoration: const InputDecoration(labelText: "이메일 주소"),
                ),
              ),
              const SizedBox(width: 8),
              const Text("@"),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _selectedEmailDomain == "직접 입력"
                    ? TextField(
                  controller: _emailDomainController,
                  decoration: const InputDecoration(labelText: "도메인 입력"),
                )
                    : DropdownButtonFormField<String>(
                  value: _selectedEmailDomain,
                  items: [
                    "직접 입력",
                    "naver.com",
                    "gmail.com",
                    "daum.net",
                  ].map((String domain) {
                    return DropdownMenuItem<String>(
                      value: domain,
                      child: Text(domain),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      if (newValue == "직접 입력") {
                        _emailDomainController.clear();
                      }
                      _selectedEmailDomain = newValue;
                    });
                  },
                  decoration: const InputDecoration(labelText: "도메인 선택"),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () {
                final emailLocal = _emailLocalController.text.trim();
                final emailDomain = _selectedEmailDomain == "직접 입력"
                    ? _emailDomainController.text.trim()
                    : _selectedEmailDomain!;
                final newEmail = "$emailLocal@$emailDomain";
                if (emailLocal.isNotEmpty && emailDomain.isNotEmpty) {
                  _updateUserInfo("email", newEmail);
                }
              },
              child: const Text("변경"),
            ),
          ],
        );
      },
    );
  }

  void _showEditBirthDialog() {
    final birthParts = (userInfo["birth"] ?? "").split("-");
    _yearController.text = birthParts.isNotEmpty ? birthParts[0] : "";
    _selectedMonth =
    birthParts.length > 1 ? "${int.parse(birthParts[1])}월" : "1월";
    _dayController.text = birthParts.length > 2 ? birthParts[2] : "";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("생년월일 수정"),
          content: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "년도 (YYYY)"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedMonth,
                  items: List.generate(12, (index) {
                    return DropdownMenuItem<String>(
                      value: "${index + 1}월",
                      child: Text("${index + 1}월"),
                    );
                  }),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedMonth = newValue ?? "1월";
                    });
                  },
                  decoration: const InputDecoration(labelText: "월 선택"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _dayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "일 (DD)"),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () {
                final year = _yearController.text.trim();
                final month = (_selectedMonth.replaceAll("월", "")).padLeft(
                    2, '0');
                final day = _dayController.text.trim().padLeft(2, '0');
                final newBirth = "$year-$month-$day";
                if (year.isNotEmpty && month.isNotEmpty && day.isNotEmpty) {
                  _updateUserInfo("birth", newBirth);
                }
              },
              child: const Text("변경"),
            ),
          ],
        );
      },
    );
  }

  void _showPasswordEditDialog() {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    String errorMessage = "";

    // 비밀번호 보이기/숨기기 상태 관리
    bool isCurrentPasswordVisible = false;
    bool isNewPasswordVisible = false;
    bool isConfirmPasswordVisible = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text("비밀번호 수정"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: !isCurrentPasswordVisible,
                    decoration: InputDecoration(
                      labelText: "현재 비밀번호",
                      suffixIcon: IconButton(
                        icon: Icon(
                          isCurrentPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            isCurrentPasswordVisible =
                            !isCurrentPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newPasswordController,
                    obscureText: !isNewPasswordVisible,
                    decoration: InputDecoration(
                      labelText: "새 비밀번호",
                      suffixIcon: IconButton(
                        icon: Icon(
                          isNewPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            isNewPasswordVisible = !isNewPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: !isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: "새 비밀번호 확인",
                      suffixIcon: IconButton(
                        icon: Icon(
                          isConfirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            isConfirmPasswordVisible =
                            !isConfirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (errorMessage.isNotEmpty)
                    Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("취소"),
                ),
                TextButton(
                  onPressed: () async {
                    final currentPassword = currentPasswordController.text
                        .trim();
                    final newPassword = newPasswordController.text.trim();
                    final confirmPassword = confirmPasswordController.text
                        .trim();

                    if (currentPassword.isEmpty ||
                        newPassword.isEmpty ||
                        confirmPassword.isEmpty) {
                      setState(() {
                        errorMessage = "모든 정보를 입력해주세요.";
                      });
                      return;
                    }

                    if (newPassword != confirmPassword) {
                      setState(() {
                        errorMessage = "새 비밀번호가 일치하지 않습니다.";
                      });
                      return;
                    }

                    if (!_isPasswordValid(newPassword)) {
                      setState(() {
                        errorMessage = "새 비밀번호는 6자리 이상, 영소문자와 숫자를 포함해야 합니다.";
                      });
                      return;
                    }

                    await _updatePassword(currentPassword, newPassword);
                  },
                  child: const Text("변경"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _isPasswordValid(String password) {
    final RegExp passwordRegExp = RegExp(r'^(?=.*[a-z])(?=.*\d)[a-z\d]{6,}$');
    return passwordRegExp.hasMatch(password);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();

    // SharedPreferences 초기화
    await prefs.clear();

    // 로그인 페이지로 이동
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("내 정보")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 이름
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "이름: ${userInfo['name'] ?? '불러오기 실패'}",
                  style: const TextStyle(fontSize: 18),
                ),
                TextButton(
                  onPressed: () => _showEditDialog("name", userInfo['name']),
                  child: const Text("수정"),
                ),
              ],
            ),
            // 🔹 이메일
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "이메일: ${userInfo['email'] ?? '불러오기 실패'}",
                  style: const TextStyle(fontSize: 18),
                ),
                TextButton(
                  onPressed: _showEditEmailDialog,
                  child: const Text("수정"),
                ),
              ],
            ),
            // 🔹 생년월일
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "생년월일: ${userInfo['birth'] ?? '불러오기 실패'}",
                  style: const TextStyle(fontSize: 18),
                ),
                TextButton(
                  onPressed: _showEditBirthDialog,
                  child: const Text("수정"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 🔹 아이디
            Text(
              "아이디: ${userInfo['_id'] ?? '불러오기 실패'}",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            // 🔹 비밀번호 수정
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "비밀번호: ******",
                  style: TextStyle(fontSize: 18),
                ),
                TextButton(
                  onPressed: _showPasswordEditDialog,
                  child: const Text("수정"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 🔹 푸시 알림 시간 설정 UI (Dropdown 형식 + 테스트 버튼)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "알림 시간:",
                  style: TextStyle(fontSize: 18),
                ),
                Row(
                  children: [
                    // 🔹 시간 선택 Dropdown (1시간 간격)
                    DropdownButton<int>(
                      value: _selectedTime?.hour ?? 20,
                      items: List.generate(24, (index) {
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text("$index 시"),
                        );
                      }),
                      onChanged: (int? newHour) {
                        if (newHour != null) {
                          setState(() {
                            _selectedTime = TimeOfDay(hour: newHour, minute: _selectedTime?.minute ?? 0);
                          });
                          _saveNotificationTime(); // 선택한 시간 저장 및 알림 예약
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    // 🔹 분 선택 Dropdown (5분 간격)
                    DropdownButton<int>(
                      value: _selectedTime?.minute ?? 0,
                      items: List.generate(12, (index) {
                        return DropdownMenuItem<int>(
                          value: index * 5, // 0, 5, 10, 15 ... 55
                          child: Text("${index * 5} 분"),
                        );
                      }),
                      onChanged: (int? newMinute) {
                        if (newMinute != null) {
                          setState(() {
                            _selectedTime = TimeOfDay(hour: _selectedTime?.hour ?? 20, minute: newMinute);
                          });
                          _saveNotificationTime(); // 선택한 시간 저장 및 알림 예약
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 🔹 QR 코드 로그인 버튼 추가
            ElevatedButton.icon(
              onPressed: _showQRCodeDialog,
              icon: const Icon(Icons.qr_code),
              label: const Text("QR 코드로 로그인"),
            ),
            const SizedBox(height: 16),

            // 🔹 로그아웃 버튼
            ElevatedButton(
              onPressed: _logout,
              child: const Text("로그아웃"),
            ),
          ],
        ),
      ),
    );
  }
}
