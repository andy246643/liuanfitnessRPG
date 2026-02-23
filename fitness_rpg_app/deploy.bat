@echo off
chcp 65001

setlocal EnableDelayedExpansion

:: 1. 設定
set "CONFIG_FILE=.deploy_config"

:: 2. 檢查是否有儲存的 Repo URL
if exist "%CONFIG_FILE%" (
    set /p REPO_URL=<"%CONFIG_FILE%"
) else (
    echo ⚠️ 未檢測到 GitHub Repository URL 設定。
    echo.
    set /p REPO_URL="👉 請輸入您的 GitHub Repository URL (例如 https://github.com/User/Repo.git): "
    echo !REPO_URL!>"%CONFIG_FILE%"
    echo ✅ 設定已儲存！下次將自動讀取。
)

echo.
echo 🚀 開始編譯 Flutter Web (RPG 進化中...)...
call flutter build web --release --base-href "/liuanfitnessRPG/"

if %errorlevel% neq 0 (
    echo ❌ 編譯失敗，請檢查程式碼後再試一次。
    pause
    exit /b %errorlevel%
)

echo.
echo 📂 進入部署資料夾 build\web...
cd build\web

:: 3. 初始化部署用的 Git Repo (每次都重新初始化以確保乾淨)
if exist ".git" (
    rmdir /s /q .git
)
git init
git branch -M main

:: 4. 關聯遠端倉庫 (使用剛剛讀取的 URL)
git remote add origin "%REPO_URL%"

echo.
echo 📝 正在將變更打包...
git add .
git commit -m "Auto-deploy: %date% %time%"

echo.
echo 📤 正在強力推送到 GitHub Pages (gh-pages 分支)...
:: 5. 強制推送到 gh-pages 分支
git push -f origin main:gh-pages

if %errorlevel% neq 0 (
    echo ❌ 部署失敗！請檢查您的網路或 Repo URL 是否正確。
    echo 目前設定的 URL: %REPO_URL%
    echo 如果 URL 錯誤，請刪除 %CONFIG_FILE% 檔案後重試。
    pause
    exit /b %errorlevel%
)

echo.
echo ✅ 任務達成！您的網頁將在幾分鐘後更新。
echo 🌍 您的網址應該是: https://[Username].github.io/[RepoName]/
cd ..\..
pause