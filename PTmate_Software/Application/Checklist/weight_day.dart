import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart'
    show AxisTitles, BarAreaData, FlBorderData, FlDotCirclePainter, FlDotData, FlGridData, FlLine, FlSpot, FlTitlesData, LineChart, LineChartBarData, LineChartData, LineTooltipItem, LineTouchData, LineTouchTooltipData, SideTitles;
import 'package:table_calendar/table_calendar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_ptmate/User/user_info.dart';
import 'package:project_ptmate/Checklist/check_diet.dart';
import 'package:project_ptmate/Checklist/check_wo.dart';
import 'package:project_ptmate/Checklist/sol_collect.dart';

class WeightDayPage extends StatefulWidget {
  const WeightDayPage({super.key});

  @override
  WeightDayPageState createState() => WeightDayPageState();
}

class WeightDayPageState extends State<WeightDayPage> {
  String? userId;
  Map<String, dynamic> weightData = {};
  String todayDate = DateTime.now().toIso8601String().split("T")[0];
  String selectedDate = DateTime.now().toIso8601String().split("T")[0];
  String lastRecordedDate = DateTime.now().toIso8601String().split("T")[0];
  String displayedHealthTip = "";
  List<DateTime> pastWeek = [];

  final List<String> healthTips = [
    "물을 충분히 마시면 신진대사가 촉진돼요!",
    "매일 30분 걷기 운동으로 심혈관 건강을 지켜요.",
    "충분한 수면은 면역력을 높여줍니다.",
    "야채와 과일을 꾸준히 섭취해요.",
    "스트레칭은 몸과 마음의 긴장을 풀어줘요.",
    "하루에 10분 명상은 스트레스 완화에 좋아요.",
    "식사는 천천히 꼭꼭 씹어 먹으면 소화가 잘돼요.",
    "하루 1컵의 녹차는 항산화 효과가 있습니다.",
    "아침에 햇볕을 쬐면 비타민D 합성이 촉진돼요.",
    "잠들기 1시간 전 스마트폰 사용을 줄여보세요.",
    "짠 음식 섭취를 줄이면 혈압 관리에 도움이 돼요.",
    "올바른 자세는 허리와 목 건강에 매우 중요해요.",
    "너무 오랜 시간 앉아있지 말고 중간에 일어나세요.",
    "주 2회 이상 꾸준한 근력운동은 골밀도에 도움이 돼요.",
    "가볍게 웃는 것도 면역력을 높이는 좋은 습관입니다.",
  ];

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now().toIso8601String().split("T")[0];
    displayedHealthTip = (healthTips..shuffle()).first;
    _updatePastWeekFromSelectedDate();   // 처음 시작 시 오늘 기준으로 pastWeek 생성
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('_id');
    if (userId != null) {
      await _fetchInitialWeight(); // users 컬렉션에서 몸무게 가져오기
      await _fetchWeightData();  // 기존 weight 데이터 가져오기
    }
  }

  Future<void> _fetchInitialWeight() async {
    if (userId == null) return;

    try {
      final response = await http.get(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/get_weight?_id=$userId'),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData["success"] == true && jsonData["data"]["weight"] != null) {
          setState(() {
            // 기본값을 강제로 설정하지 않고, weightData가 없는 경우만 업데이트
            if (!weightData.containsKey(selectedDate)) {
              weightData[selectedDate] = double.parse(jsonData["data"]["weight"].toString());
            }
          });
        }
      }
    } catch (e) {
      debugPrint("몸무게 가져오기 실패: $e");
    }
  }

  Future<void> _fetchWeightData() async {
    try {
      final response = await http.get(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/get_weight?_id=$userId'),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData["success"] == true) {
          setState(() {
            if (jsonData["data"] != null) {
              weightData.clear(); // 기존 데이터를 비우고 새로 설정
              weightData.addAll(jsonData["data"]); // 새로운 데이터 추가
            }
          });
        }
      }
    } catch (e) {
      debugPrint("몸무게 데이터 가져오기 실패: $e");
    }
  }

  Future<void> _addWeightData(String date, double weight) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await http.patch(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/add_weight'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "_id": userId,
          "date": date, 
          "weight": weight,
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData["success"] == true && jsonData["data"] != null) {
          setState(() {
            weightData.clear();
            weightData.addAll(Map<String, dynamic>.from(jsonData["data"]));
          });
        }
        messenger.showSnackBar(
          const SnackBar(content: Text("몸무게 정보가 성공적으로 저장되었습니다!")),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text("몸무게 정보를 저장하는 데 실패했습니다: ${response.statusCode}")),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("저장 오류: $e")),
      );
    }
  }


  Future<void> _updateWeightData(String date, double newWeight) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await http.patch(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/update_weight'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "_id": userId,
          "date": date,
          "weight": newWeight,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          await _fetchWeightData();
          messenger.showSnackBar(
            const SnackBar(content: Text("몸무게 정보가 성공적으로 수정되었습니다!")),
          );
        }
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text("몸무게 정보를 수정하는 데 실패했습니다: ${response.statusCode}")),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("수정 오류: $e")),
      );
    }
  }

  Future<void> _deleteWeightData(String date) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await http.delete(
        Uri.parse('https://4729-192-203-145-70.ngrok-free.app/delete_weight'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "_id": userId,
          "date": date,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          await _fetchWeightData();
          messenger.showSnackBar(
            const SnackBar(content: Text("몸무게 정보가 성공적으로 삭제되었습니다!")),
          );
        }
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text("몸무게 정보를 삭제하는 데 실패했습니다: ${response.statusCode}")),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("삭제 오류: $e")),
      );
    }
  }

  void _updatePastWeekFromSelectedDate() {
    DateTime selected = DateTime.parse(selectedDate);
    pastWeek = List.generate(7, (index) => selected.subtract(Duration(days: 6 - index)),
    );
  }

  void _showAddWeightDialog() {
    TextEditingController weightController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("몸무게 추가"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                decoration: const InputDecoration(labelText: "몸무게 입력 (kg)"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text("날짜 선택: "),
                  TextButton(
                    onPressed: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.parse(selectedDate),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          selectedDate = pickedDate.toIso8601String().split("T")[0];
                          _updatePastWeekFromSelectedDate();
                        });
                      }
                    },
                    child: Text(selectedDate),
                  ),
                ],
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
                if (weightController.text.isNotEmpty) {
                  _addWeightData(
                      selectedDate,
                      double.parse(weightController.text)
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text("저장"),
            ),
          ],
        );
      },
    );
  }

  void _showEditWeightDialog(String date, double weight) {
    TextEditingController weightController = TextEditingController(text: weight.toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("몸무게 수정"),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red), // 휴지통 아이콘
                onPressed: () {
                  _deleteWeightData(date); // 삭제 함수 호출
                  Navigator.pop(context); // 다이얼로그 닫기
                },
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                decoration: const InputDecoration(labelText: "몸무게 입력 (kg)"),
                keyboardType: TextInputType.number,
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
                if (weightController.text.isNotEmpty) {
                  _updateWeightData(date, double.parse(weightController.text)); // 수정 함수 호출
                  Navigator.pop(context);
                }
              },
              child: const Text("수정"),
            ),
          ],
        );
      },
    );
  }

  void _onWeightTap(String date, double weight) {
    _showEditWeightDialog(date, weight);
  }

  void _showMonthPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          height: 400,
          child: TableCalendar(
            locale: 'ko_KR',
            firstDay: DateTime(2010),
            lastDay: DateTime(2050),
            focusedDay: DateTime.now(),
            selectedDayPredicate: (day) => day.toIso8601String().split("T")[0] == selectedDate,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                selectedDate = selectedDay.toIso8601String().split("T")[0];
                _updatePastWeekFromSelectedDate();
                _fetchWeightData(); // 선택 날짜에 대한 데이터 다시 가져오기
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
              formatButtonVisible: false,
              titleCentered: true,
              titleTextFormatter: (date, locale) => DateFormat.yMMMM(locale).format(date),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekendStyle: const TextStyle(color: Colors.red),
              weekdayStyle: const TextStyle(color: Colors.black),
            ),
          ),
        );
      },
    );
  }

  double _calculateMinY() {
    if (weightData.isEmpty) return 50;
    double minValue = weightData.values.cast<double>().reduce((a, b) => a < b ? a : b);
    double candidateMinY = minValue - 2;
    if (candidateMinY > minValue) {
      candidateMinY = minValue - 2;
    }
    return candidateMinY.clamp(40, double.infinity);
  }

  double _calculateMaxY() {
    if (weightData.isEmpty) return 70;
    double maxValue = weightData.values.cast<double>().reduce((a, b) => a > b ? a : b);
    return maxValue + 2;
  }



  Widget _buildWeightGraph() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SizedBox(
        height: 300,
        child: GestureDetector(
          onTapUp: (details) {
            RenderBox? renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final chartWidth = renderBox.size.width;
              final stepWidth = chartWidth / pastWeek.length;

              int clickedIndex = (details.localPosition.dx / stepWidth).floor();
              if (clickedIndex >= 0 && clickedIndex < pastWeek.length) {
                String clickedDate = pastWeek[clickedIndex].toIso8601String().split("T")[0];

                if (weightData.containsKey(clickedDate) && weightData[clickedDate] != null) {
                  _onWeightTap(clickedDate, weightData[clickedDate]);
                } else {
                  setState(() {
                    selectedDate = clickedDate;
                  });
                  _showAddWeightDialog();
                }
              }
            }
          },
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (pastWeek.length - 1).toDouble(),
              minY: _calculateMinY(),
              maxY: _calculateMaxY(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                verticalInterval: 1,
                getDrawingVerticalLine: (value) => FlLine(
                  color: Colors.grey.shade300,
                  strokeWidth: 1,
                ),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.shade300,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toInt()} kg',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index >= 0 && index < pastWeek.length) {
                        return Text(
                          DateFormat('MM/dd').format(pastWeek[index]),
                          style: const TextStyle(fontSize: 12),
                        );
                      }
                      return const Text('');
                    },
                    interval: 1, // 인덱스 0부터 끝까지 강제 라벨 표시
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: const Border.symmetric(
                  horizontal: BorderSide(color: Colors.black, width: 1),
                  vertical: BorderSide(color: Colors.black, width: 1),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: pastWeek.asMap().entries.map((entry) {
                    int index = entry.key;
                    DateTime date = entry.value;
                    String dateString = date.toIso8601String().split("T")[0];

                    if (weightData.containsKey(dateString)) {
                      return FlSpot(index.toDouble(), weightData[dateString]!.toDouble());
                    } else {
                      return null;
                    }
                  }).where((spot) => spot != null).cast<FlSpot>().toList(),
                  isCurved: false,
                  barWidth: 2,
                  color: const Color(0xFF1F806F),
                  belowBarData: BarAreaData(show: false),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFF1F806F),
                        strokeWidth: 1,
                        strokeColor: Colors.black,
                      );
                    },
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (FlSpot spot) => Colors.grey.shade100,
                  tooltipPadding: const EdgeInsets.all(4),
                  tooltipBorder: BorderSide(color: Colors.grey.shade400),
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      return LineTooltipItem(
                        '${spot.y.toStringAsFixed(1)} kg',
                        const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: pastWeek.map((date) {
        String dateString = date.toIso8601String().split("T")[0];
        bool isSelected = dateString == selectedDate;
        return GestureDetector(
          onTap: () => _showMonthPicker(context), // 클릭 시 달력 띄우기
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
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.blue : Colors.black,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("몸무게 기록"),
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
          _buildWeightGraph(),
          const SizedBox(height: 15),
          Expanded(child: _buildDateSelector()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.carrot), label: "식단"),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: "운동"),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: "몸무게"),
          BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: "솔루션"),
        ],
        currentIndex: 2,
        selectedItemColor: Colors.lightBlueAccent, // 블루 계열
        unselectedItemColor: const Color(0xFF1F806F), // 민트 계열
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