from fastapi import FastAPI, HTTPException, Request, Depends, Form, File, UploadFile
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import httpx
import json
import os
import shutil
import time
import uuid
from pydantic import BaseModel
from typing import List, Dict, Optional
from sqlalchemy.orm import Session

# 导入数据库和模型
from . import models, database

# 创建数据库表
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI()

# --- 中间件和静态文件配置 ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

static_dir = "middle/static"
images_dir = os.path.join(static_dir, "images")
os.makedirs(images_dir, exist_ok=True)
app.mount("/static", StaticFiles(directory=static_dir), name="static")

templates = Jinja2Templates(directory="middle/templates")

# --- 依赖 ---
def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- 主后端和服务器配置 ---
MAIN_BACKEND_URL = "http://localhost:8000"
MIDDLE_SERVER_URL = "http://localhost:8001"
PERMISSIONS_FILE = "middle/permissions.json"
MIGRATION_FLAG_FILE = "middle/migration_done.flag"

# --- 数据迁移 ---
def migrate_from_json_to_db(db: Session):
    """如果需要，将旧的 permissions.json 数据迁移到数据库"""
    if os.path.exists(MIGRATION_FLAG_FILE) or not os.path.exists(PERMISSIONS_FILE):
        return

    print("正在从 permissions.json 迁移数据到数据库...")
    with open(PERMISSIONS_FILE, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # 迁移分类
    db_categories = {c.name for c in db.query(models.Category).all()}
    for category_name in data.get("categories", []):
        if category_name not in db_categories:
            db.add(models.Category(name=category_name))

    # 迁移用户权限
    user_perms = data.get("users", {})
    for user_id, perms in user_perms.items():
        for category_name in perms.get("categories", []):
            # 检查是否已存在
            exists = db.query(models.UserPermission).filter_by(user_id=user_id, category_name=category_name).first()
            if not exists:
                db.add(models.UserPermission(user_id=user_id, category_name=category_name))
    
    db.commit()

    # 创建迁移完成标志
    with open(MIGRATION_FLAG_FILE, 'w') as f:
        f.write('done')
    print("数据迁移完成。")
    # 可选：重命名旧的json文件，避免混淆
    os.rename(PERMISSIONS_FILE, PERMISSIONS_FILE + ".migrated")


@app.on_event("startup")
def on_startup():
    # 应用启动时执行一次性迁移
    db = database.SessionLocal()
    try:
        migrate_from_json_to_db(db)
    finally:
        db.close()


# --- Pydantic 模型 ---
class UserInfo(BaseModel):
    id: int
    username: str

class EnrichedUserPermission(BaseModel):
    id: str
    username: Optional[str] = None
    categories: List[str]

class EnrichedPermissionsResponse(BaseModel):
    permissions: List[EnrichedUserPermission]
    all_categories: List[str]
    all_users: List[UserInfo]

class PermissionsUpdateRequest(BaseModel):
    users: Dict[str, Dict[str, List[str]]]
    categories: List[str]

# --- 数据库操作 ---
async def fetch_all_users_from_main() -> List[UserInfo]:
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{MAIN_BACKEND_URL}/users")
            response.raise_for_status()
            users_data = response.json()
            return [UserInfo(**user) for user in users_data]
    except (httpx.RequestError, httpx.HTTPStatusError) as e:
        print(f"Error fetching users from main backend: {e}")
        return []

# --- API 端点 ---
@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/api/enriched_permissions", response_model=EnrichedPermissionsResponse)
async def get_enriched_permissions(db: Session = Depends(get_db)):
    all_categories_db = db.query(models.Category).order_by(models.Category.name).all()
    all_categories = [c.name for c in all_categories_db]

    all_permissions_db = db.query(models.UserPermission).all()
    user_perms_map = {}
    for perm in all_permissions_db:
        if perm.user_id not in user_perms_map:
            user_perms_map[perm.user_id] = []
        user_perms_map[perm.user_id].append(perm.category_name)

    all_users_main = await fetch_all_users_from_main()
    user_info_map = {str(u.id): u.username for u in all_users_main}

    enriched_permissions = []
    for user_id, categories in user_perms_map.items():
        enriched_permissions.append(
            EnrichedUserPermission(
                id=user_id,
                username=user_info_map.get(user_id, "未知用户"),
                categories=sorted(categories)
            )
        )
    
    # 按用户ID排序
    enriched_permissions.sort(key=lambda x: int(x.id) if x.id.isdigit() else 0)

    return EnrichedPermissionsResponse(
        permissions=enriched_permissions,
        all_categories=all_categories,
        all_users=all_users_main
    )

@app.post("/api/permissions")
async def update_permissions(request: PermissionsUpdateRequest, db: Session = Depends(get_db)):
    # 1. 更新分类
    db.query(models.Category).delete()
    for cat_name in request.categories:
        db.add(models.Category(name=cat_name))

    # 2. 更新用户权限 (先删后增)
    db.query(models.UserPermission).delete()
    for user_id, perms in request.users.items():
        for cat_name in perms.get("categories", []):
            db.add(models.UserPermission(user_id=user_id, category_name=cat_name))
    
    try:
        db.commit()
        return JSONResponse(content={"msg": "权限更新成功"}, status_code=200)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"保存失败: {str(e)}")


@app.post("/relay_push")
async def relay_push(
    db: Session = Depends(get_db),
    title: str = Form(...),
    content: str = Form(...),
    category: str = Form(...),
    summary: Optional[str] = Form(None),
    cover_file: Optional[UploadFile] = File(None),
    cover_url: Optional[str] = Form(None)
):
    # 从数据库获取有权限的用户
    permissions = db.query(models.UserPermission).filter_by(category_name=category).all()
    target_users = [p.user_id for p in permissions]

    if not target_users:
        raise HTTPException(status_code=404, detail=f"该分类'{category}'下无任何用户订阅")

    final_cover_url = cover_url
    if cover_file and cover_file.filename:
        ext = os.path.splitext(cover_file.filename)[1] if '.' in cover_file.filename else ''
        unique_name = f"{int(time.time())}_{uuid.uuid4().hex}{ext}"
        file_path = os.path.join(images_dir, unique_name)
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(cover_file.file, buffer)
        final_cover_url = f"{MIDDLE_SERVER_URL}/static/images/{unique_name}"

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{MAIN_BACKEND_URL}/stash",
            json={
                "title": title,
                "content": content,
                "type": category,
                "summary": summary,
                "cover": final_cover_url,
            }
        )
        if resp.status_code not in (200, 201):
            raise HTTPException(status_code=500, detail=f"推送到主后端失败: {resp.text}")
            
    return {"msg": f"推送成功，内容已推送到分类 '{category}'，影响用户: {target_users}"} 