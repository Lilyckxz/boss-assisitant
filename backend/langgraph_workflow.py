
from langgraph.graph import StateGraph, END
from langchain_core.runnables import RunnableLambda
import httpx
import requests
from bs4 import BeautifulSoup
from ChineseTimeNLP import TimeNormalizer
import re
from fastapi import Depends
from sqlalchemy.orm import Session
import database
import models
import json

def call_llm(prompt):
    # 智谱清言
    print("传给LLM的prompt：", prompt)  # 调试用
    api_key = "e06e2eaeb3a7420a8d291bd2cd1b47b7.Ve93kXwlLuaILHt4"
    url = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": "glm-4-plus",  # 或 "glm-3-turbo"，可根据需要更换
        "messages": [
            {"role": "user", "content": prompt}
        ],
        "stream": False
    }
    resp = httpx.post(url, json=payload, headers=headers, timeout=30)
    resp.raise_for_status()
    ai_data = resp.json()
    # 智谱清言返回格式：{"choices": [{"message": {"content": ...}}]}
    return ai_data.get("choices", [{}])[0].get("message", {}).get("content", "") or "AI无回复"

def get_text(state):
    if isinstance(state, dict):
        return state.get("input", "")
    else:
        return state

def llm_judge_todo(text):
    prompt = f"""请判断以下文本是否属于需要加入待办事项的提醒（包括但不限于以下表达）：
    - 直接指令型："记得明天交报告"、"周五前完成PPT"
    - 时间限定型："下周开会讨论"、"月底前提交申请"
    - 任务描述型："买菜清单：鸡蛋、牛奶"、"需要维修空调"
    - 自我提醒型："别忘了预约医生"、"提醒自己打电话给客户"
    - 工具关联型："设置一个9点的闹钟"、"添加到购物车"
    - 隐含需求型："冰箱快空了"、"打印机没墨了"
    - 常见句式："要..."/"得..."/"记得..."/"别忘了..."/"提醒..."/"需要处理..."
    - 其他变体："待办：整理文档"、"TODO：调试代码"、"跟进：客户反馈"

    注意：仅当文本明确或隐含需要未来执行的动作时回答yes，日常闲聊或描述性内容回答no。
    只需回答 yes 或 no：
    {text}"""
    reply = call_llm(prompt)
    print("LLM 判断是否待办事项：", reply)
    return reply.strip().lower().startswith("yes")

def is_profile_statement(text):
    # 扩展表达，宽松匹配
    like_words = "喜欢|热爱|爱好|偏爱|钟爱|崇尚|欣赏|向往|爱|情有独钟|热衷于|痴迷于"
    dislike_words = "讨厌|不喜欢|痛恨|反感|不爱|不习惯|厌恶|排斥|抵触|害怕|恐惧|怕|烦|腻|不擅长|不善于|不会|不习惯于|深恶痛绝|强烈不满"
    # 匹配句中任意人物+喜欢/讨厌/爱+内容
    pattern = rf".*?([\u4e00-\u9fa5A-Za-z0-9]+)(?:[，, ]+)?({like_words}|{dislike_words})(.+)"
    m = re.match(pattern, text)
    if m:
        name = m.group(1).strip()
        verb = m.group(2).strip()
        obj = m.group(3).strip()
        # trait 不能是问句
        if not obj.endswith("？") and not obj.endswith("?"):
            # 归一化
            if verb in like_words.split("|"):
                trait = "喜欢" + obj
            elif verb in dislike_words.split("|"):
                trait = "讨厌" + obj
            return name, trait
    return None, None

def is_profile_query(text):
    # 增加“这人怎么样”等
    m = re.match(r"(.+?)(喜欢干什么|怎么样|如何|有什么特点|喜欢什么|这人怎么样|这人如何)", text)
    if m:
        name = m.group(1).strip()
        return name
    return None

