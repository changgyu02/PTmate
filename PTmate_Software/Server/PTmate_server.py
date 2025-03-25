import subprocess
from flask import Flask, request, jsonify
from pymongo import MongoClient
from APIFunction import *
from datetime import datetime, timedelta, timezone
import time
import random

# Flask 애플리케이션 초기화
app = Flask(__name__)

# OTP 저장 (메모리 캐시)
otp_store = {}

# MongoDB 연결
client = MongoClient("mongodb://localhost:27017")  # 로컬 MongoDB
db = client["PTmate"]  # 데이터베이스 이름
users_collection = db["users"] 
checklist_diet_collection = db["checklists_diet"]
checklist_wo_collection = db["checklists_wo"]
sol_diet_logs_collection = db["sol_diet_logs"]
sol_wo_logs_collection = db["sol_wo_logs"]
weight_logs_collection = db["weight_logs"]

#-----------------------라우트 코드 시작--------------------------------
# 기본 라우트
@app.route('/', methods=['GET'])
def home():
    return jsonify({"message": "Welcome to the Flask server!"})

# 회원가입 라우트
@app.route('/register', methods=['POST'])
def register():
    try:
        data = request.json
        user_id = data.get("_id")

        # 아이디 중복 확인
        if users_collection.find_one({"id": user_id}):
            return jsonify({"success": False}), 400

        # 사용자 데이터 저장
        user_data = {
            "name": data.get("name"),
            "email": data.get("email"),
            "birth": data.get("birth"),
            "_id": user_id,
            "password": data.get("password"),
            "gender": None,
            "age": None,
            "height": None,
            "weight": None,
            "job": None,
            "purpose": None,
            "direction": None,
            "sol_wo": None,
            "sol_diet": None,
            "sol_core_wo": None,
            "sol_core_diet": None
        }
        users_collection.insert_one(user_data)  # MongoDB에 데이터 삽입

        return jsonify({"success": True}), 201

    except Exception:
        return jsonify({"success": False}), 500

# 회원가입 아이디 확인
@app.route('/check_id', methods=['POST'])
def check_id():
    try:
        data = request.json
        user_id = data.get("_id")

        if not user_id:
            return jsonify({"exists": False}), 400

        # 아이디 중복 확인
        if users_collection.find_one({"_id": user_id}):
            return jsonify({"exists": True}), 200
        return jsonify({"exists": False}), 200

    except Exception:
        return jsonify({"exists": False}), 500

# 로그인 라우트
@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.json
        user_id = data.get("_id")
        password = data.get("password")

        # MongoDB에서 사용자 검색
        user = users_collection.find_one({"_id": user_id, "password": password})

        if user:
            sol_diet = user.get("sol_diet")
            sol_wo = user.get("sol_wo")
            direction = user.get("direction")

            return jsonify({
                "success": True,
                "_id": user["_id"],
                "sol_diet": sol_diet,
                "sol_wo": sol_wo,
                "direction": direction
            }), 200
        else:
            return jsonify({"success": False, "message": "Invalid credentials"}), 401

    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

# QR 코드 OTP 생성 (유저 존재 여부 체크 추가)
@app.route('/generate_qr', methods=['POST'])
def generate_qr():
    try:
        data = request.json
        user_id = data.get("_id")

        # 사용자가 존재하는지 확인
        user = users_collection.find_one({"_id": user_id})
        if not user:
            return jsonify({"success": False, "message": "User not found"}), 404

        # 기존 OTP 삭제 후 새 OTP 저장
        otp_store.pop(user_id, None)

        otp_code = str(random.randint(100000, 999999))
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=3)
        expires_at_iso = expires_at.isoformat()

        otp_store[user_id] = {
            "otp": otp_code,
            "expires_at": expires_at_iso
        }

        # QR 코드 데이터 생성
        qr_data = json.dumps({
            "_id": user_id,
            "otp": otp_code,
            "expires_at": expires_at_iso
        })

        print(f"생성된 OTP: {otp_code} (유효기간: {expires_at_iso}) - 사용자: {user_id}")

        # 항상 `qr_data`를 포함하여 응답 반환
        return jsonify({
            "success": True,
            "otp": otp_code,
            "qr_data": qr_data,  
            "expires_at": expires_at_iso
        }), 200

    except Exception as e:
        print(f"QR 코드 생성 오류: {str(e)}")
        return jsonify({"success": False, "message": str(e)}), 500

