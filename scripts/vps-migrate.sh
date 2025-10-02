#!/bin/bash

# ============================================================================
# VPS PostgreSQL 系统自动迁移脚本
# 从旧版本迁移到 v2.0
# ============================================================================

set -e  # 遇到错误立即退出

echo ""
echo "=============================================="
echo "PostgreSQL 总系统 - 自动迁移脚本"
echo "=============================================="
echo ""
echo "⚠️  警告：此操作将删除旧系统的所有数据！"
echo ""

# ============================================================================
# 步骤 0: 确认操作
# ============================================================================

read -p "是否已备份重要数据？(yes/no): " BACKUP_CONFIRM
if [ "$BACKUP_CONFIRM" != "yes" ]; then
    echo "❌ 请先备份数据后再继续"
    exit 1
fi

read -p "确认删除旧系统并部署新系统？(yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "❌ 操作已取消"
    exit 1
fi

echo ""
echo "✅ 确认开始迁移..."
echo ""

# ============================================================================
# 步骤 1: 备份旧系统
# ============================================================================

echo "=============================================="
echo "步骤 1: 备份旧系统"
echo "=============================================="
echo ""

# 创建备份目录
BACKUP_DIR="/root/postgres-backup"
mkdir -p $BACKUP_DIR
cd $BACKUP_DIR

# 查找旧容器
OLD_CONTAINER=$(docker ps -a | grep postgres | awk '{print $NF}' | head -1)

if [ ! -z "$OLD_CONTAINER" ]; then
    echo "📦 找到旧容器: $OLD_CONTAINER"
    
    # 检查容器是否运行
    if docker ps | grep "$OLD_CONTAINER" > /dev/null; then
        echo "⏳ 正在备份数据库..."
        BACKUP_FILE="postgres_backup_$(date +%Y%m%d_%H%M%S).sql.gz"
        
        if docker exec $OLD_CONTAINER pg_dumpall -U admin | gzip > $BACKUP_FILE; then
            echo "✅ 备份完成: $BACKUP_FILE"
            ls -lh $BACKUP_FILE
        else
            echo "⚠️  备份失败，但将继续迁移"
        fi
    else
        echo "⚠️  旧容器未运行，跳过备份"
    fi
else
    echo "ℹ️  未找到旧 PostgreSQL 容器"
fi

echo ""

# ============================================================================
# 步骤 2: 停止应用容器
# ============================================================================

echo "=============================================="
echo "步骤 2: 停止使用数据库的应用"
echo "=============================================="
echo ""

# 停止可能使用数据库的应用
for APP in site4 colormagic site1 site2; do
    if docker ps | grep "$APP" > /dev/null; then
        echo "⏹️  停止容器: $APP"
        docker stop $APP 2>/dev/null || true
    fi
done

echo "✅ 应用容器已停止"
echo ""

# ============================================================================
# 步骤 3: 删除旧系统
# ============================================================================

echo "=============================================="
echo "步骤 3: 删除旧系统"
echo "=============================================="
echo ""

# 停止所有 PostgreSQL 容器
echo "⏹️  停止所有 PostgreSQL 容器..."
docker ps -a | grep postgres | awk '{print $1}' | xargs -r docker stop 2>/dev/null || true

# 删除所有 PostgreSQL 容器
echo "🗑️  删除所有 PostgreSQL 容器..."
docker ps -a | grep postgres | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true

# 删除所有 PostgreSQL 数据卷
echo "🗑️  删除所有 PostgreSQL 数据卷..."
docker volume ls | grep postgres | awk '{print $2}' | xargs -r docker volume rm 2>/dev/null || true

# 备份旧部署目录
if [ -d "/docker/db_master" ]; then
    BACKUP_DIR_NAME="/docker/db_master_old_$(date +%Y%m%d_%H%M%S)"
    echo "📦 备份旧部署目录到: $BACKUP_DIR_NAME"
    mv /docker/db_master $BACKUP_DIR_NAME
fi

echo "✅ 旧系统已删除"
echo ""

# ============================================================================
# 步骤 4: 克隆新系统
# ============================================================================

echo "=============================================="
echo "步骤 4: 从 GitHub 克隆新系统"
echo "=============================================="
echo ""

# 创建新部署目录
mkdir -p /docker/db_master
cd /docker/db_master

# 克隆仓库
echo "📥 克隆仓库: https://github.com/sicks0214/postgres-master-system.git"
git clone https://github.com/sicks0214/postgres-master-system.git . || {
    echo "❌ 克隆失败，请检查网络连接"
    exit 1
}

echo "✅ 新系统代码已下载"
echo ""

# 验证文件
echo "📋 验证关键文件..."
if [ ! -f "docker-compose.vps.yml" ]; then
    echo "❌ 缺少 docker-compose.vps.yml"
    exit 1
fi

if [ ! -d "init-scripts" ]; then
    echo "❌ 缺少 init-scripts 目录"
    exit 1
fi

echo "✅ 文件验证通过"
echo ""

# ============================================================================
# 步骤 5: 配置生产密码
# ============================================================================

echo "=============================================="
echo "步骤 5: 配置生产环境密码"
echo "=============================================="
echo ""

