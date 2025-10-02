@echo off
REM ============================================
REM PostgreSQL总系统 - 本地验证脚本 (Windows)
REM ============================================

echo.
echo ============================================
echo PostgreSQL总系统 - 本地验证测试
echo ============================================
echo.

set CONTAINER=postgres_local_test
set SUCCESS=0
set FAILED=0

REM ============================================
REM 1. 测试数据库连接
REM ============================================
echo 1️⃣  测试数据库连接...
docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT version();" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ 数据库连接成功
    set /a SUCCESS+=1
) else (
    echo    ❌ 数据库连接失败
    set /a FAILED+=1
)
echo.

REM ============================================
REM 2. 检查统一反馈表
REM ============================================
echo 2️⃣  检查统一反馈表...
docker exec %CONTAINER% psql -U admin -d postgres -t -c "SELECT COUNT(*) FROM unified_feedback;" 2>nul | findstr /r "[0-9]" >nul
if %errorlevel% equ 0 (
    for /f %%i in ('docker exec %CONTAINER% psql -U admin -d postgres -t -c "SELECT COUNT(*) FROM unified_feedback;"') do set COUNT=%%i
    echo    ✅ 统一反馈表: %COUNT%条记录
    set /a SUCCESS+=1
) else (
    echo    ❌ 统一反馈表检查失败
    set /a FAILED+=1
)
echo.

REM ============================================
REM 3. 检查ColorMagic表
REM ============================================
echo 3️⃣  检查ColorMagic表...
docker exec %CONTAINER% psql -U admin -d postgres -t -c "SELECT COUNT(*) FROM pg_tables WHERE tablename LIKE 'colormagic_%%';" 2>nul | findstr /r "[0-9]" >nul
if %errorlevel% equ 0 (
    for /f %%i in ('docker exec %CONTAINER% psql -U admin -d postgres -t -c "SELECT COUNT(*) FROM pg_tables WHERE tablename LIKE ''colormagic_%%'';"') do set COUNT=%%i
    echo    ✅ ColorMagic表: %COUNT%个表
    set /a SUCCESS+=1
) else (
    echo    ❌ ColorMagic表检查失败
    set /a FAILED+=1
)
echo.

REM ============================================
REM 4. 检查系统用户
REM ============================================
echo 4️⃣  检查系统用户...
docker exec %CONTAINER% psql -U admin -d postgres -t -c "SELECT COUNT(*) FROM pg_user WHERE usename LIKE '%%_user' OR usename = 'admin';" 2>nul | findstr /r "[0-9]" >nul
if %errorlevel% equ 0 (
    for /f %%i in ('docker exec %CONTAINER% psql -U admin -d postgres -t -c "SELECT COUNT(*) FROM pg_user WHERE usename LIKE ''%%_user'' OR usename = ''admin'';"') do set COUNT=%%i
    echo    ✅ 系统用户: %COUNT%个用户
    set /a SUCCESS+=1
) else (
    echo    ❌ 系统用户检查失败
    set /a FAILED+=1
)
echo.

REM ============================================
REM 5. 测试ColorMagic用户连接
REM ============================================
echo 5️⃣  测试ColorMagic用户连接...
docker exec %CONTAINER% psql -U colormagic_user -d postgres -c "SELECT current_user;" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ ColorMagic用户连接成功
    set /a SUCCESS+=1
) else (
    echo    ❌ ColorMagic用户连接失败
    set /a FAILED+=1
)
echo.

REM ============================================
REM 6. 测试ColorMagic用户权限
REM ============================================
echo 6️⃣  测试ColorMagic用户权限...
docker exec %CONTAINER% psql -U colormagic_user -d postgres -c "SELECT COUNT(*) FROM colormagic_users;" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ ColorMagic用户权限验证通过
    set /a SUCCESS+=1
) else (
    echo    ❌ ColorMagic用户权限验证失败
    set /a FAILED+=1
)
echo.

REM ============================================
REM 7. 测试系统统计函数
REM ============================================
echo 7️⃣  测试系统统计函数...
docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT get_system_stats();" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ 系统统计函数正常
    set /a SUCCESS+=1
) else (
    echo    ❌ 系统统计函数失败
    set /a FAILED+=1
)
echo.

REM ============================================
REM 8. 测试插入反馈
REM ============================================
echo 8️⃣  测试插入反馈...
docker exec %CONTAINER% psql -U colormagic_user -d postgres -c "INSERT INTO unified_feedback (site_id, content, category) VALUES ('colormagic', '本地验证测试反馈', 'test') RETURNING id;" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ 反馈插入成功
    set /a SUCCESS+=1
) else (
    echo    ❌ 反馈插入失败
    set /a FAILED+=1
)
echo.

REM ============================================
REM 显示结果
REM ============================================
echo ============================================
echo 📊 验证结果:
echo    成功: %SUCCESS%/8
echo    失败: %FAILED%/8
echo ============================================

if %FAILED% equ 0 (
    echo ✅ 所有验证测试完成 - 系统正常运行
    echo.
    echo 📝 系统统计:
    docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT jsonb_pretty(get_system_stats()::jsonb);"
) else (
    echo ❌ 部分测试失败，请检查日志
    echo.
    echo 查看详细日志: docker logs %CONTAINER%
)

echo.
pause

