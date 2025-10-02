#!/bin/bash
# ============================================
# PostgreSQL总系统 - 导出到VPS脚本
# ============================================

set -e

echo ""
echo "============================================"
echo "PostgreSQL总系统 - 导出到VPS"
echo "============================================"
echo ""

# 进入项目目录
cd "$(dirname "$0")/.."

# 创建导出目录
mkdir -p export-to-vps

echo "📦 准备导出文件..."
echo ""

# 方式1：打包整个系统（推荐）
echo "1️⃣  打包完整系统..."
tar -czf export-to-vps/postgres-master-system.tar.gz \
    --exclude='export-to-vps' \
    --exclude='backups/*' \
    --exclude='.git' \
    *

echo "✅ 完整系统已打包: export-to-vps/postgres-master-system.tar.gz"
echo ""

# 方式2：只打包必要文件（用于已有系统更新）
echo "2️⃣  打包核心文件..."
tar -czf export-to-vps/postgres-core-files.tar.gz \
    docker-compose.vps.yml \
    init-scripts/ \
    scripts/

echo "✅ 核心文件已打包: export-to-vps/postgres-core-files.tar.gz"
echo ""

# 生成部署说明
cat > export-to-vps/DEPLOY_INSTRUCTIONS.txt << 'EOF'
============================================
PostgreSQL总系统 - VPS部署说明
============================================

方式A：完整部署（推荐新系统）
--------------------------------------------
1. 上传文件到VPS:
   scp postgres-master-system.tar.gz root@YOUR_VPS_IP:/tmp/

2. SSH到VPS并解压:
   ssh root@YOUR_VPS_IP
   mkdir -p /docker/db_master
   cd /docker/db_master
   tar -xzf /tmp/postgres-master-system.tar.gz

3. 修改生产密码（重要！）:
   nano init-scripts/02_site4_colormagic.sql
   # 将 ColorMagic_Local_Test_Pass 改为 ColorMagic_VPS_2024_Secure_Pass
   
   nano init-scripts/03_sites_and_functions.sql
   # 将 site%s_test_pass 改为 site%s_pass

4. 创建网络并启动:
   docker network create shared_net 2>/dev/null || true
   docker compose -f docker-compose.vps.yml up -d

5. 验证部署:
   sleep 15
   docker logs postgres_master --tail 30
   docker exec postgres_master psql -U admin -d postgres -c "SELECT get_system_stats();"

方式B：更新现有系统
--------------------------------------------
1. 上传核心文件:
   scp postgres-core-files.tar.gz root@YOUR_VPS_IP:/tmp/

2. 在VPS上备份旧配置:
   cd /docker/db_master
   cp -r init-scripts init-scripts.backup
   
3. 解压新文件:
   tar -xzf /tmp/postgres-core-files.tar.gz
   
4. 修改密码并重启:
   # 参考方式A的步骤3-5

重要提醒:
- ⚠️ 修改所有用户密码为生产密码
- ⚠️ 备份旧数据再更新
- ⚠️ 确保shared_net网络已创建
- ⚠️ 修改docker-compose.vps.yml中的admin密码

验证命令:
- docker ps | grep postgres_master
- docker logs postgres_master
- docker exec postgres_master psql -U colormagic_user -d postgres -c "SELECT current_user;"

============================================
EOF

echo "📄 部署说明已生成: export-to-vps/DEPLOY_INSTRUCTIONS.txt"
echo ""

# 显示文件信息
echo "============================================"
echo "📊 导出文件列表:"
echo "============================================"
ls -lh export-to-vps/
echo ""

echo "============================================"
echo "✅ 导出完成！"
echo "============================================"
echo ""
echo "📝 下一步:"
echo "   1. 查看部署说明: cat export-to-vps/DEPLOY_INSTRUCTIONS.txt"
echo "   2. 上传到VPS: scp export-to-vps/postgres-master-system.tar.gz root@YOUR_VPS_IP:/tmp/"
echo "   3. 按照DEPLOY_INSTRUCTIONS.txt中的步骤部署"
echo ""

