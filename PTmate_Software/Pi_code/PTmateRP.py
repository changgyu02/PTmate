import time
import cv2
import mediapipe as mp
import serial
import pygame
import requests
import os
import math
import RPi.GPIO as GPIO
from gpiozero import RGBLED, Button
import threading
import numpy as np

# Pin setup
rgb_led = RGBLED(red=25, green=24, blue=23)  # RGB LED 핀 연결
button = Button(26)  # 버튼 핀 설정
# UART 설정 (아두이노 통신)
arduino = serial.Serial('/dev/ttyACM0', 9600)

# OpenAI API Key 설정
OPENAI_API_KEY = ""

# 0. PTmate-LogIN 함수 정의

# 1. 메인 프로그램 실행
def main_program():
    button.wait_for_press()  # 버튼이 눌리면 실행
    play_tts_async("안녕하세요 PTmate입니다! 오늘도 즐거운 운동을 해볼까요? 운동 종류와 시간을 선택해주세요.")
    selected_workout, set_count, target_count, time_limit, rest_time = display_pygame_ui()  # 운동 및 설정 선택
    print(f"selected_workout : {selected_workout}, set_count : {set_count}, target_count : {target_count}, time_limit : {time_limit}")
    play_tts_async(f"{selected_workout}를 선택하셨습니다! 10초 후 시작합니다! 준비해주세요!")
    # 운동 시작 전 준비 단계를 알리는 LED 제어
    for _ in range(10):
        rgb_led.color = (1, 0, 0)  # 빨간색
        time.sleep(0.25)
        rgb_led.off()
        time.sleep(0.25)
    if selected_workout == "Squat":
        sucess = run_squat_workout(set_count, target_count, time_limit, rest_time)
        if sucess:
          play_tts("운동을 성공적으로 마쳤습니다! 수고하셨습니다!")
        else:
          play_tts("운동을 정상적으로 수행하지 못했습니다. 다음엔 화이팅 해봐요")

    elif selected_workout == "Push-up":
        sucess = run_pushup_workout(set_count, target_count, time_limit, rest_time)
        if sucess:
          play_tts("운동을 성공적으로 마쳤습니다! 수고하셨습니다!")
        else:
          play_tts("운동을 정상적으로 수행하지 못했습니다. 다음엔 화이팅 해봐요")

    elif selected_workout == "Dumbbell":
        sucess = run_dumbbell_workout(set_count, target_count, time_limit, rest_time)
        if sucess:
          play_tts("운동을 성공적으로 마쳤습니다! 수고하셨습니다!")
        else:
          play_tts("운동을 정상적으로 수행하지 못했습니다. 다음엔 화이팅 해봐요")

