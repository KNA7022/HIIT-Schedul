import urllib3
import json
from jingtang_client import JingtangClient

# 禁用 SSL 警告
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def print_week_schedule(client, week_number):
    """打印指定周的所有课程详细信息"""
    week_schedule = client.get_week_schedule(week_number)
    if week_schedule["code"] == 200 and week_schedule["data"]:
        print(f"\n第{week_number}周课表详细信息：")
        for index, course in enumerate(week_schedule["data"], 1):
            time_add = course["timeAdd"]
            class_info = client.get_class_info(time_add)
            formatted_info = client.format_class_info(class_info)
            if formatted_info:
                print(f"\n[第{index}门课程]")
                print(json.dumps(formatted_info, ensure_ascii=False, indent=2))

def main():
    client = JingtangClient()
    
    # 登录参数
    username = "2023010920"
    password = "164014"
    code = client.generate_code()  # 使用随机生成的code
    print(f"使用的code: {code}")

    # 登录
    if client.login(username, password, code):
        print("登录成功！")
        
        # 获取学期信息
        semester_info = client.get_semester_info()
        print("\n学期信息：")
        print(json.dumps(semester_info, ensure_ascii=False, indent=2))
        
        # 获取并打印指定周次的所有课程详细信息
        week_number = 15  # 可以修改为其他周次
        print_week_schedule(client, week_number)
    else:
        print("登录失败！")

if __name__ == "__main__":
    main()
