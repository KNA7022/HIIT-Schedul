import requests
import json
from datetime import datetime
import random
import string

class JingtangClient:
    def __init__(self):
        self.base_url = "https://api.greathiit.com/api"
        self.headers = {
            "Host": "api.greathiit.com",
            "Connection": "keep-alive",
            "xweb_xhr": "1",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 MicroMessenger/7.0.20.1781(0x6700143B) NetType/WIFI MiniProgramEnv/Windows WindowsWechat/WMPF WindowsWechat(0x63090c25)XWEB/11581",
            "Accept": "*/*",
            "Sec-Fetch-Site": "cross-site",
            "Sec-Fetch-Mode": "cors",
            "Sec-Fetch-Dest": "empty",
            "Referer": "https://servicewechat.com/wx3db178bd95510b66/86/page-frame.html",
            "Accept-Encoding": "gzip, deflate, br",
            "Accept-Language": "zh-CN,zh;q=0.9"
        }
        self.session_id = ""
        self.token = ""

    @staticmethod
    def generate_code():
        """生成随机的32位code"""
        # 定义可能的字符集
        chars = string.ascii_letters + string.digits
        # 生成随机字符串
        code = ''.join(random.choice(chars) for _ in range(32))
        return code

    def login(self, username, password, code):
        login_url = f"{self.base_url}/user/loginUsername"
        params = {
            "username": username,
            "password": password,
            "code": code
        }
        
        response = requests.get(login_url, params=params, headers=self.headers, verify=False)
        if response.status_code == 200:
            data = response.json()
            if data["code"] == 200:
                self.session_id = data["data"]["sessionId"]
                self.token = data["data"]["token"]
                self.headers["Cookie"] = f"JSESSIONID={self.session_id}"
                self.headers["Authorization"] = self.token
                return True
        return False

    def get_semester_info(self):
        url = f"{self.base_url}/pub/getCourseCalendar"
        response = requests.get(url, headers=self.headers, verify=False)
        return response.json()

    def get_week_schedule(self, week):
        url = f"{self.base_url}/timetable/getDataWeek"
        params = {"week": week}
        response = requests.get(url, params=params, headers=self.headers, verify=False)
        return response.json()

    def get_class_info(self, time_add):
        url = f"{self.base_url}/sign/getCurrentClass"
        params = {"timeAdd": time_add}
        response = requests.get(url, params=params, headers=self.headers, verify=False)
        return response.json()

    def format_class_info(self, class_info):
        """格式化课程信息，只返回需要的字段"""
        if class_info["code"] == 200 and "ClassInfo" in class_info["data"]:
            info = class_info["data"]["ClassInfo"]
            return {
                "课程名称": info["courseName"],
                "教师": info["teacherName"],
                "教学楼": info["school"],
                "教室": info["room"],
                "周次": info["week"],
                "日期": info["time"],
                "节次": info["jie"],
                "星期": info["xq"],
                "学分": info["credit"],
                "班级": info["className"],
                "考核方式": info["cursProperty"],
                "考试形式": info["cursForm"],
                "课程状态": info["courseStatus"]
            }
        return None