# QR 코드 OTP 로그인 (만료된 OTP 자동 삭제)
@app.route('/otp_login', methods=['POST'])
def otp_login():
    try:
        data = request.json
        user_id = data.get("_id")
        otp_code = data.get("otp")

        print(f"📡 로그인 요청: user_id={user_id}, otp={otp_code}")  # 서버 로그 추가

        # 🔹 서버에 저장된 최신 OTP 확인
        otp_entry = otp_store.get(user_id)
        if not otp_entry:
            print("OTP 없음 (만료되었거나 삭제됨)")
            return jsonify({"success": False, "message": "OTP 없음"}), 400
        
        print(f"서버 저장된 OTP: {otp_entry['otp']} (만료 시간: {otp_entry['expires_at']})")

        if otp_entry["otp"] != otp_code:
            print(f"OTP 불일치 - 받은 값: {otp_code}, 저장된 값: {otp_entry['otp']}")
            return jsonify({"success": False, "message": "OTP 불일치"}), 401

        # 해결: UTC 시간 비교 오류 수정
        if datetime.now(timezone.utc) > datetime.fromisoformat(otp_entry["expires_at"]):
            del otp_store[user_id]  # 🔹 만료된 OTP 삭제
            print("OTP 만료됨")
            return jsonify({"success": False, "message": "OTP 만료됨"}), 401

        print("OTP 일치 → 로그인 성공!")
        del otp_store[user_id]  # 사용 후 OTP 삭제

        return jsonify({"success": True, "message": "로그인 성공"}), 200

    except Exception as e:
        print(f"서버 오류: {str(e)}")  # 오류 로그 추가
        return jsonify({"success": False, "message": str(e)}), 500

# 솔루션 라우트
@app.route('/solution', methods=['PATCH'])
def solution():
    try:
        data = request.json

        # 요청 본문에서 _id 가져오기
        user_id = data.get("_id")
        if not user_id:
            return jsonify({"success": False, "message": "_id가 누락되었습니다."}), 400

        # 업데이트할 데이터 추출
        updated_data = {
            "gender": data.get("gender"),
            "age": data.get("age"),
            "height": data.get("height"),
            "weight": data.get("weight"),
            "job": data.get("job"),
            "purpose": data.get("purpose"),
            "direction": data.get("direction")
        }

        # MongoDB에서 사용자 정보 업데이트
        result = users_collection.update_one(
            {"_id": user_id},  # 사용자 ID로 검색
            {"$set": updated_data}  # 필드 업데이트
        )

        if result.matched_count == 0:
            return jsonify({"success": False, "message": "사용자를 찾을 수 없습니다."}), 404

        return jsonify({"success": True, "message": "사용자 정보가 업데이트되었습니다."}), 200

    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

# 사용자 검색 라우트
@app.route('/userinfo', methods=['GET', 'PATCH'])
def userinfo():
    # `_id`를 요청에서 가져오기
    user_id = request.args.get("_id") if request.method == 'GET' else request.json.get("_id")
    if not user_id:
        return "", 400

    if request.method == 'GET':
        # `_id`로 사용자 정보 조회
        user = users_collection.find_one({"_id": user_id}, {"password": 0})  # 비밀번호 제외
        if not user:
            return "", 404

        return jsonify({
            "name": user.get("name"),
            "email": user.get("email"),
            "birth": user.get("birth"),
            "_id": user.get("_id"),
        }), 200

    elif request.method == 'PATCH':
        # 업데이트할 필드 가져오기
        data = request.json
        update_fields = {k: v for k, v in data.items() if k != "_id" and v}
        if not update_fields:
            return "", 400

        # 사용자 정보 업데이트
        result = users_collection.update_one({"_id": user_id}, {"$set": update_fields})
        if result.matched_count == 0:
            return "", 404
        if result.modified_count == 0:
            return "", 400

        return "", 200

@app.route('/userinfo/password', methods=['PATCH'])
def update_password():
    # 요청 본문에서 `_id` 가져오기
    data = request.json
    user_id = data.get("_id")
    current_password = data.get("current_password")
    new_password = data.get("new_password")

    if not user_id or not current_password or not new_password:
        return "", 400

    # `_id`로 사용자 조회
    user = users_collection.find_one({"_id": user_id})
    if not user:
        return "", 404

    # 현재 비밀번호 확인
    if current_password != user["password"]:
        return "", 401

    # 새 비밀번호 업데이트
    users_collection.update_one({"_id": user_id}, {"$set": {"password": new_password}})

    return "", 200

@app.route('/userdata', methods=['GET'])
def get_user_data():
    try:
        # 쿼리 매개변수에서 `_id` 가져오기
        user_id = request.args.get("_id")
        if not user_id:
            return "", 400  # 잘못된 요청

        # MongoDB에서 사용자 정보 조회
        user_data = users_collection.find_one({"_id": user_id})
        if user_data:
            return jsonify({
                "name": user_data.get("name"),
                "direction": user_data.get("direction")
            }), 200

        return "", 404  # 사용자 없음

    except Exception as e:
        return "", 500  # 서버 오류

