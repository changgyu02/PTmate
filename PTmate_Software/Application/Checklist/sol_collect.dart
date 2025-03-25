import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_ptmate/Solution/new_solution.dart';
import 'package:project_ptmate/User/user_info.dart';
import 'package:project_ptmate/Checklist/check_diet.dart';
import 'package:project_ptmate/Checklist/check_wo.dart';
import 'package:project_ptmate/Checklist/weight_day.dart';

class SolCollectPage extends StatefulWidget {
  const SolCollectPage({super.key});

  @override
  SolCollectPageState createState() => SolCollectPageState();
}

class SolCollectPageState extends State<SolCollectPage> {
  String? userId;
  bool isLoading = true;
  List<dynamic> soldiet = [];
  List<dynamic> solwo = [];
  String selectedTab = "diet"; // 현재 선택된 탭 ("diet" 또는 "workout")

  @override
  void initState() {
    super.initState();
    _loadUserId();
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

    await _fetchSolLogs();
  }

  Future<void> _fetchSolLogs() async {
    if (userId == null) return;

    try {
      final dietResponse = await http.get(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/get_sol_diet_logs?_id=$userId'),
      );

      if (dietResponse.statusCode == 200) {
        final dietData = jsonDecode(dietResponse.body);
        setState(() {
          soldiet = (dietData['data'] ?? [])
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          // 내림차순 정렬
          soldiet.sort((a, b) => b["number"].compareTo(a["number"]));
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }

      final woResponse = await http.get(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/get_sol_wo_logs?_id=$userId'),
      );

      if (woResponse.statusCode == 200) {
        final woData = jsonDecode(woResponse.body);
        setState(() {
          solwo = (woData['data'] ?? [])
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          // 내림차순 정렬
          solwo.sort((a, b) => b["number"].compareTo(a["number"]));
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        soldiet = [];
        solwo = [];
      });
    }
  }

  Future<void> _updateEvaluate(String id, int value, String logType, int logNumber) async {
    try {
      final response = await http.patch(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/update_evaluate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "_id": id,            // 사용자 ID
          "evaluate": value,    // 평가값
          "type": logType,      // 로그 타입 (diet 또는 wo)
          "number": logNumber   // 로그 번호
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("평가가 저장되었습니다!")),
          );
        }
        await _fetchSolLogs(); // 업데이트 후 데이터 새로고침
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("평가 저장에 실패했습니다.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("오류 발생: $e")),
        );
      }
    }
  }

  Widget _buildLogCard(Map<String, dynamic> log, String logType, bool isHighlighted) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: isHighlighted ? Colors.blue.shade100 : Colors.white, // 강조된 카드 색상
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Number 출력
            Text(
              "${log["number"] ?? "없음"}", // Null 대비
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isHighlighted ? Colors.blue.shade700 : Colors.black, // 강조된 텍스트 색상
              ),
            ),
            const SizedBox(height: 8),

            // 2. 운동/식단 계획 내용 출력
            GestureDetector(
              onTap: () {
                _showSolutionPopup(log["sol_$logType"] ?? "솔루션 없음");
              },
              child: Text(
                log["sol_$logType"] ?? "솔루션 없음", // Null 대비
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                  color: isHighlighted ? Colors.blue.shade900 : Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 3. 평가 드롭다운
            DropdownButtonFormField<int>(
              value: log["evaluate"], // Null 대비
              decoration: const InputDecoration(labelText: "평가"),
              items: const [
                DropdownMenuItem(value: 1, child: Text("1 (매우 힘듦)")),
                DropdownMenuItem(value: 2, child: Text("2 (약간 힘듦)")),
                DropdownMenuItem(value: 3, child: Text("3 (적당함)")),
                DropdownMenuItem(value: 4, child: Text("4 (약간 쉬움)")),
                DropdownMenuItem(value: 5, child: Text("5 (매우 쉬움)")),
              ],
              onChanged: (value) {
                if (value != null) {
                  _updateEvaluate(
                      userId ?? "unknown_id",  // 사용자의 ID 전달
                      value,                  // 평가값 전달
                      logType,                // 로그 타입 전달
                      log["number"]           // 로그 번호 전달
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // 팝업창 표시 메서드
  void _showSolutionPopup(String solution) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "솔루션",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    solution,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // 팝업 닫기
                      },
                      child: const Text(
                        "닫기",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("솔루션 관리"),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserInfoPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => setState(() => selectedTab = "diet"),
                child: Text(
                  "식단 관리",
                  style: TextStyle(
                    color: selectedTab == "diet" ? Colors.blue : Colors.black,
                    fontWeight:
                    selectedTab == "diet" ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => selectedTab = "workout"),
                child: Text(
                  "운동",
                  style: TextStyle(
                    color: selectedTab == "workout" ? Colors.blue : Colors.black,
                    fontWeight:
                    selectedTab == "workout" ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: selectedTab == "diet"
                  ? soldiet.length
                  : solwo.length,
              itemBuilder: (context, index) {
                final log = selectedTab == "diet"
                    ? soldiet[index]
                    : solwo[index];
                final isHighlighted = index == 0; // 첫 번째 아이템 강조
                return _buildLogCard(log, selectedTab == "diet" ? "diet" : "wo", isHighlighted);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewSolutionPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text("새로운 솔루션 받기"),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type : BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.carrot), label: "식단",),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: "운동"),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: "몸무게"),
          BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: "솔루션"),
        ],
        currentIndex: 3,
        selectedItemColor: Colors.lightBlueAccent, // 블루 계열
        unselectedItemColor: Color(0xFF1F806F), // 민트 계열
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const CheckDietPage()),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const CheckWoPage()),
              );
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const WeightDayPage()),
              );
              break;
            case 3:
              break;
          }
        },
      ),
    );
  }
}
