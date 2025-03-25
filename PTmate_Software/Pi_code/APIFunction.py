from openai import OpenAI
import re
import json

# OpenAI API 호출
client = OpenAI(api_key="")  # API 키를 입력하세요.

# 맨 처음에 이용할 API
def init_API(user_data, direction):
    """
    OpenAI API를 호출하여 고객의 정보와 direction(방향)에 따라 맞춤형 솔루션을 제공.

    Parameters:
        user_data (dict): 고객 정보(성별, 나이, 키, 몸무게, 직업 등).
        direction (str): "식단 관리" 또는 "운동" 등 AI 시스템 명령에 영향을 줄 방향.

    Returns:
        str: OpenAI API의 응답 내용.
    """
    # 고객 데이터를 JSON 문자열로 변환
    user_data_Str = json.dumps(user_data, ensure_ascii=False)
    
    # 시스템 메시지 설정
    if direction == "식단 관리":
        system_message = """당신은 유능한 헬스트레이너 역할을 수행하는 AI입니다. 
        고객의 개인 정보를 기반으로 하루 총 칼로리 섭취량과 아침, 점심, 저녁, 간식을 포함한 
        구체적인 식단 계획을 작성합니다. 고객의 목적에 맞는 식단을 추천하며, 친절하고 동기 부여적인 
        태도로 답변하세요. 솔루션에서 반드시 아래 형식을 유지하세요 : 
        
        - 아침: [추천 음식]
        - 점심: [추천 음식]
        - 저녁: [추천 음식]
        - 간식: [추천 음식]"""

    elif direction == "운동":
        system_message = """당신은 유능한 헬스트레이너 역할을 수행하는 AI입니다. 
        고객의 개인 정보를 기반으로 효과적인 운동 계획을 작성하세요. 
        고객의 직업을 고려하여 회사나 학교에서도 실천할 수 있는 간단한 운동법과 시간을 포함한 
        맞춤형 운동 루틴을 추천하세요. 고객의 현재 상태와 목표를 고려하여 구체적인 시간을 명시하고, 
        친절하고 실질적인 조언을 포함하세요.

        운동 계획은 반드시 다음 형식을 따라야 하며, 2. 추천 운동 계획과 3. 집에서 가능한 간단한 운동은 하나씩이면 충분합니다!
        1. 운동 목표: 고객의 건강 상태와 목적(예: 체중 감량, 근력 강화 등)에 따른 구체적인 목표를 서술하세요.
        2. 추천 운동 계획: [운동 이름 및 세트/횟수, 시간]
        3. 집에서 가능한 간단한 운동: 장비가 없을 경우 실내에서 할 수 있는 운동을 포함하세요.
        4. 추가 팁: 운동 수행 시 유의할 점(스트레칭, 호흡법 등)을 제공하세요.

        고객이 동기 부여를 받을 수 있도록 친절하고 응원하는 태도로 답변하세요."""
    
    # OpenAI API 호출
    response = client.chat.completions.create(
        model="gpt-3.5-turbo",
        messages=[
            {"role": "system", "content": system_message},
            {"role": "user", "content": user_data_Str},
        ]
    )
    
    # 응답 반환
    return response.choices[0].message.content

