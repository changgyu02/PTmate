# PTmate – AI 기반 개인 트레이너 🏋️‍♂️  

![PTmate Banner](./assets/banner.png)  

## 📌 프로젝트 소개  
PTmate는 **AI 기반 개인 트레이너 시스템**으로, 사용자의 운동 자세 분석, 맞춤형 트레이닝 솔루션 제공, 실시간 피드백 및 데이터 저장 기능을 지원합니다.  
MediaPipe 기반 자세 분석, OpenAI ChatGPT를 활용한 맞춤형 운동 및 식단 추천, MongoDB와의 연동을 통한 운동 기록 저장을 통해 **개인 맞춤형 피트니스 솔루션을 제공합니다.**  

---

## 🚀 기술 스택  

### **1. 하드웨어 (Hardware)**  
✅ **마이크로컨트롤러 및 SBC**  
- **Raspberry Pi**: AI 모델 실행 및 운동 데이터 처리  
- **Arduino**: 7세그먼트 디스플레이 및 GPIO 기반 센서 제어  

✅ **입력 및 센서 장치**  
- **웹캠**: 사용자의 운동 자세 분석 (MediaPipe 기반)  
- **버튼 및 터치 UI**: 라즈베리파이 모니터에서 운동 종류 및 세트 선택  
- **RGB-LED**: 운동 상태 시각적 피드백 제공  
  - 🟢 초록: 휴식  
  - 🔴 빨강: 운동 중  
  - 🔵 파랑: 운동 완료  
  - 🔴 빨강 점멸: 운동 준비  

✅ **출력 장치**  
- **7-Segment Display (4ch-7segment)**: 남은 운동 시간 표시  
- **스피커 및 오디오 앰프 모듈**: 운동 가이드 및 피드백 음성 출력  

✅ **3D 프린팅 케이스**  
- **Fusion 360**: 하드웨어 외벽 및 구조 설계  
- **3D 프린터**: PTmate 본체 제작 (탈부착형 상단, 슬라이드형 후면 구조)  

---

### **2. 소프트웨어 (Software)**  
✅ **프론트엔드 (Front-End)**  
- **Flutter**: 크로스플랫폼 모바일 앱 개발 (Android & iOS 지원)  
- **Dart**: Flutter 앱 개발 언어  
- **Flutter UI 라이브러리**: Material Design 적용  

✅ **백엔드 (Back-End)**  
- **Flask**: 경량 웹 프레임워크, REST API 서버 구축  
- **FastAPI (확장 가능)**: 고성능 API 서버 최적화 가능  
- **Ngrok**: 로컬 서버를 공인 네트워크에서 접근할 수 있도록 터널링 지원  

✅ **데이터베이스 (Database)**  
- **MongoDB**: NoSQL 기반 데이터베이스, 운동 기록 및 사용자 정보 저장  
  - **users**: 사용자 정보 저장  
  - **checklists_wo, checklists_diet**: 운동 및 식단 체크리스트 저장  
  - **sol_wo_logs, sol_diet_logs**: AI 솔루션 로그 저장  
  - **weight_logs**: 사용자의 몸무게 변화 이력 저장  

---

### **3. AI 및 머신러닝 (AI & ML)**  
- **OpenAI ChatGPT API**  
  - **ChatGPT 3.5-turbo**: 속도 최적화 및 경량 모델 적용  
  - AI 기반 운동 및 식단 솔루션 제공  
- **MediaPipe**: 웹캠을 통한 자세 분석 및 동작 인식  
- **OpenCV**: 영상 처리 및 사용자 동작 추적  
- **NumPy, Pandas**: 운동 데이터 분석 및 AI 피드백 최적화  

---

### **4. 서버 및 네트워크 (Server & Network)**  
- **Ngrok**: 로컬 서버를 외부에서 접근 가능하도록 터널링  
- **REST API**: Flask 기반 API 서버로 앱과 하드웨어 간 통신  
- **JSON 데이터 교환**: 운동 기록, AI 솔루션, 사용자 정보 송수신  

---

### **5. 개발 및 배포 (Development & Deployment)**  
- **GitHub**: 코드 버전 관리 및 협업  
- **VS Code / PyCharm**: Python 및 Flask 개발 환경  
- **Android Studio**: Flutter 기반 모바일 앱 개발  

---

### **6. 향후 확장 가능 기술**  
🔹 **모바일 앱 최적화**  
- Flutter Web 지원을 통해 웹 기반 PTmate 대시보드 제공 가능  
- Firebase 연동을 통한 실시간 데이터 업데이트 가능  

🔹 **AI 모델 개선**  
- AI 기반 운동 데이터 학습을 위한 **TensorFlow 모델 추가 가능**  
- GPT-4o를 활용한 **더 정밀한 트레이닝 분석 및 추천 시스템 개발 가능**  

🔹 **서버 확장 및 성능 개선**  
- FastAPI로 서버 성능 최적화 및 속도 향상  
- AWS Lambda 또는 Firebase Functions 적용 가능  

---

## 🎯 주요 기능  

### **1. 운동 분석 및 피드백 기능**  
✅ **운동 자세 인식 및 교정 (MediaPipe 기반 자세 분석)**  
- 웹캠을 통해 사용자의 운동 동작을 실시간 
