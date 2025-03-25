import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_ptmate/User/qrcode_scanner.dart'; // QR 코드 스캔 페이지 import
import 'package:project_ptmate/Checklist/check_diet.dart';
import 'package:project_ptmate/Solution/solution.dart';
import 'package:project_ptmate/Solution/take_sol.dart';
import 'package:project_ptmate/User/register.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _keepLoggedIn = false;
  String _message = "";

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (isLoggedIn && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CheckDietPage()),
      );
    }
  }

  Future<void> _login() async {
    final String id = _idController.text;
    final String password = _passwordController.text;

    try {
      final response = await http.post(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"_id": id, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String userId = data['_id'] ?? "";
        if (userId.isEmpty) {
          setState(() {
            _message = "서버 응답에 _id가 없습니다.";
          });
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('_id', userId);

        if (_keepLoggedIn) {
          await prefs.setBool('isLoggedIn', true);
        }

        final solDiet = data['sol_diet'];
        final solWo = data['sol_wo'];
        final direction = data['direction'];
        if (solDiet == null && solWo == null && direction != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TakeSolPage()),
            );
          });
        } else if (solDiet == null && solWo == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SolutionPage()),
            );
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CheckDietPage()),
            );
          });
        }
      } else if (response.statusCode == 401) {
        setState(() {
          _message = "ID 또는 비밀번호가 잘못되었습니다.";
        });
      }
    } catch (e) {
      debugPrint("로그인 오류: $e");
      setState(() {
        _message = "서버에 연결할 수 없습니다.";
      });
    }
  }

  void _scanQRCode() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QRScannerPage()), // ✅ 기존 QR 코드 스캐너 활용
      );

      if (result == null || result.isEmpty) {
        debugPrint("QR 코드 스캔 실패: 데이터 없음");
        return;
      }

      debugPrint("스캔된 QR 데이터: $result");

      // QR 코드 데이터 파싱
      Map<String, dynamic> decodedData;
      try {
        decodedData = jsonDecode(result);
      } catch (e) {
        debugPrint("QR 코드 JSON 파싱 오류: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("QR 코드 데이터가 올바르지 않습니다.")),
          );
        }
        return;
      }

      // QR 코드에서 필요한 데이터 추출
      final String? userId = decodedData["_id"];
      final String? otp = decodedData["otp"];

      if (userId == null || otp == null) {
        debugPrint("QR 코드 데이터가 올바르지 않음 (userId 또는 otp 없음)");
        return;
      }

      debugPrint("QR 데이터 파싱 완료: userId=$userId, otp=$otp");

      // JSON 문자열로 변환 후 `_handleQRLogin()`에 전달
      final String encodedData = jsonEncode(decodedData);
      _handleQRLogin(encodedData);
    } catch (e) {
      debugPrint("QR 코드 인식 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("QR 코드 형식이 잘못되었습니다. 다시 시도해주세요.")),
        );
      }
    }
  }


  void _handleQRLogin(String qrData) async {  // `String` 타입을 받도록 수정
    try {
      final Map<String, dynamic> data = jsonDecode(qrData);  // 문자열을 JSON으로 변환

      final String? userId = data["_id"];
      final String? otp = data["otp"];

      if (userId == null || otp == null) {
        debugPrint("QR 코드 로그인 실패: 데이터가 올바르지 않음");
        return;
      }

      final response = await http.post(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/otp_login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"_id": userId, "otp": otp}),  // JSON 형식으로 변환 후 서버에 전송
      );

      debugPrint("서버 응답 코드: ${response.statusCode}");
      debugPrint("서버 응답 데이터: ${response.body}");

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('_id', userId);
        await prefs.setBool('isLoggedIn', true);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CheckDietPage()),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _message = "QR 코드 로그인 실패: OTP가 만료되었거나 올바르지 않습니다.";
          });
        }
      }
    } catch (e) {
      debugPrint("QR 코드 로그인 오류: $e");
      if (mounted) {
        setState(() {
          _message = "QR 코드 오류: ${e.toString()}";
        });
      }
    }
  }


  void _navigateToRegisterPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("로그인")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(labelText: "ID"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: "Password",
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _keepLoggedIn,
                  onChanged: (bool? value) {
                    setState(() {
                      _keepLoggedIn = value ?? false;
                    });
                  },
                ),
                const Text("로그인 상태 유지"),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _login,
              child: const Text("Login"),
            ),
            const SizedBox(height: 16),

            // QR 코드 스캔 로그인 버튼
            ElevatedButton.icon(
              onPressed: _scanQRCode,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: const Text("QR 코드 스캔 로그인", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 16),

            Text(
              _message,
              style: const TextStyle(color: Colors.red),
            ),
            TextButton(
              onPressed: _navigateToRegisterPage,
              child: const Text("회원가입", style: TextStyle(fontSize: 16, color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }
}