@app.route('/takesol', methods=['GET', 'PATCH'])
def get_solution():
    try:
        # 쿼리 매개변수에서 `_id` 가져오기
        user_id = request.args.get("_id")
        if not user_id:
            return jsonify({"success": False, "message": "사용자 ID가 누락되었습니다."}), 400

        # 사용자 데이터 조회
        user_data = users_collection.find_one({"_id": user_id})
        if not user_data:
            return jsonify({"success": False, "message": "사용자를 찾을 수 없습니다."}), 404

        # 사용자 `direction` 확인
        direction = user_data.get("direction")
        if direction not in ["식단 관리", "운동"]:
            return jsonify({"success": False, "message": "유효하지 않은 direction입니다. (식단 관리 또는 운동만 지원)"}), 400

        # 솔루션 생성 및 핵심 데이터 추출
        try:
            solution = init_API(user_data, direction)  # 전체 솔루션 생성
            solution_core = extract_core(solution, direction)  # 핵심 정보 추출
        except Exception as e:
            return jsonify({"success": False, "message": f"솔루션 생성 중 오류 발생: {str(e)}"}), 500

        # Direction에 따른 필드 매핑
        field_map = {
            "식단 관리": {
                "user_solution_field": "sol_diet",
                "user_core_field": "sol_core_diet",
                "log_collection": sol_diet_logs_collection,
                "log_field": "sol_diet_log"
            },
            "운동": {
                "user_solution_field": "sol_wo",
                "user_core_field": "sol_core_wo",
                "log_collection": sol_wo_logs_collection,
                "log_field": "sol_wo_log"
            }
        }
        fields = field_map[direction]

        # 기존 로그 개수를 기반으로 number 계산
        log_count = fields["log_collection"].count_documents({"_id": user_id}) + 1

        # `user` 컬렉션 업데이트
        try:
            users_collection.update_one(
                {"_id": user_id},
                {"$set": {
                    fields["user_solution_field"]: solution,       # 전체 솔루션 저장
                    fields["user_core_field"]: solution_core       # 핵심 정보 저장
                }}
            )
        except Exception as e:
            return jsonify({"success": False, "message": f"사용자 업데이트 중 오류 발생: {str(e)}"}), 500

        # 로그 컬렉션 업데이트 (배열로 저장)
        try:
            # 기존 log_field가 객체인 경우 배열로 변환
            log_entry = fields["log_collection"].find_one({"_id": user_id})
            if log_entry and isinstance(log_entry.get(fields["log_field"]), dict):
                fields["log_collection"].update_one(
                    {"_id": user_id},
                    {"$set": {fields["log_field"]: [log_entry[fields["log_field"]]]}}
                )

            # 새로운 로그 추가
            fields["log_collection"].update_one(
                {"_id": user_id},
                {
                    "$push": {fields["log_field"]: {
                        "date": datetime.now().strftime("%Y-%m-%d"),  # 현재 날짜 저장
                        "number": log_count,                          # 현재 솔루션 순서
                        fields["user_solution_field"]: solution,      # 전체 솔루션 저장
                        "evaluate": None                              # 초기 평가값은 null
                    }}
                },
                upsert=True
            )
        except Exception as e:
            return jsonify({"success": False, "message": f"솔루션 로그 저장 중 오류 발생: {str(e)}"}), 500

        # 성공적으로 처리된 경우 응답
        return jsonify({
            "success": True,
            "message": f"'{direction}' 솔루션이 성공적으로 생성되었습니다.",
            "solution": solution,
            "core_solution": solution_core,
            "number": log_count
        }), 200

    except Exception as e:
        return jsonify({"success": False, "message": f"서버 오류: {str(e)}"}), 500

