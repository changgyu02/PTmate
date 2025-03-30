#include <Arduino.h>

// 7-Segment 핀 정의
const int segmentPins[8] = {2, 3, 4, 5, 6, 7, 8, 9}; // a, b, c, d, e, f, g, DP
const int digitPins[4] = {10, 11, 12, 13};           // D1, D2, D3, D4

// 숫자 매핑 (a-g 순서)
const byte digits_data[10] = {0xFC, 0x60, 0xDA, 0xF2, 0x66, 0xB6, 0xBE, 0xE4, 0xFE, 0xE6};

// 전역 변수
int currentNumber = 0; // 현재 표시할 숫자
bool newDataReceived = false; // 새로운 데이터 수신 플래그

void setup() {
  // 세그먼트와 자리 선택 핀을 출력으로 설정
  for (int i = 0; i < 8; i++) {
    pinMode(segmentPins[i], OUTPUT);
    digitalWrite(segmentPins[i], LOW);
  }
  for (int i = 0; i < 4; i++) {
    pinMode(digitPins[i], OUTPUT);
    digitalWrite(digitPins[i], HIGH); // 자리 선택 핀은 LOW에서 활성화
  }

  Serial.begin(9600); // UART 통신 시작
}

void loop() {
  // UART 데이터 수신
  if (Serial.available()) {
    String data = Serial.readStringUntil('\n'); // '\n'까지 데이터 읽기
    int receivedNumber = data.toInt();         // 문자열을 정수로 변환

    if (receivedNumber >= 0 && receivedNumber <= 9999) {
      currentNumber = receivedNumber; // 표시할 숫자 업데이트
      newDataReceived = true;         // 새 데이터 수신 플래그 설정
    }
  }

  // 지속적으로 숫자 표시
  displayNumber(currentNumber);
}

// 숫자 표시 함수
void displayNumber(int number) {
  int digits[4] = {0, 0, 0, 0}; // 네 자리 숫자로 변환
  for (int i = 3; i >= 0; i--) {
    digits[i] = number % 10;
    number /= 10;
  }

  // 각 자리 숫자에 대해 세그먼트 점등
  for (int digit = 0; digit < 4; digit++) {
    selectDigit(digit);            // 자리 선택
    lightSegments(digits[digit]);  // 해당 자리 숫자 점등
    delay(5);                      // 멀티플렉싱 시간
    clearSegments();               // 점등 초기화
  }
}

// 자리 선택 함수
void selectDigit(int digit) {
  for (int i = 0; i < 4; i++) {
    digitalWrite(digitPins[i], i == digit ? LOW : HIGH); // 활성화된 자리만 LOW
  }
}

// 세그먼트 점등 함수
void lightSegments(int number) {
  byte segments = digits_data[number];
  for (int i = 0; i < 8; i++) {
    digitalWrite(segmentPins[i], (segments & (1 << (7 - i))) ? HIGH : LOW);
  }
}

// 세그먼트 초기화 함수
void clearSegments() {
  for (int i = 0; i < 8; i++) {
    digitalWrite(segmentPins[i], LOW);
  }
}
