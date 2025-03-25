import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:project_ptmate/User/login.dart'; // 로그인 페이지로 이동하기 위한 import

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  RegisterPageState createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailLocalController = TextEditingController();
  final TextEditingController _emailDomainController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String? _selectedEmailDomain = "naver.com";
  String _selectedMonth = "1월";
  String _message = "";
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> _checkId() async {
    final String userId = _idController.text.trim();

    if (userId.isEmpty) {
      setState(() {
        _message = "아이디를 입력해주세요.";
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/check_id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"_id": userId}),
      );

      final data = jsonDecode(response.body);
      if (data['exists']) {
        setState(() {
          _message = "중복된 아이디입니다.";
        });
      } else {
        setState(() {
          _message = "사용 가능한 아이디입니다.";
        });
      }
    } catch (e) {
      setState(() {
        _message = "서버에 연결할 수 없습니다.";
      });
    }
  }

  Future<void> _register() async {
    final String name = _nameController.text.trim();
    final String emailLocal = _emailLocalController.text.trim();
    final String emailDomain = _selectedEmailDomain == "직접 입력"
        ? _emailDomainController.text.trim()
        : _selectedEmailDomain!;
    final String email = "$emailLocal@$emailDomain";
    final String year = _yearController.text.trim();
    final String month = (_selectedMonth.replaceAll("월", "")).padLeft(2, '0');
    final String day = _dayController.text.trim().padLeft(2, '0');
    final String birth = "$year-$month-$day";
    final String id = _idController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty ||
        emailLocal.isEmpty ||
        emailDomain.isEmpty ||
        year.isEmpty ||
        day.isEmpty ||
        id.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        _message = "회원가입에 필요한 모든 정보가 입력되지 않았습니다.";
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _message = "비밀번호가 일치하지 않습니다.";
      });
      return;
    }

    if (!_isPasswordValid(password)) {
      setState(() {
        _message = "비밀번호는 6자리 이상, 영소문자와 숫자를 포함해야 합니다.";
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "name": name,
          "email": email,
          "birth": birth,
          "_id": id,
          "password": password,
          "gender": null,
          "age": null,
          "height": null,
          "weight": null,
          "job": null,
          "purpose": null,
          "direction": null,
          "sol_wo": null,
          "sol_diet": null,
          "sol_core_wo": null,
          "sol_core_diet": null
        }),
      );

      if (response.statusCode == 201) {
        setState(() {
          _message = "회원가입이 완료되었습니다.";
        });

        // 회원가입 완료 후 로그인 페이지로 이동
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        });
      } else {
        setState(() {
          _message = "회원가입 실패: 중복된 아이디 혹은 다른 문제가 발생했습니다.";
        });
      }
    } catch (e) {
      setState(() {
        _message = "서버에 연결할 수 없습니다.";
      });
    }
  }

  bool _isPasswordValid(String password) {
    final RegExp passwordRegExp = RegExp(r'^(?=.*[a-z])(?=.*\d)[a-z\d]{6,}$');
    return passwordRegExp.hasMatch(password);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("회원가입")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "이름"),
              ),
              const SizedBox(height: 16),
              Row(
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
                        ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailDomainController,
                            decoration: const InputDecoration(
                              labelText: "도메인 입력",
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_drop_down),
                          onPressed: () {
                            setState(() {
                              _selectedEmailDomain = "naver.com";
                              _emailDomainController.clear();
                            });
                          },
                        ),
                      ],
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
                      decoration:
                      const InputDecoration(labelText: "도메인 선택"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _idController,
                      decoration: const InputDecoration(labelText: "아이디"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _checkId,
                    child: const Text("아이디 중복 확인"),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: "비밀번호",
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                decoration: InputDecoration(
                  labelText: "비밀번호 확인",
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _register,
                child: const Text("회원가입"),
              ),
              const SizedBox(height: 16),
              Text(
                _message,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}