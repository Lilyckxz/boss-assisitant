
# 环境
## 后端
- 激活虚拟环境
``` bash
cd .\backend\
.venv\Scripts\Activate.ps1
```

- 运行后端
``` bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

## 前端

``` bash
cd .\frontend\app3
```

- 添加包
```bash
flutter pub add <package>
```

- 运行前端

``` bash
flutter clean
flutter pub get
flutter run 
# 或
flutter build apk
```


``` bash
flutter devices
flutter run -d <device-id>
# 比如：flutter run -d PFJM10
```

或
```
flutter run
```


---
# 依赖
- 安装依赖包

```powershell
pip install -r requirements.txt
```
- 更新依赖包

```powershell
pip freeze > requirements.txt
```

