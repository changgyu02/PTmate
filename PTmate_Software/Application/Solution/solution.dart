import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_ptmate/Solution/take_sol.dart'; // TakeSolPage를 import

class SolutionPage extends StatefulWidget {
  const SolutionPage({super.key});

  @override
  SolutionPageState createState() => SolutionPageState();
}

class SolutionPageState extends State<SolutionPage> {
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _jobController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();

  String _gender = "남";
  String _direction = "식단 관리";
  String _message = "";

  Future<void> _solution() async {
    final String age = _ageController.text;
    final String height = _heightController.text;
    final String weight = _weightController.text;
    final String job = _jobController.text;
    final String purpose = _purposeController.text;

    if (age.isEmpty || height.isEmpty || weight.isEmpty || job.isEmpty || purpose.isEmpty) {
      setState(() {
        _message = "솔루션에 필요한 모든 정보가 입력되지 않았습니다.";
      });
      return;
    }

    try {
      // SharedPreferences에서 로그인된 사용자의 _id 가져오기
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('_id'); // _id 가져오기

      if (userId == null) {
        setState(() {
          _message = "로그인 정보가 유효하지 않습니다. 다시 로그인해주세요.";
        });
        return;
      }

      // PATCH 요청 보내기
      final response = await http.patch(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/solution'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "_id": userId, // 사용자 식별자 추가
          "gender": _gender,
          "age": age,
          "height": height,
          "weight": weight,
          "job": job,
          "purpose": purpose,
          "direction": _direction,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // 성공적으로 업데이트 후 TakeSolPage로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TakeSolPage()),
        );
      } else {
        // 상태 코드와 함께 오류 메시지 표시
        setState(() {
          _message = "솔루션 업데이트에 실패했습니다: ${response.statusCode}";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = "오류 발생: $e";
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("정보 입력")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _gender,
                items: const [
                  DropdownMenuItem(value: "남", child: Text("남")),
                  DropdownMenuItem(value: "여", child: Text("여")),
                ],
                onChanged: (value) {
                  setState(() {
                    _gender = value!;
                  });
                },
                decoration: const InputDecoration(labelText: "성별"),
              ),
              TextField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: "나이"),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _heightController,
                      decoration: const InputDecoration(labelText: "키"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text("cm"),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weightController,
                      decoration: const InputDecoration(labelText: "몸무게"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text("kg"),
                ],
              ),
              TextField(
                controller: _jobController,
                decoration: const InputDecoration(labelText: "직업"),
              ),
              TextField(
                controller: _purposeController,
                decoration: const InputDecoration(labelText: "목표"),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  "[예시 : 3개월 안에 5kg 감량, 6개월 동안 운동 습관 변화]",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              DropdownButtonFormField<String>(
                value: _direction,
                items: const [
                  DropdownMenuItem(value: "식단 관리", child: Text("식단 관리")),
                  DropdownMenuItem(value: "운동", child: Text("운동")),
                ],
                onChanged: (value) {
                  setState(() {
                    _direction = value!;
                  });
                },
                decoration: const InputDecoration(labelText: "솔루션 방향"),
              ),
              if (_message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _message,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ElevatedButton(
                onPressed: _solution,
                child: const Text("솔루션 받기"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}