def ai_extract_profile(text):
    prompt = (
        "你是信息抽取助手。请从下面这句话中抽取‘人物’和‘喜欢/讨厌’关系，返回JSON格式。\n"
        "规则：\n"
        "- name 字段只能是真实人名或称呼，不能带‘说他’‘透露他’‘表示自己’等修饰语。\n"
        "- 如果表达了某人喜欢某事，返回 {\"name\": \"...\", \"like\": \"...\"}。\n"
        "- 如果表达了某人讨厌/不喜欢/害怕某事，返回 {\"name\": \"...\", \"dislike\": \"...\"}。\n"
        "- 如果是查询某人画像，返回 {\"query\": \"...\"}。\n"
        "- 如果不是画像相关内容，返回 null。\n"
        "- 如果表达了某人喜欢、热衷、情有独钟、痴迷于某事，返回 {\"name\": \"...\", \"like\": \"...\"}。\n"
        "- 如果表达了某人讨厌、痛恨、强烈不满、深恶痛绝某事，也算讨厌，返回 {\"name\": \"...\", \"dislike\": \"...\"}。\n"
        "示例：\n"
        "输入：陈总喜欢喝酒 → {\"name\": \"陈总\", \"like\": \"喝酒\"}\n"
        "输入：陈总讨厌跑步 → {\"name\": \"陈总\", \"dislike\": \"跑步\"}\n"
        "输入：今天应酬的时候，程总透露他不喜欢喝酒 → {\"name\": \"程总\", \"dislike\": \"喝酒\"}\n"
        "输入：张三透露他爱好游泳 → {\"name\": \"张三\", \"like\": \"游泳\"}\n"
        "输入：小王表示自己不喜欢加班 → {\"name\": \"小王\", \"dislike\": \"加班\"}\n"
        "输入：李四不喜欢吵闹 → {\"name\": \"李四\", \"dislike\": \"吵闹\"}\n"
        "输入：你是谁 → null\n"
        "输入：明天开会 → null\n"
        "输入：程总喜欢干什么 → {\"query\": \"程总\"}\n"
        "输入：程总怎么样 → {\"query\": \"程总\"}\n"
        "输入：程总透露他这人怎么样 → {\"query\": \"程总\"}\n"
        "输入：张三表示自己这人怎么样 → {\"query\": \"张三\"}\n"
        "错误示例：name字段不能是‘程总透露他’‘张三表示自己’等，必须是‘程总’‘张三’。\n"
        "输入：里斯对加班深恶痛绝 → {\"name\": \"里斯\", \"dislike\": \"加班\"}\n"
        "输入：王五对迟到强烈不满 → {\"name\": \"王五\", \"dislike\": \"迟到\"}\n"
        "输入：小李对编程情有独钟 → {\"name\": \"小李\", \"like\": \"编程\"}\n"
        "输入：小王痴迷于下棋 → {\"name\": \"小王\", \"like\": \"下棋\"}\n"
        f"输入：{text} →"
    )
    result = call_llm(prompt)
    try:
        data = json.loads(result)
        if isinstance(data, dict):
            name = data.get("name")
            if name and any(x in name for x in ["说他", "表示自己", "透露他"]):
                return None, None
            if name:
                import re
                m = re.search(r"([\u4e00-\u9fa5]{2,4})", name)
                if m:
                    candidate = m.group(1)
                    if candidate in text:
                        name = candidate
                    else:
                        return None, None
                else:
                    return None, None
                if data.get("like"):
                    return name.strip(), "喜欢" + data["like"].strip()
                if data.get("dislike"):
                    return name.strip(), "讨厌" + data["dislike"].strip()
            if data.get("query"):
                return None, None
    except Exception:
        pass
    return None, None

# 修改 user_profile_node，优先用AI抽取

