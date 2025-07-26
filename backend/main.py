# !/user/bin/env python3
# -*- coding: utf-8 -*- 

from fastapi import FastAPI, Depends, HTTPException, Body, Request, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from fastapi.middleware.cors import CORSMiddleware
import models
import database
import logging
from pydantic import BaseModel
from datetime import datetime
import httpx
from passlib.context import CryptContext
import re
from langgraph_workflow import build_workflow
from datetime import timezone, timedelta

# 配置日志
logging.basicConfig(level=logging.ERROR)
logger = logging.getLogger(__name__)

models.Base.metadata.create_all(bind=database.engine)

app = FastAPI()

# 添加 CORS 中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic schemas
class TodoCreate(BaseModel):
    content: str
    remind_at: str | None = None  # ISO格式字符串，可选
    user_id: int  # 新增：用户ID

class TodoRead(BaseModel):
    id: int
    content: str
    time: str
    remind_at: str | None = None
    user_id: int  # 新增：用户ID

    class Config:
        orm_mode = True

class TodoUpdate(BaseModel):
    completed: bool

class UserCreate(BaseModel):
    username: str
    password: str

class UserLogin(BaseModel):
    username: str
    password: str

class UserRead(BaseModel):
    id: int
    username: str

    class Config:
        orm_mode = True

class StashContentCreate(BaseModel):
    title: str
    url: Optional[str] = None
    type: str = "article"  # 支持: article, video
    summary: Optional[str] = None
    cover: Optional[str] = None
    content: Optional[str] = None  # 新增

class StashContentRead(BaseModel):
    id: int
    title: str
    url: Optional[str]
    type: str
    summary: Optional[str]
    cover: Optional[str]
    content: Optional[str]  # 新增
    created_at: datetime
    class Config:
        orm_mode = True

class UserProfileCreate(BaseModel):
    name: str
    traits: str
    user_id: int  # 新增：用户ID

class UserProfileRead(BaseModel):
    id: int
    name: str
    traits: str
    created_at: datetime
    class Config:
        orm_mode = True

class CategorySubscribeRequest(BaseModel):
    user_id: int
    category: str

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password):
    return pwd_context.hash(password)

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/users", response_model=List[UserRead])
def get_all_users(db: Session = Depends(get_db)):
    """获取所有用户的列表（ID和用户名）"""
    users = db.query(models.User).order_by(models.User.id).all()
    return users

@app.post("/todos", response_model=TodoRead, status_code=201)
def create_todo(todo: TodoCreate, db: Session = Depends(get_db)):
    remind_at_dt = None
    if todo.remind_at:
        try:
            remind_at_dt = datetime.fromisoformat(todo.remind_at)
            # 新增：后端校验提醒时间是否已过
            if remind_at_dt < datetime.now(remind_at_dt.tzinfo):
                raise HTTPException(status_code=400, detail="提醒时间已经过去了")
        except Exception:
            remind_at_dt = None
    db_todo = models.Todo(title=todo.content, remind_at=remind_at_dt, user_id=todo.user_id)
    db.add(db_todo)
    db.commit()
    db.refresh(db_todo)
    # 转为东八区
    created_at = db_todo.created_at
    if created_at.tzinfo is None:
        created_at = created_at.replace(tzinfo=timezone.utc)
    created_at = created_at.astimezone(timezone(timedelta(hours=8)))
    return TodoRead(id=db_todo.id, content=db_todo.title, time=created_at.strftime('%Y-%m-%d %H:%M:%S'), remind_at=db_todo.remind_at.isoformat() if db_todo.remind_at else None, user_id=db_todo.user_id)

