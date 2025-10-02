#!/bin/bash
# ============================================
# PostgreSQL总系统 - 本地启动脚本 (Linux/Mac)
# ============================================

set -e

echo ""
echo "============================================"
echo "PostgreSQL总系统 - 本地启动"
echo "============================================"
echo ""

# 检查Docker是否运行
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker未运行，请先启动Docker"
    exit 1
fi

echo "✅ Docker已运行"
echo ""

# 进入项目目录
cd "$(dirname "$0")/.."

echo "📦 启动PostgreSQL容器..."
docker compose -f docker-compose.local.yml up -d

echo ""
echo "⏳ 等待PostgreSQL初始化..."
sleep 15

echo ""
echo "📋 查看启动日志:"
docker logs postgres_local_test --tail 20

echo ""
echo "============================================"
echo "✅ 启动完成！"
echo "============================================"
echo ""
echo "📊 容器信息:"
echo "   名称: postgres_local_test"
echo "   端口: 5433:5432"
echo "   用户: admin / supersecret"
echo ""
echo "📝 下一步:"
echo "   1. 运行验证脚本: ./scripts/local-verify.sh"
echo "   2. 查看日志: docker logs postgres_local_test -f"
echo "   3. 停止容器: docker compose -f docker-compose.local.yml down"
echo ""

