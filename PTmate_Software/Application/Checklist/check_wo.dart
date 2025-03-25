import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_ptmate/User/user_info.dart';
import 'package:project_ptmate/Checklist/check_diet.dart';
import 'package:project_ptmate/Checklist/weight_day.dart';
import 'package:project_ptmate/Checklist/sol_collect.dart';

class CheckWoPage extends StatefulWidget {
  const CheckWoPage({super.key});

  @override
  CheckWoPageState createState() => CheckWoPageState();
}

class CheckWoPageState extends State<CheckWoPage> {
  String? userId;
  String displayedHealthTip = "";
  Map<String, dynamic> dailyWo = {}; // 해당 날짜 운동 정보
  List<String> availableExercise = [
    "직접 입력",
    "런닝",
    "조깅",
    "걷기",
    "수영",
    "줄넘기",
    "스쿼트",
    "플랭크",
    "푸쉬업",
    "덤벨",
    "스트레칭"
  ];
  final List<String> healthTips = [
    "꾸준한 운동이 건강 유지의 핵심입니다.",
    "가벼운 스트레칭으로 하루를 시작하세요.",
    "하루 30분 이상 유산소 운동을 해보세요.",
    "근력운동은 주 2~3회 규칙적으로 하면 좋아요.",
    "올바른 자세로 운동하면 부상을 예방할 수 있어요.",
    "운동 전 워밍업은 필수예요.",
    "운동 후에는 반드시 쿨다운으로 마무리하세요.",
    "걷기나 계단 오르기도 좋은 운동입니다.",
    "운동 중 충분한 수분 섭취를 잊지 마세요.",
    "잠이 부족하면 운동 효과가 떨어질 수 있어요.",
    "운동 후 단백질 섭취는 근육 회복에 도움을 줍니다.",
    "새로운 운동을 시도해보면 지루함을 줄일 수 있어요.",
    "휴식일도 운동의 일부입니다. 무리하지 마세요.",
    "복부 코어 운동은 몸의 중심을 안정시켜줘요.",
    "운동 중 호흡 조절을 신경 쓰면 효율이 높아져요.",
  ];
  String todayDate = DateTime.now().toIso8601String().split("T")[0]; // 현재 날짜
  String selectedDate = DateTime.now().toIso8601String().split(
      "T")[0]; // 선택된 날짜

  @override
  void initState() {
    super.initState();
    displayedHealthTip = (healthTips..shuffle()).first;
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('_id');
    if (userId != null) {
      _fetchWoInfo(selectedDate); // 현재 날짜의 운동 정보 가져오기
    }
  }