# 갱신이 필요할 때 사용할 API
def renewal_API(user_satisfaction, sol, user_data, direction):
    """
    OpenAI API를 호출하여 이전 추천 결과와 만족도를 기반으로 맞춤형 솔루션을 갱신.

    Parameters:
        user_satisfaction (int): 고객의 만족도 점수 (1~5).
        result (str): 이전 추천 결과.
        user_data (dict): 고객 정보(성별, 나이, 키, 몸무게, 직업 등).
        direction (str): "식단 관리" 또는 "운동" 등 AI 시스템 명령에 영향을 줄 방향.

    Returns:
        str: OpenAI API의 갱신된 응답 내용.
    """

    if user_satisfaction != 3 : 
        # 고객 데이터를 JSON 문자열로 변환
        user_data_Str = json.dumps(user_data, ensure_ascii=False)

        # 만족도에 따른 시스템 메시지 설정
        if direction == "식단 관리":
            system_message = """당신은 유능한 헬스트레이너 역할을 수행하는 AI입니다. 
            이전에 추천한 식단 솔루션이 고객의 피드백에 따라 난이도가 조정될 필요가 있습니다. 
            고객의 개인 정보를 기반으로 하루 총 칼로리 섭취량과 아침, 점심, 저녁에 먹어야 할 구체적인 식단 계획을 작성하세요. 
            고객의 만족도 점수를 참고하여 너무 힘들거나, 적당하거나, 너무 쉬운 경우에 맞게 식단의 난이도와 구성을 조정하세요. 
            친절하고 동기 부여적인 태도로 답변하세요. 솔루션에서 반드시 아래 형식을 유지하세요 : 
        
            - 아침: [추천 음식]
            - 점심: [추천 음식]
            - 저녁: [추천 음식]
            - 간식: [추천 음식]"""
            
        elif direction == "운동":
            system_message = """당신은 유능한 헬스트레이너 역할을 수행하는 AI입니다. 
            이전에 추천한 운동 계획이 고객의 피드백에 따라 난이도가 조정될 필요가 있습니다. 
            고객의 직업을 고려하여 회사나 학교에서도 실천할 수 있는 간단한 운동법과 시간을 포함한 맞춤형 운동 루틴을 추천하세요. 
            고객의 만족도 점수를 참고하여 너무 힘들거나, 적당하거나, 너무 쉬운 경우에 맞게 운동 난이도와 루틴을 조정하세요. 

            운동 계획은 반드시 다음 형식을 따라야 하며, 2. 추천 운동 계획과 3. 집에서 가능한 간단한 운동은 하나씩이면 충분합니다!:
            1. 운동 목표: 고객의 현재 상태와 피드백을 기반으로 한 구체적인 목표를 서술하세요.
            2. 추천 운동 계획: [운동 이름 및 세트/횟수, 시간]
            3. 집에서 가능한 간단한 운동: 장비가 없을 경우 실내에서 할 수 있는 운동을 포함하세요.
            4. 추가 팁: 운동 수행 시 유의할 점(스트레칭, 호흡법 등)을 제공하고, 피드백에 따라 적절한 조언을 추가하세요.

            고객이 동기 부여를 받을 수 있도록 친절하고 응원하는 태도로 답변하세요."""

        # OpenAI API 호출
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": system_message},
                {"role": "assistant", "content": sol},
                {"role": "user", "content": f"이전 추천 결과에 대한 만족도 점수는 {user_satisfaction}입니다. \n"
                                                f"1: 너무 힘듦, 2: 약간 힘듦, 3: 난이도 적당함, 4: 약간 쉬움, 5: 너무 쉬움\n"
                                                f"고객의 정보를 참고하여 새로운 솔루션을 제공해 주세요. \n"
                                                f"고객 정보: {user_data_Str}"},
            ]
        )

        # 새로운 결과 반환
        new_result = response.choices[0].message.content
        return new_result
    elif user_satisfaction == 3 : 
        print("만족도 점수가 3이므로 새로운 추천이 필요하지 않습니다.")

# 고객 만족도 입력 함수
def survey():
    while True:
        try:
            user_satisfaction = int(input("1 : 매우 힘듦, 2 : 약간 힘듦, 3 : 적당함, 4 : 약간 쉬움, 5 : 매우 쉬움\n고객 만족도 점수 (1~5): "))
            if 1 <= user_satisfaction <= 5:
                if user_satisfaction == 3:
                    print("만족도 점수가 3이므로 새로운 추천이 필요하지 않습니다.")
                break
            else:
                print("1에서 5 사이의 숫자를 입력해주세요.")
        except ValueError:
            print("유효한 숫자를 입력해주세요.")

    return user_satisfaction

# sol_core 추출
def extract_core(text, direction):
    if direction == "식단 관리":
        """
        주어진 텍스트에서 '아침', '점심', '저녁', '간식' 항목을 추출하여 특정 포맷의 문자열로 반환합니다.

        Parameters:
            text (str): 추천 결과 텍스트

        Returns:
            str: 아침, 점심, 저녁, 간식 정보를 특정 문자열 형식으로 반환
        """
        # 정규식 패턴 정의
        pattern = r"(아침|점심|저녁|간식):\s*(.+?)(?=\n|$)"
        # 정규식으로 항목 추출
        matches = re.findall(pattern, text)
        # 포맷에 맞는 문자열 생성
        sol_core_diet = "\n".join([f"{key} : {value.strip()}" for key, value in matches])
        return sol_core_diet

    elif direction == "운동":
        """
        주어진 텍스트에서 '추천 운동 계획'만 추출하여 반환합니다.

        Parameters:
            text (str): 운동 계획이 포함된 텍스트

        Returns:
            str: 추천 운동 계획 정보
        """
        # 정규식으로 "추천 운동 계획"만 추출
        pattern = r"추천 운동 계획:\s*((?:.|\n)+?)(?=\n(?:\w|$)|$)"
        # 정규식으로 매칭
        match = re.search(pattern, text)
        if match:
            # "추천 운동 계획" 텍스트 추출
            sol_core_exercise = match.group(1).strip()
            return sol_core_exercise
        else:
            return "추천 운동 계획이 없습니다."