echo "⚠️  重要：请手动修改以下文件中的密码："
echo ""
echo "1. init-scripts/02_site4_colormagic.sql"
echo "   第13行: ColorMagic_Local_Test_Pass → ColorMagic_VPS_2024_Secure_Pass"
echo ""
echo "2. init-scripts/03_sites_and_functions.sql"
echo "   第12-18行: site%s_test_pass → site%s_prod_pass_2024"
echo ""

read -p "已手动修改密码？(yes/no): " PASSWORD_CONFIRM
if [ "$PASSWORD_CONFIRM" != "yes" ]; then
    echo ""
    echo "请使用以下命令修改密码："
    echo "  nano init-scripts/02_site4_colormagic.sql"
    echo "  nano init-scripts/03_sites_and_functions.sql"
    echo ""
    echo "修改完成后重新运行此脚本"
    exit 1
fi

echo "✅ 密码已配置"
echo ""

# ============================================================================
# 步骤 6: 创建 Docker 网络
# ============================================================================

echo "=============================================="
echo "步骤 6: 创建 Docker 网络"
echo "=============================================="
echo ""

# 创建 shared_net 网络
if docker network create shared_net 2>/dev/null; then
    echo "✅ 创建 shared_net 网络"
else
    echo "ℹ️  shared_net 网络已存在"
fi

echo ""

# ============================================================================
# 步骤 7: 部署新系统
# ============================================================================

echo "=============================================="
echo "步骤 7: 部署新系统"
echo "=============================================="
echo ""

# 启动 PostgreSQL
echo "🚀 启动 PostgreSQL 容器..."
docker compose -f docker-compose.vps.yml up -d

# 等待初始化
echo "⏳ 等待数据库初始化（20秒）..."
sleep 20

# 检查容器状态
if docker ps | grep postgres_master > /dev/null; then
    echo "✅ PostgreSQL 容器运行中"
else
    echo "❌ PostgreSQL 容器启动失败"
    echo ""
    echo "查看日志："
    docker logs postgres_master --tail 50
    exit 1
fi

echo ""

# ============================================================================
# 步骤 8: 验证新系统
# ============================================================================

echo "=============================================="
echo "步骤 8: 验证新系统"
echo "=============================================="
echo ""

SUCCESS=0
FAILED=0

# 测试1: 数据库连接
echo -n "1️⃣  测试数据库连接... "
if docker exec postgres_master psql -U admin -d postgres -c "SELECT 1" > /dev/null 2>&1; then
    echo "✅"
    ((SUCCESS++))
else
    echo "❌"
    ((FAILED++))
fi

# 测试2: ColorMagic 表
echo -n "2️⃣  检查 ColorMagic 表... "
TABLE_COUNT=$(docker exec postgres_master psql -U admin -d postgres -t -c "SELECT COUNT(*) FROM pg_tables WHERE tablename LIKE 'colormagic_%';" | tr -d ' ')
if [ "$TABLE_COUNT" -eq "7" ]; then
    echo "✅ ($TABLE_COUNT 个表)"
    ((SUCCESS++))
else
    echo "❌ ($TABLE_COUNT 个表，应为7个)"
    ((FAILED++))
fi

# 测试3: colormagic_user 权限
echo -n "3️⃣  测试 colormagic_user 权限... "
if docker exec postgres_master psql -U colormagic_user -d postgres -c "SELECT COUNT(*) FROM colormagic_users;" > /dev/null 2>&1; then
    echo "✅"
    ((SUCCESS++))
else
    echo "❌"
    ((FAILED++))
fi

# 测试4: 系统函数
echo -n "4️⃣  测试系统函数... "
if docker exec postgres_master psql -U admin -d postgres -c "SELECT get_system_stats();" > /dev/null 2>&1; then
    echo "✅"
    ((SUCCESS++))
else
    echo "❌"
    ((FAILED++))
fi

echo ""
echo "=============================================="
echo "验证结果: 成功 $SUCCESS / 失败 $FAILED"
echo "=============================================="
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✅✅✅ 迁移成功！新系统运行正常"
    echo ""
    echo "📊 系统统计："
    docker exec postgres_master psql -U admin -d postgres -c "SELECT jsonb_pretty(get_system_stats()::jsonb);"
    echo ""
    echo "📝 下一步操作："
    echo "1. 更新应用的 .env 文件（修改数据库密码）"
    echo "2. 重启应用容器"
    echo "3. 测试应用连接"
    echo ""
else
    echo "❌ 部分验证失败"
    echo ""
    echo "查看详细日志："
    echo "  docker logs postgres_master --tail 50"
    echo ""
fi

# ============================================================================
# 完成
# ============================================================================

echo "=============================================="
echo "迁移完成！"
echo "=============================================="
echo ""
echo "📦 备份位置: $BACKUP_DIR"
echo "📁 部署位置: /docker/db_master"
echo ""
echo "💡 有用的命令："
echo "  - 查看日志: docker logs postgres_master -f"
echo "  - 进入数据库: docker exec -it postgres_master psql -U admin -d postgres"
echo "  - 查看统计: docker exec postgres_master psql -U admin -d postgres -c 'SELECT get_system_stats();'"
echo ""