# 2. 메인 UI
def display_pygame_ui():
    pygame.init()

    # 화면 설정 (전체 화면 적용)
    WIDTH, HEIGHT = 800, 480
    screen = pygame.display.set_mode((WIDTH, HEIGHT), pygame.FULLSCREEN)
    pygame.display.set_caption("Workout Selection")

    # 색상 정의
    BACKGROUND_COLOR = (240, 240, 240)
    BUTTON_COLOR = (200, 200, 200)
    BUTTON_HIGHLIGHT = (0, 150, 255)
    TEXT_COLOR = (50, 50, 50)
    CONFIRM_COLOR = (60, 180, 75)
    DELETE_COLOR = (255, 100, 100)

    # 폰트 설정
    font_large = pygame.font.Font(None, 50)
    font = pygame.font.Font(None, 35)

    # UI 요소
    title_text = font_large.render("PTmate", True, TEXT_COLOR)
    title_rect = title_text.get_rect(center=(WIDTH // 2, 40))

    # 운동 버튼
    buttons = {
        "Squat": pygame.Rect(100, 80, 180, 70),
        "Push-up": pygame.Rect(310, 80, 180, 70),
        "Dumbbell": pygame.Rect(520, 80, 180, 70)
    }
    selected_workout = None

    # 설정값 입력 필드
    input_fields = {"Set count": "3", "Goal count": "5", "Time limit": "30", "Rest time": "10"}
    input_active = None
    numpad_visible = False

    # 확인 버튼
    confirm_button = pygame.Rect(325, 400, 150, 50)

    # 숫자 키패드 설정
    def draw_numpad():
        base_x, base_y = 570, 200
        button_size = 55
        spacing = 7
        numpad_buttons = []

        for i in range(9):
            x = base_x + (i % 3) * (button_size + spacing)
            y = base_y + (i // 3) * (button_size + spacing)
            numpad_buttons.append(pygame.Rect(x, y, button_size, button_size))

        zero_button = pygame.Rect(base_x, base_y + 3 * (button_size + spacing), button_size, button_size)
        delete_button = pygame.Rect(base_x + (button_size + spacing), base_y + 3 * (button_size + spacing), button_size * 2 + spacing, button_size)

        numpad_buttons.append(zero_button)
        numpad_buttons.append(delete_button)

        return numpad_buttons

    numpad_buttons = draw_numpad()

    # 메인 루프
    running = True
    while running:
        screen.fill(BACKGROUND_COLOR)
        screen.blit(title_text, title_rect)

        # 운동 버튼 그리기
        for label, button in buttons.items():
            color = BUTTON_HIGHLIGHT if selected_workout == label else BUTTON_COLOR
            pygame.draw.rect(screen, color, button, border_radius=15)
            text = font.render(label, True, TEXT_COLOR)
            text_rect = text.get_rect(center=button.center)
            screen.blit(text, text_rect)

        # 확인 버튼
        pygame.draw.rect(screen, CONFIRM_COLOR, confirm_button, border_radius=15)
        confirm_text = font.render("Confirm", True, (0, 0, 0))
        screen.blit(confirm_text, confirm_text.get_rect(center=confirm_button.center))

        # 입력 필드
        start_y = 180
        for idx, (key, value) in enumerate(input_fields.items()):
            y_pos = start_y + idx * 45
            rect = pygame.Rect(100, y_pos, 400, 40)
            pygame.draw.rect(screen, (220, 220, 220), rect, border_radius=10)
            text = font.render(f"{key}: {value}", True, TEXT_COLOR)
            screen.blit(text, text.get_rect(center=rect.center))

        # 숫자 키패드
        if numpad_visible:
            for i, button in enumerate(numpad_buttons[:-1]):
                pygame.draw.rect(screen, (180, 180, 180), button, border_radius=15)
                num_text = font.render(str(i + 1) if i < 9 else "0", True, (0, 0, 0))
                screen.blit(num_text, num_text.get_rect(center=button.center))

            pygame.draw.rect(screen, DELETE_COLOR, numpad_buttons[-1], border_radius=15)
            delete_text = font.render("Delete", True, (0, 0, 0))
            screen.blit(delete_text, delete_text.get_rect(center=numpad_buttons[-1].center))

        pygame.display.flip()

        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:  # ESC 키로 종료
                    running = False
            elif event.type == pygame.MOUSEBUTTONDOWN:
                # 운동 버튼 클릭 처리
                for label, button in buttons.items():
                    if button.collidepoint(event.pos):
                        selected_workout = label

                # 확인 버튼 클릭 시 종료
                if confirm_button.collidepoint(event.pos) and selected_workout:
                    running = False

                # 입력 필드 클릭 시 숫자 키패드 표시
                for idx, key in enumerate(input_fields.keys()):
                    y_pos = start_y + idx * 45
                    rect = pygame.Rect(100, y_pos, 400, 40)
                    if rect.collidepoint(event.pos):
                        input_active = key
                        numpad_visible = True

                # 숫자 키패드 입력 처리
                if numpad_visible:
                    for i, button in enumerate(numpad_buttons[:-1]):
                        if button.collidepoint(event.pos) and input_active:
                            input_fields[input_active] += str(i + 1) if i < 9 else "0"

                    # 삭제 버튼 클릭 시
                    if numpad_buttons[-1].collidepoint(event.pos) and input_active:
                        input_fields[input_active] = input_fields[input_active][:-1]

    pygame.quit()
    return selected_workout, int(input_fields["Set count"]), int(input_fields["Goal count"]), int(input_fields["Time limit"]), int(input_fields["Rest time"])


# 3. OpenAI TTS API를 호출하여 음성 출력 (스레드 방식)
def play_tts_async(message):
    """TTS를 별도의 스레드에서 실행하여 운동 감지가 멈추지 않도록 함"""
    tts_thread = threading.Thread(target=play_tts, args=(message,))
    tts_thread.daemon = True  # 프로그램 종료 시 스레드도 자동 종료
    tts_thread.start()

def play_tts(message):
    """OpenAI API를 이용해 음성 출력"""
    url = "https://api.openai.com/v1/audio/speech"
    headers = {"Authorization": f"Bearer {OPENAI_API_KEY}", "Content-Type": "application/json"}
    data = {"model": "tts-1", "input": message, "voice": "alloy"}

    response = requests.post(url, json=data, headers=headers)
    if response.status_code == 200:
        with open("tts_output.mp3", "wb") as f:
            f.write(response.content)
        os.system("mpg321 tts_output.mp3")
    else:
        print("TTS API 오류:", response.text)


# 4. 스쿼트 운동 감지
def run_squat_workout(total_sets, goal_count, time_limit, rest_time):
    """ 스쿼트 감지 및 피드백 제공 (LCD 및 부저 없이 최적화) """
    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 800)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    if not cap.isOpened():
        print("Error: Unable to access the webcam.")
        return False

    mp_pose = mp.solutions.pose
    pose = mp_pose.Pose()
    mp_drawing = mp.solutions.drawing_utils

    results_summary = []
    success_sets = 0

    for set_number in range(1, total_sets + 1):
        squat_count = 0
        in_squat = False
        squat_hold_time = None  # 스쿼트 유지 시간 체크
        start_time = time.time()

        print(f"Starting Set {set_number}...")

        if set_number == 1:
            play_tts_async("바르게 서서 운동을 시작해주세요.")

        play_tts_async("운동을 시작합니다!")
        rgb_led.color = (1, 0, 0)  # 빨간색 (운동 중)

        try:
            while True:
                elapsed_time = time.time() - start_time
                remaining_time = max(0, time_limit - int(elapsed_time))
                send_to_arduino(remaining_time)

                if elapsed_time >= time_limit:
                    break

                ret, frame = cap.read()
                if not ret:
                    print("Error: Unable to read from the webcam.")
                    break

                image = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                results = pose.process(image)
                frame = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)

                if results.pose_landmarks:
                    mp_drawing.draw_landmarks(frame, results.pose_landmarks, mp_pose.POSE_CONNECTIONS,
                                              mp_drawing.DrawingSpec(color=(0, 255, 0), thickness=2, circle_radius=3),
                                              mp_drawing.DrawingSpec(color=(0, 0, 255), thickness=2))
                    landmarks = results.pose_landmarks.landmark

                    # 좌우 무릎 각도 계산
                    left_hip = [landmarks[mp_pose.PoseLandmark.LEFT_HIP.value].x,
                                landmarks[mp_pose.PoseLandmark.LEFT_HIP.value].y]
                    left_knee = [landmarks[mp_pose.PoseLandmark.LEFT_KNEE.value].x,
                                 landmarks[mp_pose.PoseLandmark.LEFT_KNEE.value].y]
                    left_ankle = [landmarks[mp_pose.PoseLandmark.LEFT_ANKLE.value].x,
                                  landmarks[mp_pose.PoseLandmark.LEFT_ANKLE.value].y]

                    right_hip = [landmarks[mp_pose.PoseLandmark.RIGHT_HIP.value].x,
                                 landmarks[mp_pose.PoseLandmark.RIGHT_HIP.value].y]
                    right_knee = [landmarks[mp_pose.PoseLandmark.RIGHT_KNEE.value].x,
                                  landmarks[mp_pose.PoseLandmark.RIGHT_KNEE.value].y]
                    right_ankle = [landmarks[mp_pose.PoseLandmark.RIGHT_ANKLE.value].x,
                                   landmarks[mp_pose.PoseLandmark.RIGHT_ANKLE.value].y]

                    left_knee_angle = calculate_angle(left_hip, left_knee, left_ankle)
                    right_knee_angle = calculate_angle(right_hip, right_knee, right_ankle)
                    knee_angle = (left_knee_angle + right_knee_angle) / 2  # 평균 각도

                    # 힙 높이 확인
                    hip_y = (left_hip[1] + right_hip[1]) / 2  # 힙의 평균 y 좌표
                    knee_y = (left_knee[1] + right_knee[1]) / 2  # 무릎의 평균 y 좌표

                    # ✅ 스쿼트 감지 (90도 이하, 그리고 일정 높이 내려간 경우)
                    if knee_angle <= 90 and knee_y > hip_y:
                        if squat_hold_time is None:  # ✅ 처음 90도 이하로 내려갔을 때만 기록
                            squat_hold_time = time.time()

                        if time.time() - squat_hold_time >= 0.7:  # ✅ 0.7초 이상 유지해야 카운트됨
                            in_squat = True

                    # ✅ 스쿼트 카운트 증가 (다시 일어날 때)
                    if knee_angle > 110 and in_squat: #앉았을 때
                        in_squat = False
                        squat_hold_time = None  # ✅ 다음 동작을 위해 초기화
                        squat_count += 1
                        play_tts_async(f"{squat_count}!")


                    # 카운트 정보 화면 출력
                    cv2.putText(frame, f"Knee Angle: {int(knee_angle)}", (50, 100),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                    cv2.putText(frame, f"Squat Count: {squat_count}/{goal_count}", (50, 150),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                    cv2.putText(frame, f"Set: {set_number}/{total_sets}", (50, 50),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 0, 0), 2)
                    cv2.putText(frame, f"in_squat: {in_squat}", (50, 200),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 0, 0), 2)


                cv2.imshow('Squat Detection', frame)

                if squat_count >= goal_count:
                    results_summary.append(f"Set {set_number}: 성공")
                    success_sets += 1
                    break

                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break

        finally:
            if set_number < total_sets:
                rest_period(set_number, total_sets, rest_time)

    cap.release()
    cv2.destroyAllWindows()

    rgb_led.color = (0, 0, 1)  # 파란색 (운동 완료)
    time.sleep(5)
    rgb_led.off()

    play_tts_async(f"총 {total_sets}세트중 {success_sets}세트를 성공하셨습니다!")
    time.sleep(5)
    final = False
    if total_sets == success_sets:
        final = True
    else:
        final = False
    return final

# 5. 푸쉬업
def run_pushup_workout(total_sets, goal_count, time_limit, rest_time):
    """ 여러 세트의 푸쉬업 운동 감지 및 포즈 랜드마크 시각화 """
    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 800)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    if not cap.isOpened():
        print("Error: Unable to access the webcam.")
        return False

    mp_pose = mp.solutions.pose
    pose = mp_pose.Pose()
    mp_drawing = mp.solutions.drawing_utils

    results_summary = []
    success_sets = 0

    for set_number in range(1, total_sets + 1):
        pushup_count = 0
        in_pushup = False
        pushup_hold_time = None  # 푸쉬업 유지 시간 체크
        start_time = time.time()

        print(f"Starting Set {set_number}...")

        if set_number == 1:
            play_tts_async("푸쉬업 자세를 취해주세요.")

        rgb_led.color = (1, 0, 0)  # 운동 시작 LED (빨간색)

        try:
            while True:
                elapsed_time = time.time() - start_time
                remaining_time = max(0, time_limit - int(elapsed_time))
                send_to_arduino(remaining_time)

                if elapsed_time >= time_limit:
                    break

                ret, frame = cap.read()
                if not ret:
                    print("Error: Unable to read from the webcam.")
                    break

                image = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                results = pose.process(image)
                frame = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)

                if results.pose_landmarks:
                    mp_drawing.draw_landmarks(frame, results.pose_landmarks, mp_pose.POSE_CONNECTIONS,
                                              mp_drawing.DrawingSpec(color=(0, 255, 0), thickness=2, circle_radius=3),
                                              mp_drawing.DrawingSpec(color=(0, 0, 255), thickness=2))

                    landmarks = results.pose_landmarks.landmark
                    shoulder = [landmarks[mp_pose.PoseLandmark.LEFT_SHOULDER.value].x,
                                landmarks[mp_pose.PoseLandmark.LEFT_SHOULDER.value].y]
                    elbow = [landmarks[mp_pose.PoseLandmark.LEFT_ELBOW.value].x,
                             landmarks[mp_pose.PoseLandmark.LEFT_ELBOW.value].y]
                    wrist = [landmarks[mp_pose.PoseLandmark.LEFT_WRIST.value].x,
                             landmarks[mp_pose.PoseLandmark.LEFT_WRIST.value].y]

                    elbow_angle = calculate_angle(shoulder, elbow, wrist)
                    cv2.putText(frame, f"Elbow Angle: {int(elbow_angle)}", (50, 250),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)

                    # ✅ 1. 푸쉬업 유지 시간 체크 (빠른 동작 방지)
                    if elbow_angle <= 90:
                        if pushup_hold_time is None:  # ✅ 내려가기 시작한 시간 기록 (최초 1회)
                            pushup_hold_time = time.time()

                        if time.time() - pushup_hold_time >= 0.7:  # ✅ 0.7초 이상 유지해야 카운트됨
                            in_pushup = True

                    # ✅ 2. 푸쉬업 카운트 증가 (팔이 다 펴졌을 때)
                    if elbow_angle > 150 and in_pushup:
                        in_pushup = False
                        pushup_hold_time = None  # ✅ 다음 동작을 위해 초기화
                        pushup_count += 1
                        play_tts_async(f"{pushup_count}!")


                    # 카운트 및 세트 정보 OpenCV 화면에 출력
                    cv2.putText(frame, f"Push-up: {pushup_count}/{goal_count}", (50, 100),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                    cv2.putText(frame, f"Set: {set_number}/{total_sets}", (50, 200),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
                    cv2.putText(frame, f"in_pushup: {in_pushup}", (50, 300),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)

                cv2.imshow('Push-up Workout', frame)

                if pushup_count >= goal_count:
                    results_summary.append(f"Set {set_number}: 성공")
                    success_sets += 1
                    break

                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break

        finally:
            if set_number < total_sets:
                rest_period(set_number, total_sets, rest_time)

    cap.release()
    cv2.destroyAllWindows()

    rgb_led.color = (0, 0, 1)  # 파란색 (운동 완료)
    time.sleep(5)
    rgb_led.off()

    play_tts_async(f"총 {total_sets}세트중 {success_sets}세트를 성공하셨습니다!")
    time.sleep(5)
    final = False
    if total_sets == success_sets:
        final = True
    else:
        final = False
    return final


# 6. 덤밸
def run_dumbbell_workout(total_sets, goal_count, time_limit, rest_time):
    """ 여러 세트의 덤벨 운동 감지 및 포즈 랜드마크 시각화 """
    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 800)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    if not cap.isOpened():
        print("Error: Unable to access the webcam.")
        return False

    mp_pose = mp.solutions.pose
    pose = mp_pose.Pose()
    mp_drawing = mp.solutions.drawing_utils  # Mediapipe 랜드마크 그리기 유틸

    results_summary = []
    success_sets = 0

    for set_number in range(1, total_sets + 1):
        dumbbell_count = 0
        in_curl = False
        curl_hold_time = None  # 컬 유지 시간 체크
        start_time = time.time()

        print(f"Starting Set {set_number}...")

        # 처음 한 번만 측면 촬영 안내
        if set_number == 1:
            play_tts_async("카메라는 측면에 배치해주세요. 덤벨 운동 감지가 더 정확합니다.")

        rgb_led.color = (1, 0, 0)  # 빨간색 (운동 중)

        try:
            while True:
                elapsed_time = time.time() - start_time
                remaining_time = max(0, time_limit - int(elapsed_time))
                send_to_arduino(remaining_time)  # 남은 시간을 아두이노로 전송

                if elapsed_time >= time_limit:
                    break

                ret, frame = cap.read()
                if not ret:
                    print("Error: Unable to read from the webcam.")
                    break

                image = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                results = pose.process(image)
                frame = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)  # 다시 BGR로 변환 (OpenCV는 BGR 사용)

                if results.pose_landmarks:
                    # Mediapipe 랜드마크와 연결선 그리기
                    mp_drawing.draw_landmarks(frame, results.pose_landmarks, mp_pose.POSE_CONNECTIONS,
                                              mp_drawing.DrawingSpec(color=(0, 255, 0), thickness=2, circle_radius=3),
                                              mp_drawing.DrawingSpec(color=(0, 0, 255), thickness=2))

                    # 랜드마크 좌표 가져오기
                    landmarks = results.pose_landmarks.landmark
                    shoulder = [landmarks[mp_pose.PoseLandmark.LEFT_SHOULDER.value].x,
                                landmarks[mp_pose.PoseLandmark.LEFT_SHOULDER.value].y]
                    elbow = [landmarks[mp_pose.PoseLandmark.LEFT_ELBOW.value].x,
                             landmarks[mp_pose.PoseLandmark.LEFT_ELBOW.value].y]
                    wrist = [landmarks[mp_pose.PoseLandmark.LEFT_WRIST.value].x,
                             landmarks[mp_pose.PoseLandmark.LEFT_WRIST.value].y]

                    # 팔꿈치 각도 계산 및 표시
                    elbow_angle = calculate_angle(shoulder, elbow, wrist)
                    cv2.putText(frame, f"Elbow Angle: {int(elbow_angle)}", (50, 250),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)

                    # ✅ 덤벨 컬 유지 시간 체크 (빠른 동작 방지)
                    if elbow_angle < 45:
                        if curl_hold_time is None:  # ✅ 처음 45도 이하로 내려갔을 때만 기록
                            curl_hold_time = time.time()

                        if time.time() - curl_hold_time >= 0.7:  # ✅ 0.7초 이상 유지해야 카운트됨
                            in_curl = True

                    # ✅ 덤벨 카운트 증가 (팔을 다시 내렸을 때)
                    elif elbow_angle > 135 and in_curl:
                        in_curl = False
                        curl_hold_time = None  # ✅ 다음 동작을 위해 초기화
                        dumbbell_count += 1
                        play_tts_async(f"{dumbbell_count}!")

                    # 카운트 및 세트 정보 OpenCV 화면에 출력
                    cv2.putText(frame, f"Dumbbell: {dumbbell_count}/{goal_count}", (50, 100),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

                cv2.imshow('Dumbbell Workout', frame)

                if dumbbell_count >= goal_count:
                    results_summary.append(f"Set {set_number}: 성공")
                    success_sets += 1
                    break

                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break
            else:
                results_summary.append(f"Set {set_number}: 실패")

        finally:
            if set_number < total_sets:
                rest_period(set_number, total_sets, rest_time)

    cap.release()
    cv2.destroyAllWindows()

    rgb_led.color = (0, 0, 1)  # 파란색 (운동 완료)
    time.sleep(5)
    rgb_led.off()

    play_tts_async(f"총 {total_sets}세트중 {success_sets}세트를 성공하셨습니다!")
    time.sleep(5)
    final = False
    if total_sets == success_sets:
        final = True
    else:
        final = False
    return final

# 7. 각도 계산
def calculate_angle(a, b, c):
    """ 세 점 a, b, c를 받아 각도를 계산 """
    ab = [b[0] - a[0], b[1] - a[1]]
    bc = [c[0] - b[0], c[1] - b[1]]
    dot_product = ab[0] * bc[0] + ab[1] * bc[1]
    magnitude_ab = math.sqrt(ab[0] ** 2 + ab[1] ** 2)
    magnitude_bc = math.sqrt(bc[0] ** 2 + bc[1] ** 2)
    angle = math.acos(dot_product / (magnitude_ab * magnitude_bc))
    return math.degrees(angle)

# 8. 아두이노로 남은 시간 전송
def send_to_arduino(remaining_time):
    """ 남은 시간을 아두이노로 전송 """
    message = str(remaining_time) + '\n'  # '\n'은 메시지 끝을 알림
    arduino.write(message.encode())  # 메시지를 UTF-8로 인코딩 후 전송

# 9. 세트 종료 후 휴식 안내
def rest_period(set_number, set_count, rest_time):
    """세트 종료 후 휴식 시간을 제공"""
    if set_number >= set_count:
        rgb_led.color = (0, 0, 1)  # 파란색 (최종 휴식)
    else:
        rgb_led.color = (0, 1, 0)  # 초록색 (세트 간 휴식)

    play_tts(f"{set_number}세트를 종료합니다! 수고하셨습니다!")
    play_tts_async(f"지금부터 {rest_time}초 동안 휴식시간을 가집니다. 다음 세트를 위해 편히 쉬어주세요!")

    # OpenCV로 "Resting..." 텍스트만 표시
    rest_screen = np.zeros((480, 800, 3), dtype=np.uint8)  # 검은 배경 생성
    cv2.putText(rest_screen, "Resting...", (250, 200), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
    cv2.imshow("Rest Mode", rest_screen)

    # 남은 시간만 아두이노로 전송
    for remaining in range(rest_time, 0, -1):
        send_to_arduino(f"REST,{remaining}")
        time.sleep(1)  # 1초 대기 (불필요한 화면 갱신 제거)

    cv2.destroyWindow("Rest Mode")  # 휴식 종료 후 창 닫기
    rgb_led.off()  # LED 끄기

# Main program
try:
    main_program()
except KeyboardInterrupt:
    print("Program interrupted.")
finally:
    GPIO.cleanup()
    if arduino.is_open:
        arduino.close()
