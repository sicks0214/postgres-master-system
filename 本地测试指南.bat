@echo off
chcp 65001 >nul
REM ============================================
REM ColorMagic 数据库本地测试完整指南
REM ============================================

echo.
echo ============================================
echo ColorMagic 数据库 - 本地完整测试
echo ============================================
echo.

REM 设置变量
set CONTAINER=postgres_local_test
set SUCCESS=0
set FAILED=0

REM ============================================
REM 步骤0: 检查Docker
REM ============================================
echo 📋 步骤 0: 检查 Docker 状态...
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Docker 未运行
    echo.
    echo 💡 请先启动 Docker Desktop，然后重新运行此脚本
    echo    - 双击桌面的 Docker Desktop 图标
    echo    - 等待 Docker 图标变成绿色（通常需要30-60秒）
    echo.
    pause
    exit /b 1
)
echo ✅ Docker 正在运行
echo.

REM ============================================
REM 步骤1: 启动 PostgreSQL
REM ============================================
echo ============================================
echo 📋 步骤 1: 启动 PostgreSQL 容器
echo ============================================
echo.

docker ps -a | findstr %CONTAINER% >nul 2>&1
if %errorlevel% equ 0 (
    echo ℹ️  容器已存在，检查状态...
    docker ps | findstr %CONTAINER% >nul 2>&1
    if %errorlevel% neq 0 (
        echo ⏳ 启动已存在的容器...
        docker start %CONTAINER%
    ) else (
        echo ✅ 容器已在运行
    )
) else (
    echo 📦 创建并启动新容器...
    docker compose -f docker-compose.local.yml up -d
    if %errorlevel% neq 0 (
        echo ❌ 容器启动失败
        echo.
        echo 查看详细错误:
        docker logs %CONTAINER%
        pause
        exit /b 1
    )
)

echo.
echo ⏳ 等待 PostgreSQL 初始化（20秒）...
timeout /t 20 /nobreak >nul

echo.
echo 📋 查看初始化日志（最后30行）:
echo ----------------------------------------
docker logs %CONTAINER% --tail 30
echo ----------------------------------------
echo.

REM ============================================
REM 步骤2: 验证数据库基础功能
REM ============================================
echo ============================================
echo 📋 步骤 2: 验证数据库基础功能
echo ============================================
echo.

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

echo 2️⃣  检查统一反馈表...
docker exec %CONTAINER% psql -U admin -d postgres -t -c "SELECT COUNT(*) FROM unified_feedback;" >nul 2>&1
if %errorlevel% equ 0 (
    for /f %%i in ('docker exec %CONTAINER% psql -U admin -d postgres -t -c "SELECT COUNT(*) FROM unified_feedback;"') do set COUNT=%%i
    echo    ✅ 统一反馈表: %COUNT% 条记录
    set /a SUCCESS+=1
) else (
    echo    ❌ 统一反馈表检查失败
    set /a FAILED+=1
)
echo.

REM ============================================
REM 步骤3: 验证 ColorMagic 表结构
REM ============================================
echo ============================================
echo 📋 步骤 3: 验证 ColorMagic 表结构
echo ============================================
echo.

echo 3️⃣  检查 ColorMagic 表数量...
docker exec %CONTAINER% psql -U admin -d postgres -t -c "SELECT COUNT(*) FROM pg_tables WHERE tablename LIKE 'colormagic_%%';" >nul 2>&1
if %errorlevel% equ 0 (
    for /f %%i in ('docker exec %CONTAINER% psql -U admin -d postgres -t -c "SELECT COUNT(*) FROM pg_tables WHERE tablename LIKE ''colormagic_%%'';"') do set COUNT=%%i
    echo    ✅ ColorMagic 表: %COUNT% 个表
    set /a SUCCESS+=1
) else (
    echo    ❌ ColorMagic 表检查失败
    set /a FAILED+=1
)
echo.

echo 📊 ColorMagic 表列表:
echo ----------------------------------------
docker exec %CONTAINER% psql -U admin -d postgres -c "\dt colormagic_*"
echo ----------------------------------------
echo.

REM ============================================
REM 步骤4: 验证用户和权限
REM ============================================
echo ============================================
echo 📋 步骤 4: 验证用户和权限
echo ============================================
echo.

echo 4️⃣  检查 colormagic_user 用户...
docker exec %CONTAINER% psql -U colormagic_user -d postgres -c "SELECT current_user;" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ colormagic_user 连接成功
    set /a SUCCESS+=1
) else (
    echo    ❌ colormagic_user 连接失败
    set /a FAILED+=1
)
echo.

echo 5️⃣  测试 colormagic_user 权限（读取用户表）...
docker exec %CONTAINER% psql -U colormagic_user -d postgres -c "SELECT COUNT(*) FROM colormagic_users;" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ 权限验证通过（可读取 colormagic_users）
    set /a SUCCESS+=1
) else (
    echo    ❌ 权限验证失败
    set /a FAILED+=1
)
echo.

REM ============================================
REM 步骤5: 测试数据查询
REM ============================================
echo ============================================
echo 📋 步骤 5: 测试数据查询
echo ============================================
echo.

echo 6️⃣  查询测试用户...
echo ----------------------------------------
docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT username, email, status, email_verified, subscription_type FROM colormagic_users;"
echo ----------------------------------------
echo.

