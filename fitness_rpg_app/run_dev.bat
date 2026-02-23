@echo off
echo Check & Kill process on port 8082...
powershell -Command "Get-NetTCPConnection -LocalPort 8082 -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }"
flutter run -d chrome --web-port 8082 --dart-define=SUPABASE_URL=https://zvzkqyadsaoplswtqxdq.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_ZAFoCnC-aGv3qASHP6nYCg_t_V1lv_v