@app.get("/todos", response_model=List[TodoRead])
def read_todos(user_id: int = Query(...), db: Session = Depends(get_db)):
    try:
        todos = db.query(models.Todo).filter(models.Todo.user_id == user_id).all()
        result = []
        for t in todos:
            created_at = t.created_at
            if created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=timezone.utc)
            created_at = created_at.astimezone(timezone(timedelta(hours=8)))
            result.append(TodoRead(
                id=t.id,
                content=t.title,
                time=created_at.strftime('%Y-%m-%d %H:%M:%S'),
                remind_at=t.remind_at.isoformat() if t.remind_at else None,
                user_id=t.user_id
            ))
        return result
    except Exception as e:
        logger.error(f"Error reading todos: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.delete("/todos/{todo_id}")
def delete_todo(todo_id: int, user_id: int = Query(...), db: Session = Depends(get_db)):
    todo = db.query(models.Todo).filter(models.Todo.id == todo_id, models.Todo.user_id == user_id).first()
    if not todo:
        raise HTTPException(status_code=404, detail="Todo not found or no permission")
    db.delete(todo)
    db.commit()
    return {"ok": True}

# 新增：切换 To-Do 完成状态
@app.patch("/todos/{todo_id}", response_model=TodoRead)
def update_todo_completed(todo_id: int, update: TodoUpdate, db: Session = Depends(get_db)):
    todo = db.query(models.Todo).filter(models.Todo.id == todo_id).first()
    if not todo:
        raise HTTPException(status_code=404, detail="Todo not found")
    todo.completed = update.completed
    db.commit()
    db.refresh(todo)
    return todo

@app.post("/register")
def register(user: UserCreate, db: Session = Depends(get_db)):
    if db.query(models.User).filter(models.User.username == user.username).first():
        raise HTTPException(status_code=400, detail="用户名已存在")
    user_obj = models.User(
        username=user.username,
        password_hash=get_password_hash(user.password)
    )
    db.add(user_obj)
    db.commit()
    db.refresh(user_obj)
    return {"id": user_obj.id, "username": user_obj.username}

@app.post("/login")
def login(user: UserLogin, db: Session = Depends(get_db)):
    user_obj = db.query(models.User).filter(models.User.username == user.username).first()
    if not user_obj or not verify_password(user.password, user_obj.password_hash):
        raise HTTPException(status_code=401, detail="用户名或密码错误")
    return {"id": user_obj.id, "username": user_obj.username}

@app.post("/stash", response_model=StashContentRead)
def add_stash(content: StashContentCreate, db: Session = Depends(get_db)):
    obj = models.StashContent(**content.dict())
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj

@app.get("/stash", response_model=List[StashContentRead])
def get_stash_list(type: Optional[str] = Query(None), db: Session = Depends(get_db)):
    query = db.query(models.StashContent)
    if type:
        query = query.filter(models.StashContent.type == type)
    return query.order_by(models.StashContent.created_at.desc()).all()

@app.delete("/stash/{stash_id}")
def delete_stash(stash_id: int, db: Session = Depends(get_db)):
    obj = db.query(models.StashContent).filter(models.StashContent.id == stash_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="内容未找到")
    db.delete(obj)
    db.commit()
    return {"ok": True}

@app.post("/user_profile", response_model=UserProfileRead)
def create_user_profile(profile: UserProfileCreate, db: Session = Depends(get_db)):
    # 查重，若已存在则合并traits（只在该用户的人脉中查重）
    obj = db.query(models.UserProfile).filter_by(name=profile.name, user_id=profile.user_id).first()
    if obj:
        # 解析现有的traits
        existing_traits = []
        if obj.traits:
            # 支持多种分隔符：分号、逗号、换行符
            for t in obj.traits.replace(';', ',').replace('\n', ',').split(','):
                t = t.strip()
                if t:
                    existing_traits.append(t)
        
        # 检查新trait是否已存在
        new_trait = profile.traits.strip()
        if new_trait not in existing_traits:
            # 如果不存在，则添加
            existing_traits.append(new_trait)
            obj.traits = ", ".join(existing_traits)
            db.commit()
        # 如果已存在，不做任何操作
        return obj
    new_obj = models.UserProfile(name=profile.name, traits=profile.traits, user_id=profile.user_id)
    db.add(new_obj)
    db.commit()
    db.refresh(new_obj)
    return new_obj

@app.get("/user_profile")
def get_user_profile(name: str, user_id: int = Query(...), db: Session = Depends(get_db)):
    obj = db.query(models.UserProfile).filter_by(name=name, user_id=user_id).first()
    if not obj:
        return {"result": f"未找到{name}的画像信息。"}
    return {"result": f"{obj.name}：{obj.traits}"}

@app.get("/user_profiles")
def get_all_user_profiles(user_id: int = Query(...), db: Session = Depends(get_db)):
    profiles = db.query(models.UserProfile).filter_by(user_id=user_id).all()
    return [
        {
            "id": profile.id,
            "name": profile.name,
            "traits": profile.traits,
            "created_at": profile.created_at.isoformat() if profile.created_at else None
        }
        for profile in profiles
    ]

@app.delete("/user_profile/{profile_id}")
def delete_user_profile(profile_id: int, user_id: int = Query(...), db: Session = Depends(get_db)):
    profile = db.query(models.UserProfile).filter(models.UserProfile.id == profile_id, models.UserProfile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="用户画像未找到或无权限")
    db.delete(profile)
    db.commit()
    return {"ok": True}

@app.put("/user_profile/{profile_id}")
def update_user_profile(profile_id: int, profile: UserProfileCreate, db: Session = Depends(get_db)):
    db_profile = db.query(models.UserProfile).filter(models.UserProfile.id == profile_id, models.UserProfile.user_id == profile.user_id).first()
    if not db_profile:
        raise HTTPException(status_code=404, detail="用户画像未找到或无权限")
    db_profile.name = profile.name
    db_profile.traits = profile.traits
    db.commit()
    db.refresh(db_profile)
    return db_profile

MIDDLE_SERVER_URL = "http://localhost:8001"  # 中转站地址

def check_user_category_permission(user_id: int, category: str) -> bool:
    try:
        resp = httpx.get(f"{MIDDLE_SERVER_URL}/api/enriched_permissions", timeout=3)
        if resp.status_code != 200:
            return False
        data = resp.json()
        for user in data.get("permissions", []):
            if str(user["id"]) == str(user_id) and category in user["categories"]:
                return True
        return False
    except Exception as e:
        print(f"[权限校验] 访问中转站失败: {e}")
        return False

@app.post("/subscribe_category")
def subscribe_category(req: CategorySubscribeRequest, db: Session = Depends(get_db)):
    # 直接允许订阅，无需权限校验
    exists = db.query(models.UserCategorySubscription).filter_by(user_id=req.user_id, category=req.category).first()
    if exists:
        return {"msg": "已订阅"}
    sub = models.UserCategorySubscription(user_id=req.user_id, category=req.category)
    db.add(sub)
    db.commit()
    return {"msg": "订阅成功"}

@app.post("/unsubscribe_category")
def unsubscribe_category(req: CategorySubscribeRequest, db: Session = Depends(get_db)):
    # 直接允许取消订阅，无需权限校验
    sub = db.query(models.UserCategorySubscription).filter_by(user_id=req.user_id, category=req.category).first()
    if not sub:
        return {"msg": "未订阅"}
    db.delete(sub)
    db.commit()
    return {"msg": "已取消订阅"}

@app.get("/my_categories")
def my_categories(user_id: int, db: Session = Depends(get_db)):
    subs = db.query(models.UserCategorySubscription).filter_by(user_id=user_id).all()
    return [s.category for s in subs]

workflow = build_workflow()

@app.post("/chat")
async def chat_endpoint(request: Request):
    data = await request.json()
    message = data.get("message", "")
    print("完整请求数据：", data)  # 新增：显示完整请求数据
    
    # 更严格的user_id处理
    raw_user_id = data.get("user_id")
    print(f"原始user_id值: {raw_user_id}, 类型: {type(raw_user_id)}")  # 新增调试信息
    
    if raw_user_id is None:
        print("[ERROR] 请求中没有user_id字段")
        user_id = 1
    else:
        try:
            user_id = int(raw_user_id)
            print(f"转换后的user_id: {user_id}")
        except (ValueError, TypeError):
            print(f"[ERROR] user_id转换失败: {raw_user_id}，使用默认值1")
            user_id = 1
    
    print("收到前端消息：", message, "最终用户ID：", user_id)  # 调试用
    print("传递给workflow的state：", {"input": message, "user_id": user_id})  # 新增调试信息
    result = workflow.invoke({"input": message, "user_id": user_id})
    print("workflow返回结果：", result)  # 新增调试信息
    # result 可能包含 result 和 remind_at
    if isinstance(result, dict) and "remind_at" in result:
        return {"answer": result["result"], "remind_at": result["remind_at"]}
    return {"answer": result["result"]}

