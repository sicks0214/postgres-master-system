# PostgreSQL总系统 - 完整部署指南

**版本**: 2.0  
**更新日期**: 2024-10-02  
**支持站点**: 1-20个站点  
**适用于**: ColorMagic (Site4) 及未来站点扩展

---

## 📋 目录

1. [系统概述](#系统概述)
2. [文件结构](#文件结构)
3. [本地测试部署](#本地测试部署)
4. [VPS生产部署](#vps生产部署)
5. [验证测试](#验证测试)
6. [站点接入指南](#站点接入指南)
7. [常见问题](#常见问题)
8. [备份恢复](#备份恢复)

---

## 📖 系统概述

### 架构设计

```
PostgreSQL总系统 (postgres_master)
├── 数据库: postgres (主数据库)
├── 管理员: admin / supersecret
├── 用户体系:
│   ├── colormagic_user (Site4 - ColorMagic专用)
│   └── site1_user ~ site20_user (预留20个站点)
├── 表结构:
│   ├── unified_feedback (所有站点共享反馈表)
│   ├── colormagic_* (Site4专用，9个表)
│   └── site1_*, site2_*, ... (未来站点表前缀)
└── 网络: shared_net (Docker网络别名: postgres_master)
```

### 核心特性

- ✅ **多站点支持**: 单实例支持20个站点
- ✅ **权限隔离**: 每个站点独立用户，只能访问自己的表
- ✅ **统一反馈**: 所有站点共享反馈表，通过site_id区分
- ✅ **表前缀系统**: 避免表名冲突（colormagic_*, site1_*, site2_*...）
- ✅ **Docker容器化**: 一键部署，环境一致
- ✅ **自动初始化**: 首次启动自动创建所有表和用户
- ✅ **健康检查**: 内置健康监控和自动重启

### Site4 (ColorMagic) 表列表

| 表名 | 用途 | 关联 |
|------|------|------|
| `colormagic_users` | 用户表 | 认证系统 |
| `colormagic_sessions` | 会话表 | 认证系统 |
| `colormagic_analysis_history` | 分析历史表（用户关联） | 认证系统 |
| `colormagic_palettes` | 收藏调色板表 | 认证系统 |
| `colormagic_usage_stats` | 使用统计表 | 认证系统 |
| `colormagic_color_analysis` | 颜色分析记录表（独立） | 颜色分析 |
| `colormagic_export_history` | 导出历史表 | 颜色分析 |
| `unified_feedback` | 反馈表（共享，site_id='colormagic'） | 反馈系统 |

---

## 📁 文件结构

```
postgres-master-system/
├── README.md                          # 本文档
├── docker-compose.local.yml           # 本地测试配置
├── docker-compose.vps.yml             # VPS生产配置
├── init-scripts/                      # 数据库初始化脚本
│   ├── 01_unified_feedback.sql        # 统一反馈表
│   ├── 02_site4_colormagic.sql        # Site4 (ColorMagic) 专用表
│   └── 03_sites_and_functions.sql     # 其他站点和系统函数
├── scripts/                           # 管理脚本
│   ├── local-start.bat                # 本地启动（Windows）
│   ├── local-start.sh                 # 本地启动（Linux/Mac）
│   ├── local-verify.bat               # 本地验证（Windows）
│   ├── local-verify.sh                # 本地验证（Linux/Mac）
│   ├── export-to-vps.sh               # 导出到VPS
│   └── vps-deploy.sh                  # VPS部署脚本
└── docs/                              # 文档
    ├── SITE4_INTEGRATION.md           # Site4接入指南
    ├── NEW_SITE_GUIDE.md              # 新站点接入指南
    └── TROUBLESHOOTING.md             # 故障排查

使用说明：
1. 本地测试：使用 docker-compose.local.yml
2. VPS部署：使用 docker-compose.vps.yml
3. 首次启动会自动执行 init-scripts/ 中的所有SQL脚本
```

---

## 🏠 本地测试部署

### 前置要求

- Docker Desktop (Windows/Mac) 或 Docker Engine (Linux)
- Docker Compose v2.0+
- 至少 2GB 可用内存

### 步骤1：复制系统文件

```bash
# Windows PowerShell
cd C:\Users\Administrator.USER-20240417KK\Documents\GitHub

# 复制整个postgres-master-system文件夹到本地测试目录
cp -r "template A\database\postgres-master-system" "postgres-test"
cd postgres-test
```

### 步骤2：启动本地PostgreSQL

#### Windows:
```cmd
# 双击运行或命令行执行
scripts\local-start.bat
```

#### Linux/Mac:
```bash
chmod +x scripts/local-start.sh
./scripts/local-start.sh
```

#### 或使用Docker Compose手动启动:
```bash
docker compose -f docker-compose.local.yml up -d
```

### 步骤3：等待初始化完成

```bash
# 查看初始化日志
docker logs postgres_local_test --tail 100

# 等待看到以下消息：
# ✅ 创建用户: colormagic_user
# ✅ 创建用户: site1_user
# ...
# database system is ready to accept connections
```

### 步骤4：验证本地部署

#### Windows:
```cmd
scripts\local-verify.bat
```

#### Linux/Mac:
```bash
chmod +x scripts/local-verify.sh
./scripts/local-verify.sh
```

### 预期输出

```
==========================================
PostgreSQL总系统 - 本地验证测试
==========================================

✅ 1. 数据库连接成功
✅ 2. 统一反馈表: 3条记录
✅ 3. ColorMagic表: 7个表
✅ 4. 系统用户: 22个 (admin + colormagic_user + 20个site_user)
✅ 5. ColorMagic用户连接成功
✅ 6. ColorMagic用户权限验证通过
✅ 7. 系统统计函数正常

==========================================
✅ 所有验证测试完成 - 系统正常运行
==========================================
```

---

## 🚀 VPS生产部署

### 前置要求

- VPS服务器 (Ubuntu 20.04+ 推荐)
- Docker + Docker Compose 已安装
- SSH访问权限
- 至少 2GB 可用内存

### 方式A：上传整个文件夹（推荐）

#### 步骤1：打包本地系统

```bash
# 在本地 postgres-test 目录
cd ..
tar -czf postgres-master-system.tar.gz postgres-test/

# 或只打包必要文件（不含本地数据）
cd postgres-test
tar -czf postgres-master-system.tar.gz \
    docker-compose.vps.yml \
    init-scripts/ \
    scripts/
```

#### 步骤2：上传到VPS

```bash
# 上传到VPS
scp postgres-master-system.tar.gz root@YOUR_VPS_IP:/tmp/

# SSH到VPS
ssh root@YOUR_VPS_IP
```

#### 步骤3：在VPS上部署

```bash
# 创建部署目录
mkdir -p /docker/db_master
cd /docker/db_master

# 解压
tar -xzf /tmp/postgres-master-system.tar.gz --strip-components=1

# 修改生产环境密码（重要！）
nano init-scripts/02_site4_colormagic.sql
# 将 ColorMagic_Local_Test_Pass 改为 ColorMagic_VPS_2024_Secure_Pass

nano init-scripts/03_sites_and_functions.sql
# 将 site%s_test_pass 改为 site%s_pass

# 创建shared_net网络
docker network create shared_net 2>/dev/null || echo "shared_net已存在"

# 启动PostgreSQL
docker compose -f docker-compose.vps.yml up -d

# 查看启动日志
docker logs postgres_master --tail 100

# 等待初始化完成（约15-30秒）
sleep 20
```

#### 步骤4：验证VPS部署

```bash
# 在VPS上执行
cd /docker/db_master

# 运行验证脚本
chmod +x scripts/vps-verify.sh
./scripts/vps-verify.sh

# 或手动验证
docker exec postgres_master psql -U admin -d postgres -c "SELECT get_system_stats();"
docker exec postgres_master psql -U colormagic_user -d postgres -c "SELECT current_user;"
```

### 方式B：Git拉取（适合已在Git仓库中）

```bash
# 在VPS上
cd /docker
git clone https://github.com/your-repo/template-A.git
cd template-A/database/postgres-master-system

# 按照方式A的步骤3-4继续
```

---

## ✅ 验证测试

### 基础验证

```bash
# 1. 检查容器状态
docker ps | grep postgres

# 2. 测试数据库连接
docker exec postgres_master psql -U admin -d postgres -c "SELECT version();"

# 3. 检查所有表
docker exec postgres_master psql -U admin -d postgres -c "\dt"

# 4. 检查ColorMagic表
docker exec postgres_master psql -U admin -d postgres -c "\dt colormagic_*"

# 5. 检查用户
docker exec postgres_master psql -U admin -d postgres -c "\du"
```

### 功能验证

```sql
-- 1. 测试统一反馈表
INSERT INTO unified_feedback (site_id, content, category) 
VALUES ('colormagic', '测试反馈内容', 'test');

SELECT * FROM unified_feedback WHERE site_id = 'colormagic';

-- 2. 测试ColorMagic用户权限
-- 使用 colormagic_user 连接
SELECT COUNT(*) FROM colormagic_users;
SELECT COUNT(*) FROM colormagic_color_analysis;

-- 3. 测试系统函数
SELECT jsonb_pretty(get_system_stats()::jsonb);
SELECT * FROM get_active_sites();
```

### 性能验证

```bash
# 查看连接数
docker exec postgres_master psql -U admin -d postgres -c "
SELECT count(*) as active_connections 
FROM pg_stat_activity 
WHERE state = 'active';
"

# 查看数据库大小
docker exec postgres_master psql -U admin -d postgres -c "
SELECT pg_database.datname, 
       pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;
"
```

---

## 🔌 站点接入指南

### Site4 (ColorMagic) 接入配置

#### 应用环境变量配置

在 Site4 应用的 `.env` 文件中配置：

```bash
# PostgreSQL总系统连接配置
USE_DATABASE=true
DB_HOST=postgres_master          # Docker网络别名
DB_PORT=5432
DB_NAME=postgres
DB_USER=colormagic_user
DB_PASSWORD=ColorMagic_VPS_2024_Secure_Pass
DB_SSL=false
DB_MAX_CONNECTIONS=20

# 站点标识（用于unified_feedback表）
SITE_ID=colormagic

# 其他配置...
JWT_SECRET=your-super-secret-jwt-key
ALLOWED_ORIGINS=https://imagecolorpicker.cc,https://www.imagecolorpicker.cc
```

#### 应用网络配置

确保应用容器连接到 `shared_net` 网络：

```bash
# 方式1：docker run
docker run -d --name site4 \
  --network shared_net \
  --env-file .env \
  your-image:latest

# 方式2：docker-compose.yml
networks:
  - shared_net

networks:
  shared_net:
    external: true
```

#### 代码适配

需要确保代码中的表名与PostgreSQL系统一致：

| 原表名 | PostgreSQL表名 | 说明 |
|--------|---------------|------|
| `users` | `colormagic_users` | 用户表 |
| `user_sessions` | `colormagic_sessions` | 会话表 |
| `user_analysis_history` | `colormagic_analysis_history` | 分析历史 |
| `user_favorite_palettes` | `colormagic_palettes` | 收藏调色板 |
| `user_usage_stats` | `colormagic_usage_stats` | 使用统计 |
| `analysis_history` | `colormagic_color_analysis` | 颜色分析 |
| `export_history` | `colormagic_export_history` | 导出历史 |
| `feedback` 或 `unified_feedback` | `unified_feedback` | 反馈表（site_id='colormagic'） |

### 新站点接入（Site 1-20）

详细指南请参考：[docs/NEW_SITE_GUIDE.md](docs/NEW_SITE_GUIDE.md)

**快速步骤**：

1. 创建站点表（使用表前缀，如 `site5_users`）
2. 授予站点用户权限（`site5_user` 已预创建）
3. 配置应用环境变量
4. 连接到 `shared_net` 网络
5. 在 `unified_feedback` 表中使用对应的 `site_id`

---

## 🔧 常见问题

### 1. 容器启动失败

**问题**: `docker compose up -d` 执行后容器立即退出

**检查**:
```bash
# 查看容器日志
docker logs postgres_master --tail 50

# 查看容器状态
docker ps -a | grep postgres
```

**常见原因**:
- 端口5432被占用 → 修改 `docker-compose.yml` 中的端口映射
- 数据卷冲突 → 删除旧volume: `docker volume rm postgres_master_postgres_data`
- 内存不足 → 检查系统内存，至少需要2GB

### 2. 连接失败

**问题**: 应用无法连接到PostgreSQL

**检查网络**:
```bash
# 检查shared_net网络
docker network inspect shared_net

# 检查容器是否在shared_net中
docker inspect site4 | grep -A 10 "Networks"

# 测试DNS解析
docker exec site4 ping -c 2 postgres_master
```

**解决方法**:
```bash
# 重新连接网络
docker network disconnect shared_net site4
docker network connect shared_net site4
```

### 3. 权限错误 ⚠️（新站点常见）

**问题**: `permission denied for table xxx`

**快速解决（推荐）**:
```bash
# 使用自动化脚本（最简单）
cd /docker/db_master
./scripts/fix-permissions.sh site3_user

# 或手动授权（适用于任何站点）
docker exec postgres_master psql -U admin -d postgres -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO site3_user;"
docker exec postgres_master psql -U admin -d postgres -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO site3_user;"

# 验证
docker exec postgres_master psql -U site3_user -d postgres -c "SELECT COUNT(*) FROM site3__users;"
```

**详细排查**:
```bash
# 1. 检查权限
docker exec postgres_master psql -U admin -d postgres -c "
SELECT grantee, table_name, privilege_type 
FROM information_schema.table_privileges 
WHERE grantee = 'colormagic_user' AND table_name LIKE 'colormagic_%';
"

# 2. 如果没有权限，授予所有权限
docker exec postgres_master psql -U admin -d postgres -c "
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO colormagic_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO colormagic_user;
"
```

**📖 详细指南**: 查看 `故障排查与问题解决指南.md` - 权限问题章节

### 4. 初始化脚本未执行

**问题**: 表不存在

**原因**: Docker卷已存在数据，初始化脚本被跳过

**解决**:
```bash
# 完全清除并重新初始化
docker compose down -v
docker volume rm postgres_master_postgres_data
docker compose up -d
```

### 5. 密码认证失败

**问题**: `password authentication failed`

**检查密码**:
```bash
# 查看.env文件中的密码
cat /docker/site4/backend/.env | grep DB_PASSWORD

# 检查PostgreSQL中的用户
docker exec postgres_master psql -U admin -d postgres -c "
SELECT usename FROM pg_user WHERE usename = 'colormagic_user';
"
```

**重置密码**:
```bash
docker exec postgres_master psql -U admin -d postgres -c "
ALTER USER colormagic_user WITH PASSWORD 'NewPassword123';
"

# 同时更新应用的.env文件
```

---

## 💾 备份恢复

### 自动备份

创建定时备份脚本：

```bash
# 创建备份脚本
cat > /docker/db_master/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/docker/db_master/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# 全库备份
docker exec postgres_master pg_dumpall -U admin | \
  gzip > $BACKUP_DIR/postgres_full_${DATE}.sql.gz

# 只保留最近7天的备份
find $BACKUP_DIR -name "*.sql.gz" -mtime +7 -delete

echo "✅ 备份完成: postgres_full_${DATE}.sql.gz"
EOF

chmod +x /docker/db_master/backup.sh

# 添加到crontab（每天凌晨3点备份）
crontab -e
# 添加: 0 3 * * * /docker/db_master/backup.sh
```

### 手动备份

```bash
# 备份所有数据库
docker exec postgres_master pg_dumpall -U admin > backup_$(date +%Y%m%d).sql

# 只备份结构（不含数据）
docker exec postgres_master pg_dumpall -U admin --schema-only > schema_$(date +%Y%m%d).sql

# 备份单个站点的表
docker exec postgres_master pg_dump -U admin -d postgres \
  -t 'colormagic_*' > colormagic_backup_$(date +%Y%m%d).sql
```

### 恢复数据库

```bash
# 恢复完整备份
cat backup_20241002.sql | docker exec -i postgres_master psql -U admin -d postgres

# 恢复gzip压缩备份
gunzip -c backup_20241002.sql.gz | docker exec -i postgres_master psql -U admin -d postgres

# 恢复单个站点
cat colormagic_backup_20241002.sql | docker exec -i postgres_master psql -U admin -d postgres
```

---

## 📊 监控和维护

### 系统监控

```bash
# 实时监控
watch -n 5 'docker exec postgres_master psql -U admin -d postgres -c "SELECT get_system_stats();"'

# 查看活跃连接
docker exec postgres_master psql -U admin -d postgres -c "
SELECT usename, application_name, client_addr, state, query 
FROM pg_stat_activity 
WHERE state = 'active';
"

# 查看表大小
docker exec postgres_master psql -U admin -d postgres -c "
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
LIMIT 10;
"
```

### 性能优化

```bash
# 分析表统计信息
docker exec postgres_master psql -U admin -d postgres -c "ANALYZE;"

# 清理死行
docker exec postgres_master psql -U admin -d postgres -c "VACUUM;"

# 完全清理和分析
docker exec postgres_master psql -U admin -d postgres -c "VACUUM FULL ANALYZE;"
```

### 日志管理

```bash
# 查看最近日志
docker logs postgres_master --tail 100

# 实时查看日志
docker logs postgres_master -f

# 导出日志
docker logs postgres_master > postgres_$(date +%Y%m%d).log
```

---

## 🔐 安全建议

### 1. 修改默认密码

```bash
# 修改admin密码
docker exec postgres_master psql -U admin -d postgres -c "
ALTER USER admin WITH PASSWORD 'YourStrongPassword123!';
"

# 修改colormagic_user密码
docker exec postgres_master psql -U admin -d postgres -c "
ALTER USER colormagic_user WITH PASSWORD 'YourStrongPassword456!';
"

# 同步更新应用的.env文件
```

### 2. 限制远程访问

编辑 `docker-compose.vps.yml`，移除或限制端口映射：

```yaml
# 只允许内部容器访问（推荐）
# ports:
#   - "5432:5432"

# 或只监听本地
ports:
  - "127.0.0.1:5432:5432"
```

### 3. 定期更新

```bash
# 更新PostgreSQL镜像
docker compose pull
docker compose up -d

# 应用安全更新
apt update && apt upgrade -y
```

---

## 📞 技术支持

### 📚 相关文档

| 文档 | 说明 | 适用场景 |
|------|------|----------|
| `应用接入PostgreSQL总系统指南.md` | 完整的应用接入指南 | 新应用接入时必读 |
| `故障排查与问题解决指南.md` | 综合故障排查指南 | ⭐ 遇到任何问题时优先查看 |
| `VPS查看反馈表和注册表指南.md` | VPS端数据查看指南 | 查看反馈和用户数据 |
| `ColorMagic数据库结构详解.md` | ColorMagic 表结构详解 | 了解 ColorMagic 数据库设计 |
| `使用指南-完整版.md` | 完整使用指南 | 系统使用和维护 |
| `反馈数据查看指南.md` | 反馈数据管理 | unified_feedback 表操作 |

### 🔧 常用工具脚本

| 脚本 | 说明 | 用法 |
|------|------|------|
| `scripts/fix-permissions.sh` | 自动修复权限问题 | `./scripts/fix-permissions.sh site3_user` |
| `scripts/local-start.bat` | Windows 本地启动 | 双击运行或 `scripts\local-start.bat` |
| `scripts/local-verify.bat` | Windows 本地验证 | `scripts\local-verify.bat` |
| `scripts/local-start.sh` | Linux/Mac 本地启动 | `./scripts/local-start.sh` |
| `scripts/local-verify.sh` | Linux/Mac 本地验证 | `./scripts/local-verify.sh` |

### 获取帮助

1. 📖 查看相关文档（见上表）
2. 🔧 使用工具脚本快速诊断
3. 📋 查看日志：`docker logs postgres_master`
4. ✅ 运行验证：`./scripts/local-verify.sh` 或 `./scripts/vps-verify.sh`
5. 🐛 GitHub Issues: [提交问题](https://github.com/sicks0214/postgres-master-system/issues)

### 版本信息

```bash
# PostgreSQL版本
docker exec postgres_master psql -U admin -d postgres -c "SELECT version();"

# 系统统计
docker exec postgres_master psql -U admin -d postgres -c "SELECT get_system_stats();"
```

---

## 📝 更新日志

### v2.0 (2024-10-02)
- ✅ 重新设计表结构，完全适配ColorMagic应用
- ✅ 简化部署流程，支持本地测试
- ✅ 添加完整的验证脚本
- ✅ 支持20个站点扩展
- ✅ 添加系统统计函数
- ✅ 完善文档和故障排查指南

### v1.0 (2024-09-30)
- 初始版本

---

**部署愉快！🎉**

如有问题，请查阅 [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

