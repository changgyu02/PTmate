import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_ptmate/Checklist/check_diet.dart';

class TakeSolPage extends StatefulWidget {
  const TakeSolPage({super.key});

  @override
  TakeSolPageState createState() => TakeSolPageState();
}

class TakeSolPageState extends State<TakeSolPage> {
  String? userName; // 서버에서 가져온 사용자 이름
  String? direction; // 서버에서 가져온 direction
  String? solution; // 서버에서 가져온 sol_diet 또는 sol_wo
  bool isLoading = true; // 로딩 상태 추적
  String? userId; // SharedPreferences에서 가져온 _id

  @override
  void initState() {
    super.initState();
    _loadUserId(); // SharedPreferences에서 _id 가져오기
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('_id');

    if (id == null) {
      setState(() {
        isLoading = false; // _id가 없으면 로딩 종료
      });
      return;
    }

    setState(() {
      userId = id;
    });

    await _fetchUserData(); // 사용자 데이터 가져오기
  }

  Future<void> _fetchUserData() async {
    if (userId == null) return;

    try {
      final response = await http.get(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/userdata?_id=$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          userName = data['name']; // 서버에서 받은 사용자 이름
          direction = data['direction']; // 서버에서 받은 direction
        });
        await _fetchSolution(); // 솔루션 데이터 가져오기
      } else {
        setState(() {
          isLoading = false; // 사용자 데이터를 가져오지 못한 경우 로딩 종료
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false; // 오류 발생 시 로딩 종료
      });
    }
  }

  Future<void> _fetchSolution() async {
    if (direction == null || userId == null) return;

    try {
      final response = await http.get(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/takesol?_id=$userId&direction=$direction'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          solution = data['solution']; // 서버에서 받은 sol_diet 또는 sol_wo
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false; // 솔루션 데이터를 가져오지 못한 경우 로딩 종료
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false; // 오류 발생 시 로딩 종료
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("솔루션 보기")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(), // 로딩 애니메이션
              const SizedBox(height: 16),
              const Text(
                "솔루션을 생성중입니다.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          )
              : userName == null || direction == null
              ? const Text(
            "사용자 정보를 가져오는데 실패했습니다.",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          )
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "$userName님에 맞춘 $direction에 대한 솔루션입니다.",
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                solution ?? "솔루션을 가져오는데 실패했습니다.",
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const CheckDietPage(), // 버튼 클릭 시 체크리스트 페이지로 이동
                    ),
                  );
                },
                child: const Text("메인페이지로 이동"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}