def user_profile_node(state):
    text = state["input"]
    print(f"[DEBUG] 完整state内容: {state}")  # 新增：显示完整state
    user_id = state.get("user_id")
    print(f"[DEBUG] 原始user_id值: {user_id}, 类型: {type(user_id)}")  # 新增：显示原始值和类型
    
    # 确保user_id是整数
    if user_id is None:
        print("[ERROR] user_id为None，使用默认值1")
        user_id = 1
    else:
        try:
            user_id = int(user_id)
            print(f"[DEBUG] 转换后的user_id: {user_id}")
        except (ValueError, TypeError):
            print(f"[ERROR] user_id转换失败: {user_id}，使用默认值1")
            user_id = 1
    
    print(f"[DEBUG] user_profile_node - 输入文本: {text}, 最终用户ID: {user_id}")  # 新增调试信息
    
    # 先用AI抽取
    name, trait = ai_extract_profile(text)
    # 若AI未能抽取，再用正则兜底
    if not (name and trait):
        name, trait = is_profile_statement(text)
    if name and trait:
        print(f"[DEBUG] 提取到人脉信息 - 姓名: {name}, 特点: {trait}, 用户ID: {user_id}")  # 新增调试信息
        db = database.SessionLocal()
        try:
            # 只在该用户的人脉中查找
            obj = db.query(models.UserProfile).filter_by(name=name, user_id=user_id).first()
            if obj:
                print(f"[DEBUG] 找到现有记录: {obj.name}, 特点: {obj.traits}")  # 新增调试信息
                # 解析现有的traits
                existing_traits = []
                if obj.traits:
                    # 支持多种分隔符：分号、逗号、换行符
                    for t in obj.traits.replace(';', ',').replace('\n', ',').split(','):
                        t = t.strip()
                        if t:
                            existing_traits.append(t)
                
                # 检查新trait是否已存在
                new_trait = trait.strip()
                if new_trait not in existing_traits:
                    # 如果不存在，则添加
                    existing_traits.append(new_trait)
                    obj.traits = ", ".join(existing_traits)
                    db.commit()
                    print(f"[DEBUG] 添加新特点成功: {new_trait}")  # 新增调试信息
                    return {"result": f"已记录：{name}{trait}"}
                else:
                    # 如果已存在，直接返回
                    print(f"[DEBUG] 特点已存在: {new_trait}")  # 新增调试信息
                    return {"result": f"{name}的{trait}信息已存在"}
            else:
                print(f"[DEBUG] 创建新记录: {name}, 特点: {trait}, 用户ID: {user_id}")  # 新增调试信息
                obj = models.UserProfile(name=name, traits=trait, user_id=user_id)
                db.add(obj)
                db.commit()
                return {"result": f"已记录：{name}{trait}"}
        finally:
            db.close()
    
    # 查询画像
    query_name = is_profile_query(text)
    if query_name:
        print(f"[DEBUG] 查询人脉信息: {query_name}, 用户ID: {user_id}")  # 新增调试信息
        db = database.SessionLocal()
        try:
            # 只在该用户的人脉中查找
            obj = db.query(models.UserProfile).filter_by(name=query_name, user_id=user_id).first()
            if obj:
                return {"result": f"{obj.name}：{obj.traits}"}
            else:
                return {"result": f"未找到{query_name}的信息。"}
        finally:
            db.close()
    return None

def classify_intent(state):
    text = get_text(state)
    # 新增：优先判断是否为用户画像
    name, trait = is_profile_statement(text)
    if name and trait:
        intent = "users"
    elif is_profile_query(text):
        intent = "users"
    elif any(site in text for site in ["新闻", "news", "头条", "BBC", "网易"]):
        intent = "news"
    elif llm_judge_todo(text):
        intent = "todo"
    else:
        intent = "chat"
    
    # 保留原始state中的所有字段，只更新input和intent
    result = state.copy()
    result.update({"input": text, "intent": intent})
    return result

def extract_time_from_text(text):
    tn = TimeNormalizer()
    res = tn.parse(target=text)
    # 只取第一个时间点
    if isinstance(res, dict):
        if res.get('type') == 'timestamp' and res.get('timestamp'):
            return res['timestamp']
        elif res.get('type') == 'timespan' and res.get('timespan'):
            # 取区间的第一个时间
            return res['timespan'][0]
    return None

# 后续节点都用 state['input']
def extract_todo(state):
    text = state["input"]
    remind_at = extract_time_from_text(text)
    if remind_at:
        return {"result": f"建议添加到待办：{text}", "remind_at": remind_at}
    else:
        return {"result": f"建议添加到待办：{text}"}

def chat_ai(state):
    text = state["input"]
    system_prompt = (
        "你是别人的贴心助手，可以帮别人解决问题。\n"
        "你的功能包括：ai对话、手动/语音添加代办事项、通知推送、存储他人喜好与厌恶、新闻搜索、查看优质文章等。"
    )
    prompt = f"{system_prompt}\n用户: {text}"
    return {"result": call_llm(prompt)}

