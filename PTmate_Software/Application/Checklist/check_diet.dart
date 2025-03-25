import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_ptmate/User/user_info.dart';
import 'package:project_ptmate/Checklist/check_wo.dart';
import 'package:project_ptmate/Checklist/weight_day.dart';
import 'package:project_ptmate/Checklist/sol_collect.dart';

class CheckDietPage extends StatefulWidget {
  const CheckDietPage({super.key});

  @override
  CheckDietPageState createState() => CheckDietPageState();
}

class CheckDietPageState extends State<CheckDietPage> {
  String? userId;
  String displayedHealthTip = "";
  Map<String, dynamic> dailyDiet = {}; // 해당 날짜 식단 정보
  List<String> availableFoods = [
    "직접 입력",
    "계란",
    "고구마",
    "그릭 요거트",
    "딸기",
    "두부",
    "사과",
    "삶은 달걀",
    "샐러드",
    "연어 구이",
    "오트밀",
    "현미밥"
  ]; // 음식(달걀, 샐러드, 연어 등)
  final List<String> healthTips = [
    "하루 세 끼 규칙적으로 식사해요.",
    "단 음식을 줄이면 혈당 관리에 도움이 돼요.",
    "야채는 매끼 최소 2가지 이상 섭취해요.",
    "가공식품보다 자연식품을 선택하세요.",
    "아침을 거르지 않으면 체중 조절에 유리해요.",
    "하루 물 섭취는 최소 1.5L 이상을 권장해요.",
    "과식을 피하고 배부르기 전 멈춰보세요.",
    "탄수화물, 단백질, 지방을 골고루 섭취해요.",
    "식사 후에는 가벼운 산책이 소화에 좋아요.",
    "너무 늦은 야식은 피하는 것이 좋아요.",
    "짠 음식은 적당히, 싱겁게 먹는 습관을 가져요.",
    "설탕 대신 천연 감미료 사용을 고려해보세요.",
    "식사 전 물 한잔은 과식을 예방해요.",
    "튀김보다는 찜이나 삶은 요리를 추천해요.",
    "과일도 적당량! 지나친 과당 섭취는 주의하세요.",
  ];
  String todayDate = DateTime.now().toIso8601String().split("T")[0]; // 현재 날짜
  String selectedDate = DateTime.now().toIso8601String().split("T")[0]; // 선택된 날짜

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
      _fetchDietInfo(selectedDate); // 현재 날짜의 식단 정보 가져오기
    }
  }

  Future<void> _fetchDietInfo(String date) async {
    try {
      final response = await http.get(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/checklist_diet?_id=$userId&date=$date'),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["success"] == true) {
          setState(() {
            dailyDiet = jsonData["data"] ?? {};
          });
        } else {
          setState(() {
            dailyDiet = {};
          });
        }
      }
    } catch (e) {
      setState(() {
        dailyDiet = {};
      });
    }
  }

  Future<void> _saveDietInfo(String meal, Map<String, String> food, BuildContext context) async {
    final String? dbMealKey = mealMapping[meal.trim()]; // 매핑된 데이터베이스 키
    if (dbMealKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("유효하지 않은 식사 시간입니다.")),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await http.patch(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/checklist_diet'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "_id": userId,
          "date": selectedDate,
          "meal": dbMealKey,
          "food": food,
        }),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          await _fetchDietInfo(selectedDate);
          messenger.showSnackBar(
            const SnackBar(content: Text("식단 정보가 성공적으로 저장되었습니다.")),
          );
        }
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text("식단 정보를 저장하는 데 실패했습니다: ${response.statusCode}")),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("저장 오류: $e")),
      );
    }
  }

  Future<void> _updateDietInfo(String meal, Map<String, String> food, BuildContext context)
  async {
    final String? dbMealKey = mealMapping[meal.trim()]; // 매핑된 데이터베이스 키
    if (dbMealKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("유효하지 않은 식사 시간입니다.")),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await http.patch(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/checklist_diet_update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "_id": userId,
          "date": selectedDate,
          "meal": dbMealKey,
          "food": {
            "original_food": food["original_food"], // 기존 음식 이름
            "food": food["food"],                 // 새 음식 이름
            "amount": food["amount"],             // 새 음식 양
          },
        }),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          await _fetchDietInfo(selectedDate);
          messenger.showSnackBar(
            const SnackBar(content: Text("식단 정보가 성공적으로 업데이트되었습니다!")),
          );
        }
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text("식단 정보를 업데이트하는 데 실패했습니다: ${response.statusCode}")),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("업데이트 오류: $e")),
      );
    }
  }

  Future<void> _deleteDietInfo(String meal, Map<String, String> food, BuildContext context)
  async {
    final String? dbMealKey = mealMapping[meal.trim()]; // 매핑된 키
    if (dbMealKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("유효하지 않은 식사 시간입니다.")),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await http.delete(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/checklist_diet_delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "_id": userId,
          "date": selectedDate,
          "meal": dbMealKey,
          "food": food,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          await _fetchDietInfo(selectedDate);
          messenger.showSnackBar(
            const SnackBar(content: Text("식단 정보가 성공적으로 삭제되었습니다.")),
          );
        }
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text("식단 정보를 삭제하는 데 실패했습니다: ${response.statusCode}")),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("삭제 오류: $e")),
      );
    }
  }

  void _addFoodDialog(String meal) {
    String selectedFood = availableFoods[0];
    String quantity = "";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("$meal 추가"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedFood,
                    items: availableFoods.map((String food) {
                      return DropdownMenuItem<String>(
                        value: food,
                        child: Text(food),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      if (value == "직접 입력") {
                        // 직접 입력 다이얼로그 띄우기
                        final customFoodController = TextEditingController();
                        await showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text("직접 음식 입력"),
                              content: TextField(
                                controller: customFoodController,
                                decoration: const InputDecoration(labelText: "음식 이름 입력"),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("취소"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    if (customFoodController.text.isNotEmpty) {
                                      setState(() {
                                        selectedFood = customFoodController.text;
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
                          selectedFood = value!;
                        });
                      }
                    },
                    decoration: const InputDecoration(labelText: "음식 선택"),
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: "수량 (ex: 2개, 100g)"),
                    onChanged: (value) {
                      quantity = value;
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
                    _saveDietInfo(meal, {"food": selectedFood, "amount": quantity}, context);
                    Navigator.pop(context);
                  },
                  child: const Text("저장"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editFoodDialog(String meal, Map<String, String> food) {
    String originalFood = food["food"]!; // 기존 음식 이름
    String selectedFood = food["food"]!; // 수정할 새 음식 이름
    String quantity = food["amount"]!;  // 수정할 새 양

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$meal 수정"),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  _deleteDietInfo(meal, {"food": selectedFood, "amount": quantity}, context);
                  Navigator.pop(context); // 다이얼로그 닫기
                },
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: availableFoods.contains(selectedFood) ? selectedFood : null, // ✅ 리스트에 없으면 null
                items: availableFoods.map((String food) {
                  return DropdownMenuItem<String>(
                    value: food,
                    child: Text(food),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value == "직접 입력") {
                    final customFoodController = TextEditingController();
                    await showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("직접 음식 입력"),
                          content: TextField(
                            controller: customFoodController,
                            decoration: const InputDecoration(labelText: "음식 이름 입력"),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("취소"),
                            ),
                            TextButton(
                              onPressed: () {
                                if (customFoodController.text.isNotEmpty) {
                                  setState(() {
                                    selectedFood = customFoodController.text; // 직접 입력 값 저장
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
                      selectedFood = value!;
                    });
                  }
                },
                decoration: const InputDecoration(labelText: "음식 선택"),
              ),
              TextField(
                decoration: const InputDecoration(labelText: "수량 (ex: 2개, 100g)"),
                controller: TextEditingController(text: quantity),
                onChanged: (value) {
                  quantity = value;
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
                _updateDietInfo(
                  meal,
                  {
                    "original_food": originalFood, // 기존 음식 이름 전달
                    "food": selectedFood,         // 새 음식 이름
                    "amount": quantity            // 새 음식 양
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
            locale: 'ko_KR', // 한국어 설정
            firstDay: DateTime(2010),
            lastDay: DateTime(2050),
            focusedDay: DateTime.now(),
            selectedDayPredicate: (day) => day.toIso8601String().split("T")[0] == selectedDate,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                selectedDate = selectedDay.toIso8601String().split("T")[0];
                _updateWeekDates(selectedDay);
                _fetchDietInfo(selectedDate);
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
              titleTextFormatter: (date, locale) => DateFormat.yMMMM(locale).format(date), // "2024년 11월" 형식
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekendStyle: const TextStyle(color: Colors.red), // 주말 빨간색
              weekdayStyle: const TextStyle(color: Colors.black),
            ),
          ),
        );
      },
    );
  }  // 달력 UI 형식

  List<DateTime> weekDates = [];

  final Map<String, String> mealMapping = {
    "아침": "breakfast",
    "점심": "lunch",
    "저녁": "dinner",
  };

  void _updateWeekDates(DateTime selectedDay) {
    DateTime startOfWeek = selectedDay.subtract(Duration(days: selectedDay.weekday - 1));
    setState(() {
      weekDates = List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
    });
  }  // 주를 보여주는 함수

  Widget _buildDateSelector() {
    if (weekDates.isEmpty) {
      _updateWeekDates(DateTime.now());
    }

    String month = "${DateTime.parse(selectedDate).month}월";

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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  _fetchDietInfo(dateString);
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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

  Widget _buildMealSection(String meal, List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Text(
                "$meal:",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.blue),
              onPressed: () => _addFoodDialog(meal),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map<Widget>((foodItem) {
              final food = foodItem['food'] ?? '음식 없음';
              final amount = foodItem['amount'] ?? '수량 없음';
              return GestureDetector(
                onTap: () => _editFoodDialog(meal, {"food": food, "amount": amount}),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    "$food $amount",
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black,
                    ),
                  ),
                ),
              );
            }).toList(),
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
        title: const Text("식단 체크리스트"),
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
                _buildMealSection("아침", dailyDiet["breakfast"] ?? []),
                _buildMealSection("점심", dailyDiet["lunch"] ?? []),
                _buildMealSection("저녁", dailyDiet["dinner"] ?? []),
              ],
            ),
          ),
        ],
      ),  // 식단
      bottomNavigationBar: BottomNavigationBar(
        type : BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.carrot), label: "식단",),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: "운동"),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: "몸무게"),
          BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: "솔루션"),
        ],
        currentIndex: 0,
        selectedItemColor: Colors.lightBlueAccent, // 블루 계열
        unselectedItemColor: Color(0xFF1F806F), // 민트 계열
        onTap: (index) {
          switch (index) {
            case 0:
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
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SolCollectPage()),
              );
              break;
          }
        },
      ), // 하단버튼
    );
  }
}