@app.route('/checklist_diet', methods=['GET', 'PATCH'])
def checklist_diet():
    if request.method == 'GET':
        user_id = request.args.get("_id")  # 사용자 ID 가져오기
        date = request.args.get("date")  # 날짜 가져오기

        # _id와 date가 없는 경우 에러 반환
        if not user_id or not date:
            return jsonify({"success": False, "message": "Missing _id or date"}), 400

        # MongoDB에서 사용자 데이터 찾기
        user_data = checklist_diet_collection.find_one({"_id": user_id})
        if not user_data:
            return jsonify({"success": True, "data": {}}), 200

        # checklist_diet에서 해당 날짜의 데이터를 찾기
        checklist = user_data.get("checklist_diet", [])
        diet_info = next((item for item in checklist if item["date"] == date), None)

        # 해당 날짜 데이터가 없는 경우
        if not diet_info:
            return jsonify({"success": True, "data": {}}), 200

        # 데이터 반환
        return jsonify({
            "success": True,
            "data": {
                "date": diet_info["date"],
                "breakfast": diet_info.get("breakfast", []),
                "lunch": diet_info.get("lunch", []),
                "dinner": diet_info.get("dinner", [])
            }
        }), 200

    elif request.method == 'PATCH':
        try:
            data = request.json
            user_id = data.get("_id")
            date = data.get("date")
            meal = data.get("meal")
            food = data.get("food")

            # 필요한 필드가 없을 경우 에러 반환
            if not user_id or not date or not meal or not food:
                return jsonify({"success": False, "message": "Missing required fields"}), 400

            # 사용자 데이터 가져오기
            user_data = checklist_diet_collection.find_one({"_id": user_id})

            if not user_data:
                # 사용자 데이터가 없는 경우 새로 추가
                new_data = {
                    "_id": user_id,
                    "checklist_diet": [
                        {
                            "date": date,
                            "breakfast": [] if meal != "breakfast" else [food],
                            "lunch": [] if meal != "lunch" else [food],
                            "dinner": [] if meal != "dinner" else [food],
                        }
                    ]
                }
                checklist_diet_collection.insert_one(new_data)
            else:
                # 기존 데이터가 있는 경우 업데이트
                checklist = user_data.get("checklist_diet", [])
                date_entry = next((item for item in checklist if item["date"] == date), None)

                if date_entry:
                    # 해당 날짜가 있는 경우 업데이트
                    if meal in date_entry:
                        date_entry[meal].append(food)
                    else:
                        date_entry[meal] = [food]
                else:
                    # 해당 날짜가 없는 경우 새로 추가
                    checklist.append({
                        "date": date,
                        "breakfast": [] if meal != "breakfast" else [food],
                        "lunch": [] if meal != "lunch" else [food],
                        "dinner": [] if meal != "dinner" else [food],
                    })

                checklist_diet_collection.update_one(
                    {"_id": user_id},
                    {"$set": {"checklist_diet": checklist}}
                )

            return jsonify({"success": True, "message": "Diet info updated successfully"}), 200

        except Exception as e:
            return jsonify({"success": False, "message": str(e)}), 500

