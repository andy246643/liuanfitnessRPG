@echo off
echo Check & Kill process on port 5000...
powershell -Command "Get-NetTCPConnection -LocalPort 5000 -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }"
C:\fitnessrpg\flutter\bin\flutter.bat run -d chrome --web-port 5000 --dart-define=SUPABASE_URL=https://zvzkqyadsaoplswtqxdq.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_ZAFoCnC-aGv3qASHP6nYCg_t_V1lv_v
pause