echo 7️⃣  查询测试调色板...
echo ----------------------------------------
docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT p.palette_name, u.username, p.tags, p.created_at FROM colormagic_palettes p JOIN colormagic_users u ON p.user_id = u.id;"
echo ----------------------------------------
echo.

echo 8️⃣  查询反馈记录...
echo ----------------------------------------
docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT id, site_id, LEFT(content, 50) as content, category, rating FROM unified_feedback WHERE site_id = 'colormagic';"
echo ----------------------------------------
echo.

REM ============================================
REM 步骤6: 测试插入操作
REM ============================================
echo ============================================
echo 📋 步骤 6: 测试插入操作
echo ============================================
echo.

echo 9️⃣  测试插入反馈（使用 colormagic_user）...
docker exec %CONTAINER% psql -U colormagic_user -d postgres -c "INSERT INTO unified_feedback (site_id, content, category, rating) VALUES ('colormagic', '本地测试 - 数据库功能正常', 'test', 5) RETURNING id, site_id, content;" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ 反馈插入成功
    set /a SUCCESS+=1
    docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT id, site_id, content, rating FROM unified_feedback WHERE category = 'test' ORDER BY id DESC LIMIT 1;"
) else (
    echo    ❌ 反馈插入失败
    set /a FAILED+=1
)
echo.

echo 🔟  测试插入颜色分析记录...
docker exec %CONTAINER% psql -U colormagic_user -d postgres -c "INSERT INTO colormagic_color_analysis (analysis_id, image_name, processing_time_ms, algorithm) VALUES ('test_analysis_001', 'test_image.jpg', 123, 'production') RETURNING id, analysis_id, image_name;" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ 分析记录插入成功
    set /a SUCCESS+=1
) else (
    echo    ❌ 分析记录插入失败
    set /a FAILED+=1
)
echo.

REM ============================================
REM 步骤7: 测试系统函数
REM ============================================
echo ============================================
echo 📋 步骤 7: 测试系统函数
echo ============================================
echo.

echo 1️⃣1️⃣  测试 get_system_stats^(^) 函数...
docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT get_system_stats();" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ 系统统计函数正常
    set /a SUCCESS+=1
    echo.
    echo    📊 系统统计详情:
    echo    ----------------------------------------
    docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT jsonb_pretty(get_system_stats()::jsonb);"
    echo    ----------------------------------------
) else (
    echo    ❌ 系统统计函数失败
    set /a FAILED+=1
)
echo.

echo 1️⃣2️⃣  测试 get_colormagic_system_stats^(^) 函数...
docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT get_colormagic_system_stats();" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ ColorMagic 统计函数正常
    set /a SUCCESS+=1
    echo.
    echo    📊 ColorMagic 统计详情:
    echo    ----------------------------------------
    docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT jsonb_pretty(get_colormagic_system_stats()::jsonb);"
    echo    ----------------------------------------
) else (
    echo    ❌ ColorMagic 统计函数失败
    set /a FAILED+=1
)
echo.

echo 1️⃣3️⃣  测试 get_active_sites^(^) 函数...
docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT * FROM get_active_sites();" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ 活跃站点函数正常
    set /a SUCCESS+=1
    echo.
    echo    📊 活跃站点列表:
    echo    ----------------------------------------
    docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT * FROM get_active_sites();"
    echo    ----------------------------------------
) else (
    echo    ❌ 活跃站点函数失败
    set /a FAILED+=1
)
echo.

REM ============================================
REM 步骤8: 性能测试
REM ============================================
echo ============================================
echo 📋 步骤 8: 性能和容量检查
echo ============================================
echo.

echo 📊 数据库大小:
docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT pg_size_pretty(pg_database_size('postgres')) as database_size;"
echo.

echo 📊 表大小统计:
docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'colormagic_%%' ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
echo.

echo 📊 当前连接数:
docker exec %CONTAINER% psql -U admin -d postgres -c "SELECT count(*) as active_connections FROM pg_stat_activity WHERE state = 'active';"
echo.

REM ============================================
REM 显示测试结果
REM ============================================
echo ============================================
echo 📊 测试结果汇总
echo ============================================
echo.
echo    成功: %SUCCESS%/13
echo    失败: %FAILED%/13
echo.

if %FAILED% equ 0 (
    echo ✅✅✅ 所有测试通过 - ColorMagic 数据库系统正常运行！
    echo.
    echo 🎉 恭喜！数据库已完全就绪，可以开始接入应用了。
    echo.
    echo 📝 下一步操作:
    echo    1. 配置应用的 .env 文件（DB_HOST=postgres_master）
    echo    2. 确保应用容器连接到 shared_net 网络
    echo    3. 修改代码中的表名为 colormagic_* 前缀
    echo    4. 启动应用并测试数据库连接
    echo.
) else (
    echo ❌ 部分测试失败，请检查以下内容:
    echo    1. 查看详细日志: docker logs %CONTAINER%
    echo    2. 检查初始化脚本是否执行: init-scripts/
    echo    3. 如果问题持续，尝试重新初始化:
    echo       docker compose -f docker-compose.local.yml down -v
    echo       docker compose -f docker-compose.local.yml up -d
    echo.
)

echo ============================================
echo.

echo 💡 有用的命令:
echo    - 查看日志: docker logs %CONTAINER% -f
echo    - 进入数据库: docker exec -it %CONTAINER% psql -U admin -d postgres
echo    - 停止容器: docker compose -f docker-compose.local.yml down
echo    - 重启容器: docker compose -f docker-compose.local.yml restart
echo.

pause