@app.route('/checklist_diet_update', methods=['PATCH'])
def update_diet():
    try:
        data = request.json
        user_id = data.get("_id")
        date = data.get("date")
        meal = data.get("meal")
        food = data.get("food")  # {"food": "닭가슴살", "amount": "150g"}

        if not all([user_id, date, meal, food]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        # MongoDB에서 사용자 데이터 조회
        user_data = checklist_diet_collection.find_one({"_id": user_id})
        if not user_data:
            return jsonify({"success": False, "message": "User not found"}), 404

        checklist = user_data.get("checklist_diet", [])
        updated = False

        for day in checklist:
            if day["date"] == date:
                if meal in day:
                    # 기존 항목 중 조건에 맞는 항목을 탐색
                    for item in day[meal]:
                        if item["food"] == food["original_food"]:
                            # 조건에 맞는 항목을 수정
                            item["food"] = food["food"]
                            item["amount"] = food["amount"]
                            updated = True
                            break

                    if not updated:
                        # 조건에 맞는 항목이 없으면 새 항목 추가
                        day[meal].append({"food": food["food"], "amount": food["amount"]})
                        updated = True
                    break
                else:
                    return jsonify({"success": False, "message": f"Meal '{meal}' not found for the date"}), 404

        if not updated:
            return jsonify({"success": False, "message": "Date or meal not found"}), 404

        # MongoDB 업데이트
        checklist_diet_collection.update_one(
            {"_id": user_id},
            {"$set": {"checklist_diet": checklist}}
        )

        return jsonify({"success": True, "message": "Diet updated successfully"}), 200

    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
    
@app.route('/checklist_diet_delete', methods=['DELETE'])
def delete_diet():
    try:
        data = request.json
        user_id = data.get("_id")
        date = data.get("date")
        meal = data.get("meal")
        food = data.get("food")

        if not all([user_id, date, meal, food]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        user_data = checklist_diet_collection.find_one({"_id": user_id})
        if not user_data:
            return jsonify({"success": False, "message": "User not found"}), 404

        checklist = user_data.get("checklist_diet", [])
        for day in checklist:
            if day["date"] == date and meal in day:
                day[meal] = [item for item in day[meal] if item["food"] != food["food"]]

        checklist_diet_collection.update_one(
            {"_id": user_id},
            {"$set": {"checklist_diet": checklist}}
        )

        return jsonify({"success": True, "message": "Diet deleted"}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

# WebSocket 통신 고려
@app.route('/checklist_wo', methods=['GET', 'PATCH'])
def checklist_wo():
    if request.method == 'GET':
        user_id = request.args.get("_id")  
        date = request.args.get("date")  

        if not user_id or not date:
            return jsonify({"success": False, "message": "Missing _id or date"}), 400

        user_data = checklist_wo_collection.find_one({"_id": user_id})
        if not user_data:
            return jsonify({"success": True, "data": []}), 200

        checklist = user_data.get("checklist_wo", [])
        date_entry = next((item for item in checklist if item["date"] == date), None)

        if not date_entry:
            return jsonify({"success": True, "data": {}}), 200

        # `flattened_data`를 반환하여 wo_id를 유지
        flattened_data = {
            key: value for key, value in date_entry.items()
            if key.startswith("wo") and value  # 빈 값 제외
        }

        return jsonify({"success": True, "data": flattened_data}), 200

    # PATCH 메소드 구현은 기존 코드 유지
    elif request.method == 'PATCH':
        try:
            data = request.json
            user_id = data.get("_id")
            date = data.get("date")
            wo_data = data.get("wo")  # {"wo_name": "스쿼트", "amount": "10개 x 3세트", "checkbox": true}

            if not all([user_id, date, wo_data]):
                return jsonify({"success": False, "message": "Missing required fields"}), 400

            # 사용자 데이터 가져오기
            user_data = checklist_wo_collection.find_one({"_id": user_id})

            if not user_data:
                # 첫 데이터 추가
                new_data = {
                    "_id": user_id,
                    "checklist_wo": [
                        {
                            "date": date,
                            "wo1": wo_data,
                        }
                    ]
                }
                checklist_wo_collection.insert_one(new_data)
            else:
                checklist = user_data.get("checklist_wo", [])
                date_entry = next((item for item in checklist if item["date"] == date), None)

                if date_entry:
                    # 기존 데이터에 새로운 wo_id 추가
                    existing_ids = [
                        int(key[2:]) for key in date_entry.keys() if key.startswith("wo")
                    ]
                    new_wo_id = f"wo{max(existing_ids, default=0) + 1}"
                    date_entry[new_wo_id] = wo_data
                else:
                    # 새로운 날짜 항목 추가
                    new_wo_id = "wo1"
                    checklist.append({"date": date, new_wo_id: wo_data})

                checklist_wo_collection.update_one(
                    {"_id": user_id},
                    {"$set": {"checklist_wo": checklist}}
                )

            return jsonify({"success": True, "message": "Workout info updated successfully"}), 200

        except Exception as e:
            return jsonify({"success": False, "message": str(e)}), 500

        except Exception as e:
            return jsonify({"success": False, "message": str(e)}), 500

# WebSocket 통신 고려
@app.route('/checklist_wo_update', methods=['PATCH'])
def update_workout():
    try:
        data = request.json
        user_id = data.get("_id")
        date = data.get("date")
        wo_id = data.get("wo_id")  # 운동 항목 키 (예: wo1, wo2)
        wo_data = data.get("wo")  # {"original_name": "스쿼트", "wo_name": "런닝", "amount": "30분", "checkbox": "true"}

        if not all([user_id, date, wo_id, wo_data]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        # MongoDB에서 사용자 데이터 조회
        user_data = checklist_wo_collection.find_one({"_id": user_id})
        if not user_data:
            return jsonify({"success": False, "message": "User not found"}), 404

        checklist = user_data.get("checklist_wo", [])
        updated = False

        for day in checklist:
            if day["date"] == date:
                # 기존 항목 중 wo_id가 있는지 확인
                if wo_id in day:
                    # 기존 항목 수정 (문자열 "true"/"false"를 그대로 저장)
                    if day[wo_id]["wo_name"] == wo_data.get("original_name"):
                        day[wo_id] = {
                            "wo_name": wo_data["wo_name"],
                            "amount": wo_data["amount"],
                            "checkbox": wo_data["checkbox"],  # 그대로 저장
                        }
                        updated = True
                        break

        if not updated:
            return jsonify({"success": False, "message": "Workout not found"}), 404

        # MongoDB 업데이트
        checklist_wo_collection.update_one(
            {"_id": user_id},
            {"$set": {"checklist_wo": checklist}}
        )

        return jsonify({"success": True, "message": "Workout updated successfully"}), 200

    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

@app.route('/checklist_wo_delete', methods=['DELETE'])
def delete_wo():
    try:
        data = request.json
        user_id = data.get("_id")  # 사용자 ID
        date = data.get("date")    # 날짜
        wo_id = data.get("wo_id")  # 삭제할 운동 ID

        # 필수 데이터 확인
        if not all([user_id, date, wo_id]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        # 사용자 데이터 가져오기
        user_data = checklist_wo_collection.find_one({"_id": user_id})
        if not user_data:
            return jsonify({"success": False, "message": "User not found"}), 404

        # 해당 날짜의 운동 정보에서 항목 삭제
        checklist = user_data.get("checklist_wo", [])
        for day in checklist:
            if day["date"] == date and wo_id in day:
                del day[wo_id]  # wo_id에 해당하는 항목 삭제
                break

        # MongoDB 업데이트
        checklist_wo_collection.update_one(
            {"_id": user_id},
            {"$set": {"checklist_wo": checklist}}
        )

        return jsonify({"success": True, "message": "Workout deleted successfully"}), 200

    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

@app.route('/get_sol_diet_logs', methods=['GET'])
def get_sol_diet_logs():
    try:
        user_id = request.args.get("_id")
        if not user_id:
            return jsonify({"error": "사용자 ID가 제공되지 않았습니다."}), 400

        # MongoDB에서 _id로 데이터 조회
        user_data = sol_diet_logs_collection.find_one({"_id": user_id})
        if user_data and "sol_diet_log" in user_data:
            sol_diet_logs = user_data["sol_diet_log"]  # 배열 데이터 가져오기
            return jsonify({
                "data": [
                    {
                        "number": log.get("number"),
                        "sol_diet": log.get("sol_diet"),
                        "evaluate": log.get("evaluate", 0)  # 기본값 0
                    } for log in sol_diet_logs  # 배열 반복 처리
                ]
            }), 200

        return jsonify({"error": "식단 로그를 찾을 수 없습니다."}), 404

    except Exception as e:
        return jsonify({"error": "서버 오류가 발생했습니다.", "details": str(e)}), 500

@app.route('/get_sol_wo_logs', methods=['GET'])
def get_sol_wo_logs():
    try:
        user_id = request.args.get("_id")
        if not user_id:
            return jsonify({"error": "사용자 ID가 제공되지 않았습니다."}), 400

        # MongoDB에서 _id로 데이터 조회
        user_data = sol_wo_logs_collection.find_one({"_id": user_id})
        if user_data and "sol_wo_log" in user_data:
            sol_wo_logs = user_data["sol_wo_log"]  # 배열 데이터 가져오기
            return jsonify({
                "data": [
                    {
                        "number": log.get("number"),
                        "sol_wo": log.get("sol_wo"),
                        "evaluate": log.get("evaluate", 0)  # 기본값 0
                    } for log in sol_wo_logs  # 배열 반복 처리
                ]
            }), 200

        return jsonify({"error": "운동 로그를 찾을 수 없습니다."}), 404

    except Exception as e:
        return jsonify({"error": "서버 오류가 발생했습니다.", "details": str(e)}), 500

@app.route('/update_evaluate', methods=['PATCH'])
def update_evaluate():
    try:
        data = request.json
        user_id = data.get("_id")
        evaluate = data.get("evaluate")
        log_type = data.get("type")
        log_number = data.get("number")  # 업데이트할 로그의 번호 추가

        if not user_id or evaluate is None or not log_type or not log_number:
            return jsonify({"error": "필수 데이터가 누락되었습니다."}), 400

        # 선택된 컬렉션에 따라 분기
        collection = sol_diet_logs_collection if log_type == "diet" else sol_wo_logs_collection
        log_field = "sol_diet_log" if log_type == "diet" else "sol_wo_log"

        # 조건 확인: 로그가 존재하는지 먼저 확인
        log_entry = collection.find_one({"_id": user_id})
        if not log_entry:
            return jsonify({"error": "해당 사용자의 로그를 찾을 수 없습니다."}), 404

        # 배열 요소 확인: 해당 로그 번호가 배열에 존재하는지 확인
        matching_log = next((log for log in log_entry.get(log_field, []) if log.get("number") == log_number), None)
        if not matching_log:
            return jsonify({"error": "해당 로그 번호를 찾을 수 없습니다."}), 404

        # 배열에서 특정 `number` 값을 가진 로그의 `evaluate`를 업데이트
        result = collection.update_one(
            {"_id": user_id, f"{log_field}.number": log_number},  # 배열에서 특정 조건 검색
            {"$set": {f"{log_field}.$.evaluate": evaluate}}  # `$` 연산자로 해당 배열 요소 업데이트
        )

        if result.matched_count == 0:
            return jsonify({"error": "로그를 찾을 수 없습니다."}), 404
        if result.modified_count == 0:
            return jsonify({"error": "업데이트가 실패했습니다."}), 400

        return jsonify({"message": "평가가 성공적으로 업데이트되었습니다."}), 200

    except Exception as e:
        return jsonify({"error": "서버 오류가 발생했습니다.", "details": str(e)}), 500

@app.route('/new_solution', methods=['GET', 'PATCH'])
def new_solution():
    if request.method == 'GET':
        user_id = request.args.get('_id')
        if not user_id:
            return jsonify({'error': 'User ID is required'}), 400

        user_data = users_collection.find_one({'_id': user_id})
        if user_data:
            return jsonify(user_data), 200
        else:
            return jsonify({'error': 'User data not found'}), 404

    elif request.method == 'PATCH':
        data = request.json
        user_id = data.get('_id')
        if not user_id:
            return jsonify({'error': 'User ID is required'}), 400

        # 새로 입력된 direction
        new_direction = data.get('direction')

        # 기존 사용자 데이터 가져오기
        user_data = users_collection.find_one({'_id': user_id})
        if not user_data:
            return jsonify({'error': 'User data not found'}), 404

        # direction 비교 및 update_data 생성
        if new_direction == "식단 관리" and "sol_diet" == None :
            update_data = {
                "gender": data.get('gender'),
                "age": data.get('age'),
                "height": data.get('height'),
                "weight": data.get('weight'),
                "job": data.get('job'),
                "purpose": data.get('purpose'),
                "direction": new_direction,
            }
        elif new_direction == "운동" and "sol_wo" == None :
            update_data = {
                "gender": data.get('gender'),
                "age": data.get('age'),
                "height": data.get('height'),
                "weight": data.get('weight'),
                "job": data.get('job'),
                "purpose": data.get('purpose'),
                "direction": new_direction,
            }
        elif new_direction == "식단 관리":
            update_data = {
                "gender": data.get('gender'),
                "age": data.get('age'),
                "height": data.get('height'),
                "weight": data.get('weight'),
                "job": data.get('job'),
                "purpose": data.get('purpose'),
                "direction": new_direction,
                "sol_diet": None,
                "sol_core_diet": None,
            }
        elif new_direction == "운동":
            update_data = {
                "gender": data.get('gender'),
                "age": data.get('age'),
                "height": data.get('height'),
                "weight": data.get('weight'),
                "job": data.get('job'),
                "purpose": data.get('purpose'),
                "direction": new_direction,
                "sol_wo": None,
                "sol_core_wo": None,
            }
        else:
            return jsonify({'error': 'Invalid direction value'}), 400

        result = users_collection.update_one({'_id': user_id}, {'$set': update_data}, upsert=True)

        if result.modified_count > 0 or result.upserted_id:
            return jsonify({'message': 'Solution updated successfully'}), 200
        else:
            return jsonify({'error': 'Failed to update solution'}), 500

@app.route('/new_takesol', methods=['GET', 'PATCH'])
def new_takesol():
    try:
        # 1초 딜레이 추가
        time.sleep(1)

        # 쿼리 매개변수에서 `_id` 가져오기
        user_id = request.args.get("_id")
        if not user_id:
            return jsonify({"success": False, "message": "사용자 ID 누락"}), 400

        # 사용자 데이터 조회
        user_data = users_collection.find_one({"_id": user_id})
        if not user_data:
            return jsonify({"success": False, "message": "사용자를 찾을 수 없습니다."}), 404

        # 사용자 `direction` 확인
        new_direction = user_data.get("direction")
        if new_direction not in ["식단 관리", "운동"]:
            return jsonify({"success": False, "message": "유효하지 않은 direction입니다. (식단 관리 또는 운동만 지원)"}), 400

        # Direction에 따른 필드 매핑
        field_map = {
            "식단 관리": {
                "user_solution_field": "sol_diet",
                "user_core_field": "sol_core_diet",
                "log_collection": sol_diet_logs_collection,
                "log_field": "sol_diet_log"
            },
            "운동": {
                "user_solution_field": "sol_wo",
                "user_core_field": "sol_core_wo",
                "log_collection": sol_wo_logs_collection,
                "log_field": "sol_wo_log"
            }
        }
        fields = field_map[new_direction]

        # 해당 방향의 기존 로그 존재 여부 확인
        log_entry = fields["log_collection"].find_one({"_id": user_id})

        if log_entry:
            # 만족도 점수, 이전 solution 데이터 가져오기
            log_list = log_entry.get(fields["log_field"], [])
            user_satisfaction = log_list[-1].get("evaluate") if log_list else None
            pre_solution = log_list[-1].get(fields["user_solution_field"]) if log_list else None

            # 로그가 있는 경우 리뉴얼 솔루션 생성
            new_solution = renewal_API(user_satisfaction, pre_solution, user_data, new_direction)
            new_solution_core = extract_core(new_solution, new_direction)
            if not new_solution:
                return jsonify({"success": False, "message": "Failed to generate solution"}), 500

            # 기존 로그 개수를 기반으로 number 계산
            log_count = len(log_list) + 1

            # `user` 컬렉션 업데이트
            try:
                users_collection.update_one(
                    {"_id": user_id},
                    {"$set": {
                        fields["user_solution_field"]: new_solution,
                        fields["user_core_field"]: new_solution_core
                    }}
                )
            except Exception as e:
                return jsonify({"success": False, "message": f"사용자 업데이트 중 오류 발생: {str(e)}"}), 500

            # 로그 컬렉션에 새로운 로그 추가
            try:
                fields["log_collection"].update_one(
                    {"_id": user_id},
                    {
                        "$push": {fields["log_field"]: {
                            "date": datetime.now().strftime("%Y-%m-%d"),
                            "number": log_count,
                            fields["user_solution_field"]: new_solution,
                            "evaluate": None
                        }}
                    }
                )
            except Exception as e:
                return jsonify({"success": False, "message": f"로그 추가 중 오류 발생: {str(e)}"}), 500

        else:
            # 로그가 없을 경우 새로운 솔루션 생성
            new_solution = init_API(user_data, new_direction)
            new_solution_core = extract_core(new_solution, new_direction)

            if not new_solution:
                return jsonify({"success": False, "message": "솔루션 생성 중 오류 발생"}), 500

            # `user` 컬렉션 업데이트
            try:
                users_collection.update_one(
                    {"_id": user_id},
                    {"$set": {
                        fields["user_solution_field"]: new_solution,
                        fields["user_core_field"]: new_solution_core
                    }}
                )
            except Exception as e:
                return jsonify({"success": False, "message": f"사용자 업데이트 중 오류 발생: {str(e)}"}), 500

            # 로그 컬렉션 초기화 및 새로운 로그 추가
            try:
                fields["log_collection"].insert_one({
                    "_id": user_id,
                    fields["log_field"]: [{
                        "date": datetime.now().strftime("%Y-%m-%d"),
                        "number": 1,
                        fields["user_solution_field"]: new_solution,
                        "evaluate": None
                    }]
                })
            except Exception as e:
                return jsonify({"success": False, "message": f"로그 초기화 중 오류 발생: {str(e)}"}), 500

        # 성공적으로 처리된 경우 응답
        return jsonify({
            "success": True,
            "message": f"'{new_direction}' 솔루션이 성공적으로 생성되었습니다.",
            "solution": new_solution,
            "core_solution": new_solution_core,
            "number": log_count if log_entry else 1
        }), 200

    except Exception as e:
        return jsonify({"success": False, "message": f"Server Error: {str(e)}"}), 500

@app.route('/get_weight', methods=['GET'])
def get_weight():
    user_id = request.args.get("_id")
    if not user_id:
        return jsonify({"success": False, "message": "Missing user ID"}), 400

    user_data = weight_logs_collection.find_one({"_id": user_id})

    # 사용자의 몸무게 데이터가 없으면 users 컬렉션에서 weight 가져오기
    if not user_data:
        user_info = users_collection.find_one({"_id": user_id})
        if user_info and "weight" in user_info:
            return jsonify({"success": True, "data": {user_info["weight"]}}), 200
        else:
            return jsonify({"success": True, "data": {}}), 200  # 완전히 비어있는 경우

    weights_by_date = {entry["date"]: entry["weight"] for entry in user_data.get("weights", [])}

    return jsonify({"success": True, "data": weights_by_date}), 200

@app.route('/add_weight', methods=['PATCH'])
def add_weight():
    try:
        data = request.json
        user_id = data.get("_id")
        date = data.get("date")
        weight = data.get("weight")

        if not all([user_id, date, weight]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        user_data = weight_logs_collection.find_one({"_id": user_id})
        new_entry = {"date": date, "weight": weight}

        if user_data:
            # 기존 날짜 데이터 제거
            weights = [entry for entry in user_data.get("weights", []) if entry["date"] != date]
            weights.append(new_entry)
            # 날짜순 정렬
            weights.sort(key=lambda x: x["date"])

            weight_logs_collection.update_one(
                {"_id": user_id},
                {"$set": {"weights": weights}}
            )
        else:
            users_collection.update_one(
                {"_id": user_id},
                {"$set": {"weight": weight}}
            )
            weight_logs_collection.insert_one({
                "_id": user_id,
                "weights": [new_entry]
            })

        # 저장 후 바로 최신 데이터 반환
        user_data = weight_logs_collection.find_one({"_id": user_id})
        weights_by_date = {entry["date"]: entry["weight"] for entry in user_data.get("weights", [])}
        return jsonify({"success": True, "message": "Weight saved successfully", "data": weights_by_date}), 200

    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

@app.route('/update_weight', methods=['PATCH'])
def update_weight():
    try:
        data = request.json
        user_id = data.get("_id")
        date = data.get("date")
        new_weight = data.get("weight")

        if not all([user_id, date, new_weight]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        user_data = weight_logs_collection.find_one({"_id": user_id})
        if not user_data:
            return jsonify({"success": False, "message": "User not found"}), 404

        # 날짜별 몸무게 업데이트
        weights = user_data.get("weights", [])
        for entry in weights:
            if entry["date"] == date:
                entry["weight"] = new_weight
                break

        weight_logs_collection.update_one(
            {"_id": user_id},
            {"$set": {"weights": weights}}
        )

        return jsonify({"success": True, "message": "Weight updated successfully"}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

@app.route('/delete_weight', methods=['DELETE'])
def delete_weight():
    try:
        data = request.json
        user_id = data.get("_id")
        date = data.get("date")

        if not all([user_id, date]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        user_data = weight_logs_collection.find_one({"_id": user_id})
        if not user_data:
            return jsonify({"success": False, "message": "User not found"}), 404

        # 해당 날짜 데이터 삭제
        weights = [entry for entry in user_data.get("weights", []) if entry["date"] != date]

        weight_logs_collection.update_one(
            {"_id": user_id},
            {"$set": {"weights": weights}}
        )

        return jsonify({"success": True, "message": "Weight deleted successfully"}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

# Flask 서버 실행
if __name__ == '__main__':
    # ngrok 실행
    print("Starting ngrok...")
    subprocess.Popen(["C:/ngrok/ngrok.exe", "http", "5000"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    # Flask 서버 실행
    app.run(host='0.0.0.0', port=5000, debug=True)