  Future<void> _fetchWoInfo(String date) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://4729-192-203-145-70.ngrok-free.app/checklist_wo?_id=$userId&date=$date'),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["success"] == true) {
          setState(() {
            dailyWo = jsonData["data"];
            dailyWo.removeWhere((key, value) => value.isEmpty); // 빈 데이터 제거
          });
        } else {
          setState(() {
            dailyWo = {};
          });
        }
      }
    } catch (e) {
      setState(() {
        dailyWo = {};
      });
    }
  }

  Future<void> _saveWoInfo(String woId, Map<String, dynamic> wo,
      BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await http.patch(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/checklist_wo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "_id": userId,
          "date": selectedDate,
          "wo_id": woId,
          "wo": wo,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          await _fetchWoInfo(selectedDate);
          messenger.showSnackBar(
            const SnackBar(content: Text("운동 정보가 성공적으로 저장되었습니다!")),
          );
        }
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text("운동 정보를 저장하는 데 실패했습니다.")),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("저장 오류: $e")),
      );
    }
  }

  Future<void> _updateWoInfo(String woId, Map<String, dynamic> wo,
      BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await http.patch(
        Uri.parse(
            'https://4729-192-203-145-70.ngrok-free.app/checklist_wo_update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "_id": userId,
          "date": selectedDate,
          "wo_id": woId,
          "wo": wo,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          await _fetchWoInfo(selectedDate);
          messenger.showSnackBar(
            const SnackBar(content: Text("운동 정보가 성공적으로 업데이트되었습니다!")),
          );
        }
      } else {
        messenger.showSnackBar(
          SnackBar(
              content: Text("운동 정보를 업데이트하는 데 실패했습니다: ${response.statusCode}")),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("업데이트 오류: $e")),
      );
    }
  }

  Future<void> _deleteWoInfo(String woId, BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await http.delete(
        Uri.parse(
            'https://4729-192-203-145-70.ngrok-free.app/checklist_wo_delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "_id": userId,
          "date": selectedDate,
          "wo_id": woId,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          await _fetchWoInfo(selectedDate);
          messenger.showSnackBar(
            const SnackBar(content: Text("운동 정보가 성공적으로 삭제되었습니다!")),
          );
        }
      } else {
        messenger.showSnackBar(
          SnackBar(
              content: Text("운동 정보를 삭제하는 데 실패했습니다: ${response.statusCode}")),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("삭제 오류: $e")),
      );
    }
  }

  void _addWoDialog() {
    String selectedWo = availableExercise[0];
    String duration = "";
    bool isCompleted = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("운동 추가"),
          content: StatefulBuilder(builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: availableExercise.contains(selectedWo) ? selectedWo : null,
                  items: availableExercise.map((String wo) {
                    return DropdownMenuItem<String>(
                      value: wo,
                      child: Text(wo),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value == "직접 입력") {
                      final customWoController = TextEditingController();
                      await showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text("직접 운동 입력"),
                            content: TextField(
                              controller: customWoController,
                              decoration: const InputDecoration(labelText: "운동 이름 입력"),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("취소"),
                              ),
                              TextButton(
                                onPressed: () {
                                  if (customWoController.text.isNotEmpty) {
                                    setState(() {
                                      // ✅ 리스트에 없으면 추가
                                      if (!availableExercise.contains(customWoController.text)) {
                                        availableExercise.add(customWoController.text);
                                      }
                                      selectedWo = customWoController.text;
                                    });
                                    Navigator.pop(context);
                                  }
                                },
                                child: const Text("확인"),
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      setState(() {
                        selectedWo = value!;
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: "운동 선택"),
                ),
                TextField(
                  decoration: const InputDecoration(labelText: "시간(예: 30분, 10개 x 3세트)"),
                  onChanged: (value) {
                    duration = value;
                  },
                ),
              ],
            );
          }),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () {
                final woId = "wo${dailyWo.length + 1}";
                if (selectedWo.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("운동명을 입력해주세요.")),
                  );
                  return;
                }
                _saveWoInfo(
                  woId,
                  {
                    "wo_name": selectedWo,
                    "amount": duration,
                    "checkbox": isCompleted.toString(),
                  },
                  context,
                );
                Navigator.pop(context);
              },
              child: const Text("저장"),
            ),
          ],
        );
      },
    );
  }

  void _editWoDialog(String woId, Map<String, dynamic> wo) {
    String originalName = wo["wo_name"]!; // 기존 운동 이름
    String selectedName = wo["wo_name"]!; // 수정할 새 운동 이름
    String duration = wo["amount"]!; // 수정할 새 시간
    bool isCompleted = wo["checkbox"] == "false";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$originalName 수정"),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  _deleteWoInfo(woId, context);
                  Navigator.pop(context); // 다이얼로그 닫기
                },
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedName,
                items: availableExercise.map((String exercise) {
                  return DropdownMenuItem<String>(
                    value: exercise,
                    child: Text(exercise),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedName = value!;
                },
                decoration: const InputDecoration(labelText: "운동 선택"),
              ),
              TextField(
                decoration: const InputDecoration(
                    labelText: "시간(예: 30분, 10개 x 3세트)"),
                controller: TextEditingController(text: duration),
                onChanged: (value) {
                  duration = value;
                },
              ),
              CheckboxListTile(
                title: const Text("완료 여부"),
                value: isCompleted,
                onChanged: (value) {
                  setState(() {
                    isCompleted = value ?? false; // 체크박스 상태 업데이트
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () {
                _updateWoInfo(
                  woId,
                  {
                    "original_name": originalName, // 기존 운동 이름
                    "wo_name": selectedName, // 새 운동 이름
                    "amount": duration, // 새 시간
                    "checkbox": isCompleted.toString(), // 새 완료 상태
                  },
                  context,
                );
                Navigator.pop(context);
              },
              child: const Text("저장"),
            ),
          ],
        );
      },
    );
  }

  void _showMonthPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          height: 400,
          child: TableCalendar(
            locale: 'ko_KR',
            // 한국어 설정
            firstDay: DateTime(2010),
            lastDay: DateTime(2050),
            focusedDay: DateTime.now(),
            selectedDayPredicate: (day) =>
            day.toIso8601String().split("T")[0] == selectedDate,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                selectedDate = selectedDay.toIso8601String().split("T")[0];
                _updateWeekDates(selectedDay);
                _fetchWoInfo(selectedDate);
              });
              Navigator.pop(context);
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue[200],
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false, // 달력 위 포맷 버튼 숨김
              titleCentered: true,
              titleTextFormatter: (date, locale) =>
                  DateFormat.yMMMM(locale).format(date), // "2024년 11월" 형식
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekendStyle: const TextStyle(color: Colors.red), // 주말 빨간색
              weekdayStyle: const TextStyle(color: Colors.black),
            ),
          ),
        );
      },
    );
  } // 달력 UI 형식

  List<DateTime> weekDates = [];

  void _updateWeekDates(DateTime selectedDay) {
    DateTime startOfWeek = selectedDay.subtract(
        Duration(days: selectedDay.weekday - 1));
    setState(() {
      weekDates =
          List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
    });
  } // 주를 보여주는 함수

  Widget _buildDateSelector() {
    if (weekDates.isEmpty) {
      _updateWeekDates(DateTime.now());
    }

    String month = "${DateTime
        .parse(selectedDate)
        .month}월";

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                _showMonthPicker(context);
              },
              child: Text(
                month,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: weekDates.map((date) {
            String dateString = date.toIso8601String().split("T")[0];
            bool isToday = dateString == todayDate;
            bool isSelected = dateString == selectedDate;
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedDate = dateString;
                  _fetchWoInfo(dateString);
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[100] : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  date.day.toString(),
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.blue : Colors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  } // 선택된 날에 해당하는 주를 보여주는 함수

  Widget _buildWoList(String title, Map<String, dynamic> dailyData) {
    // 운동 항목 데이터를 정리
    final List<MapEntry<String, dynamic>> workoutEntries = dailyData.entries
        .where((entry) => entry.key.startsWith("wo") && entry.value.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목과 + 버튼
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Text(
                "$title:",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.blue),
              onPressed: () => _addWoDialog(),
            ),
          ],
        ),
        // 운동 항목 리스트
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: workoutEntries.isNotEmpty
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: workoutEntries.map<Widget>((entry) {
              final woId = entry.key;
              final workoutData = entry.value as Map<String, dynamic>;
              final woName = workoutData["wo_name"] ?? "운동 없음";
              final amount = workoutData["amount"] ?? "시간 없음";
              final checkbox = workoutData["checkbox"] == "true";

              return GestureDetector(
                onTap: () => _editWoDialog(woId, workoutData),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$woName $amount",
                        style: const TextStyle(
                            fontSize: 15, color: Colors.black),
                      ),
                      Checkbox(
                        value: checkbox,
                        onChanged: (value) async {
                          final newValue = value ?? false;
                          final updatedWo = {
                            "original_name": woName,
                            "wo_name": woName,
                            "amount": amount,
                            "checkbox": newValue.toString(),
                          };

                          // 서버 업데이트 요청
                          await _updateWoInfo(woId, updatedWo, context);

                          // UI 업데이트
                          setState(() {
                            dailyWo[woId]["checkbox"] = newValue.toString();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          )
              : const Center(
            child: Text(
              "새로운 운동을 추가해주세요.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("운동 체크리스트"),
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
          Container(
            height: 80,
            color: Colors.grey[200],
            child: Center(
              child: Text(
                displayedHealthTip,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          _buildDateSelector(),
          const SizedBox(height: 15),
          Expanded(
            child: ListView(
              children: [
                _buildWoList(
                  "운동 체크리스트",
                  dailyWo, // 운동 데이터를 전달
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.carrot),
            label: "식단",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: "운동",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: "몸무게",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb),
            label: "솔루션",
          ),
        ],
        currentIndex: 1,
        selectedItemColor: Colors.lightBlueAccent,
        // 블루 계열
        unselectedItemColor: Color(0xFF1F806F),
        // 민트 계열
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const CheckDietPage()),
              );
              break;
            case 1:
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const WeightDayPage()),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SolCollectPage()),
              );
              break;
          }
        },
      ),
    );
  }
}