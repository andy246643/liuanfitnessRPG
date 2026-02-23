@echo off
echo Check & Kill process on port 8081...
powershell -Command "Get-NetTCPConnection -LocalPort 5000 -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }"
flutter run -d web-server --web-port 5000 --dart-define=SUPABASE_URL=https://zvzkqyadsaoplswtqxdq.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_ZAFoCnC-aGv3qASHP6nYCg_t_V1lv_v
