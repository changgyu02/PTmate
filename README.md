# PTmate

## 프로젝트 소개  
PTmate는 AI 기반 개인 트레이너 시스템으로, 사용자의 운동 자세 분석, 맞춤형 트레이닝 솔루션 제공, 실시간 피드백 및 데이터 저장 기능을 지원합니다. MediaPipe 기반 자세 분석, OpenAI ChatGPT를 활용한 맞춤형 운동 및 식단 추천, MongoDB와의 연동을 통한 운동 기록 저장을 통해 개인 맞춤형 피트니스 솔루션을 제공합니다.

---

## 기술 스택  

### **1. 하드웨어 (Hardware)**  
- **Raspberry Pi**: AI 모델 실행 및 운동 데이터 처리  
- **Arduino**: 7세그먼트 디스플레이 및 GPIO 기반 센서 제어  
- **웹캠**: 사용자의 운동 자세 분석 (MediaPipe 기반)  
- **버튼 및 터치 UI**: 라즈베리파이 모니터에서 운동 종류 및 세트 선택  
- **RGB-LED**: 운동 상태 시각적 피드백 제공   
- **7-Segment Display (4ch-7segment)**: 남은 운동 시간 표시  
- **스피커 및 오디오 앰프 모듈**: 운동 가이드 및 피드백 음성 출력   
- **Fusion 360**: 하드웨어 외벽 및 구조 설계  
- **3D 프린터**: PTmate 본체 제작 (탈부착형 상단, 슬라이드형 후면 구조)  

### **2. 소프트웨어 (Software)**  
- **Flutter**: 크로스플랫폼 모바일 앱 개발 (Android & iOS 지원)  
- **Dart**: Flutter 앱 개발 언어  
- **Flutter UI 라이브러리**: Material Design 적용  
- **Flask**: 경량 웹 프레임워크, REST API 서버 구축  
- **FastAPI (확장 가능)**: 고성능 API 서버 최적화 가능  
- **Ngrok**: 로컬 서버를 공인 네트워크에서 접근할 수 있도록 터널링 지원  
- **MongoDB**: NoSQL 기반 데이터베이스, 운동 기록 및 사용자 정보 저장  

### **3. AI 및 머신러닝 (AI & ML)**  
- **OpenAI ChatGPT API** : AI 기반 운동 및 식단 솔루션 제공
- **ChatGPT 3.5-turbo**: 속도 최적화 및 경량 모델 적용  
- **MediaPipe**: 웹캠을 통한 자세 분석 및 동작 인식  
- **OpenCV**: 영상 처리 및 사용자 동작 추적  
- **NumPy, Pandas**: 운동 데이터 분석 및 AI 피드백 최적화  

### **4. 서버 및 네트워크 (Server & Network)**  
- **Ngrok**: 로컬 서버를 외부에서 접근 가능하도록 터널링  
- **REST API**: Flask 기반 API 서버로 앱과 하드웨어 간 통신  
- **JSON 데이터 교환**: 운동 기록, AI 솔루션, 사용자 정보 송수신  
---

##  주요 기능  

### **1. 운동 분석 및 피드백 기능**  
- 운동 자세 인식 및 교정 (MediaPipe 기반 자세 분석)
- 운동 횟수 자동 카운트
- 운동 진행 상태 시각화 (RGB-LED 피드백)    
- 운동 가이드 음성 지원 (스피커 출력)  

### **2. AI 기반 맞춤형 솔루션 제공**  
- 사용자 맞춤 운동 루틴 생성
- 운동 및 식단 솔루션 제공
- 운동 기록 저장 및 조회

### **3. 운동 루틴 관리 및 데이터 저장**  
- 체크리스트 기능 (운동 및 식단 관리)
- 몸무게 이력 관리
- 실시간 서버 연동 및 데이터 관리
  
### **4. 하드웨어 및 앱 연동 기능**  
- 라즈베리파이 기반 UI 제공
- 아두이노 기반 타이머 및 피드백 제공 
- 외부 장치 연결 최적화 (USB 허브 & C타입 연장 케이블 사용) 

---

##  하드웨어 구성도
![image](https://github.com/user-attachments/assets/99d0e1b6-9be4-41b8-8205-de02a769f812)

---

## install
```bash
# 1. Python3 및 pip 최신 버전 업데이트
sudo apt update && sudo apt upgrade -y
sudo apt install python3 python3-pip -y

# 2. 필수 패키지 설치
pip install numpy opencv-python mediapipe pygame requests gpiozero pyserial RPi.GPIO

# 3. OpenCV 설치 (라즈베리파이 최적화)
pip install opencv-python-headless  # GUI 없이 OpenCV 사용 가능

