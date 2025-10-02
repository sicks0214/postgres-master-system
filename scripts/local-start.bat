@echo off
REM ============================================
REM PostgreSQL总系统 - 本地启动脚本 (Windows)
REM ============================================

echo.
echo ============================================
echo PostgreSQL总系统 - 本地启动
echo ============================================
echo.

REM 检查Docker是否运行
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Docker未运行，请先启动Docker Desktop
    pause
    exit /b 1
)

echo ✅ Docker已运行
echo.

REM 进入项目目录
cd /d "%~dp0.."

echo 📦 启动PostgreSQL容器...
docker compose -f docker-compose.local.yml up -d

if %errorlevel% neq 0 (
    echo ❌ 启动失败
    pause
    exit /b 1
)

echo.
echo ⏳ 等待PostgreSQL初始化...
timeout /t 15 /nobreak >nul

echo.
echo 📋 查看启动日志:
docker logs postgres_local_test --tail 20

echo.
echo ============================================
echo ✅ 启动完成！
echo ============================================
echo.
echo 📊 容器信息:
echo    名称: postgres_local_test
echo    端口: 5433:5432
echo    用户: admin / supersecret
echo.
echo 📝 下一步:
echo    1. 运行验证脚本: scripts\local-verify.bat
echo    2. 查看日志: docker logs postgres_local_test -f
echo    3. 停止容器: docker compose -f docker-compose.local.yml down
echo.

pause

