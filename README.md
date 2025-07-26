

# 📌 开发协作建议：依赖版本管理

如你在 **本地安装了新的依赖包（无论是 Python 或 Flutter）**，需要确保版本信息被同步：

---

## 🐍 后端（Python）

使用 `pip freeze` 将当前虚拟环境中的依赖版本写入 `requirements.txt`：

```powershell
pip freeze > requirements.txt
```

---

## 🐦 前端（Flutter）

推荐使用命令添加依赖，**自动写入 `pubspec.yaml` 并完成依赖同步**：

```bash
flutter pub add <package>
```

示例：

```bash
flutter pub add http
```

⚠️ **请勿手动编辑 `pubspec.yaml` 添加依赖**，避免格式错误或版本不一致问题。


## ⬆️ Git同步指南

```bash
git add .
git commit -m "此处添加提交说明"
git push
```


### 如果出现

```bash
master -> master (non-fast-forward)
error: failed to push some refs to 'https://gitee.com/lcxzainuli/boss-assisitant.git'
hint: Updates were rejected because the tip of your current branch is behind
hint: its remote counterpart. If you want to integrate the remote changes,
hint: use 'git pull' before pushing again.
```

说明本地 master 分支落后于远程 master 分支（远程有你本地没有的提交）

git 默认不允许你直接推送，会防止丢失远程的提交

### 解决方法：使用 merge(以master分支为例)

```bash
git pull origin master
```

如果有冲突，Git 会提示你哪些文件有冲突。
手动编辑这些文件，解决冲突后，执行：

```bash
  git add <冲突文件>
  git commit
```

合并完成后，推送到远程：

```bash
  git push origin master
```

### 冲突处理说明

Git 会在有冲突的文件中用  <<<<<<<, =======, >>>>>>> 

标记出冲突内容。

需要手动选择保留哪一部分内容，或合并两部分内容，然后删除这些标记。

解决所有冲突后，记得 git add <文件>，然后继续 commit。



---

# ▶️ 运行指南

## 前端

```bash
flutter run
```

## 后端

```bash
uvicorn main:app --port 8000 --reload
```

---

# 🚀 第一次——项目运行指南

本项目分为前端（Flutter）与后端（FastAPI）两个模块。以下为各模块的运行步骤说明。

---

## 📦 前端（frontend/app3）

### 1. 进入前端项目目录

```bash
cd frontend/app3
```

### 2. 安装依赖包

```bash
flutter pub get
```

### 3. 启动前端应用

```bash
flutter run
```

> 如需运行在模拟器或物理设备上，请提前完成 Flutter 环境配置。

> 检查环境配置状态：
>
> ```bash
> flutter doctor
> ```

---

## 🔧 后端（backend）

### 1. 进入后端项目目录

```bash
cd backend
```

### 2. 创建并激活虚拟环境（首次执行）

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
```

> 退出虚拟环境：
>
> ```powershell
> deactivate
> ```

### 3. 安装依赖包（根据 `requirements.txt`）

```powershell
pip install -r requirements.txt
```

### 4. 启动后端服务（FastAPI + Uvicorn）

```powershell
uvicorn main:app --port 8000 --reload
```

---