def news_scraper(state):
    text = state["input"]
    results = []
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    news_keywords = ["news", "article", "content", "/c/", "/a/", "/n1/", "/politics/"]
    exclude_keywords = ["邮箱", "注册", "download", "专题", "index.html", "平台", "报告", "发布", "体验中心"]
    # 新华网额外排除外文频道
    xinhuanet_exclude_titles = ["Русский язык", "Português"]

    # 人民网
    try:
        people_url = "http://www.people.com.cn/"
        people_resp = requests.get(people_url, timeout=10, headers=headers)
        people_resp.encoding = 'utf-8'
        soup = BeautifulSoup(people_resp.text, "html.parser")
        people_news = []
        for a in soup.find_all("a", href=True):
            href = a["href"]
            title = a.get_text(strip=True)
            if (
                any(kw in href for kw in news_keywords)
                and not any(ek in href for ek in exclude_keywords)
                and not any(ek in title for ek in exclude_keywords)
                and 8 < len(title) < 40
            ):
                if not href.startswith("http"):
                    href = people_url.rstrip('/') + '/' + href.lstrip('/')
                people_news.append(f"[{title}]({href})")
            if len(people_news) >= 3:
                break
        if people_news:
            results.append("【人民网】\n\n" + "\n\n".join(people_news))
    except Exception as e:
        results.append(f"【人民网爬取失败: {str(e)}]")

    # 凤凰网
    try:
        ifeng_url = "https://www.ifeng.com/"
        ifeng_resp = requests.get(ifeng_url, timeout=10, headers=headers)
        ifeng_resp.encoding = 'utf-8'
        soup = BeautifulSoup(ifeng_resp.text, "html.parser")
        ifeng_news = []
        for a in soup.find_all("a", href=True):
            href = a["href"]
            title = a.get_text(strip=True)
            if (
                any(kw in href for kw in news_keywords)
                and not any(ek in href for ek in exclude_keywords)
                and not any(ek in title for ek in exclude_keywords)
                and 8 < len(title) < 40
            ):
                if not href.startswith("http"):
                    href = ifeng_url.rstrip('/') + '/' + href.lstrip('/')
                ifeng_news.append(f"[{title}]({href})")
            if len(ifeng_news) >= 3:
                break
        if ifeng_news:
            results.append("【凤凰网】\n\n" + "\n\n".join(ifeng_news))
    except Exception as e:
        results.append(f"【凤凰网爬取失败: {str(e)}]")

    # 新华网
    try:
        xinhuanet_url = "https://www.news.cn/?lan=zh"
        xinhuanet_resp = requests.get(xinhuanet_url, timeout=10, headers=headers)
        xinhuanet_resp.encoding = 'utf-8'
        soup = BeautifulSoup(xinhuanet_resp.text, "html.parser")
        xinhuanet_news = []
        for a in soup.find_all("a", href=True):
            href = a["href"]
            title = a.get_text(strip=True)
            if (
                any(kw in href for kw in news_keywords)
                and not any(ek in href for ek in exclude_keywords)
                and not any(ek in title for ek in exclude_keywords)
                and not any(ek in title for ek in xinhuanet_exclude_titles)
                and not any(ek in href for ek in xinhuanet_exclude_titles)
                and 8 < len(title) < 40
                and all(ord(c) < 128 or '\u4e00' <= c <= '\u9fff' for c in title)  # 只保留中英文混合
            ):
                if not href.startswith("http"):
                    href = "https://www.news.cn/" + href.lstrip('/')
                xinhuanet_news.append(f"[{title}]({href})")
            if len(xinhuanet_news) >= 3:
                break
        if xinhuanet_news:
            results.append("【新华网】\n\n" + "\n\n".join(xinhuanet_news))
    except Exception as e:
        results.append(f"【新华网爬取失败: {str(e)}]")

    # 网易新闻
    # try:
    #     netease_url = "https://news.163.com/"
    #     netease_resp = requests.get(netease_url, timeout=10, headers=headers)
    #     netease_resp.encoding = 'utf-8'
    #     soup = BeautifulSoup(netease_resp.text, "html.parser")
    #     netease_news = []
    #     for a in soup.find_all("a", href=True):
    #         href = a["href"]
    #         title = a.get_text(strip=True)
    #         if (
    #             any(kw in href for kw in news_keywords)
    #             and not any(ek in href for ek in exclude_keywords)
    #             and not any(ek in title for ek in exclude_keywords)
    #             and 8 < len(title) < 40
    #             and href.startswith("http")
    #         ):
    #             netease_news.append(f"[{title}]({href})")
    #         if len(netease_news) >= 3:
    #             break
    #     if netease_news:
    #         results.append("【网易新闻】\n\n" + "\n\n".join(netease_news))
    # except Exception as e:
    #     results.append(f"【网易新闻爬取失败: {str(e)}]")

    return {"result": "\n\n".join(results) or "未找到相关新闻"}

# workflow conditional_edges 用 state['intent']
def build_workflow():
    workflow = StateGraph(dict)
    workflow.add_node("classify", RunnableLambda(classify_intent))
    workflow.add_node("todo", RunnableLambda(extract_todo))
    workflow.add_node("chat", RunnableLambda(chat_ai))
    workflow.add_node("news", RunnableLambda(news_scraper))
    workflow.add_node("users", RunnableLambda(user_profile_node))
    workflow.add_conditional_edges(
        "classify",
        lambda state: state["intent"],
        {
            "news": "news",
            "todo": "todo",
            "chat": "chat",
            "users": "users"
        }
    )
    workflow.add_edge("news", END)
    workflow.add_edge("todo", END)
    workflow.add_edge("chat", END)
    workflow.add_edge("users", END)
    workflow.set_entry_point("classify")
    return workflow.compile()

