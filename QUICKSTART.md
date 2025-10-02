# PostgreSQL总系统 - 快速上手指南

## 🚀 5分钟快速开始

### 本地测试（Windows）

```cmd
# 1. 进入系统目录
cd postgres-master-system

# 2. 启动PostgreSQL
scripts\local-start.bat

# 3. 验证系统
scripts\local-verify.bat

# 完成！系统已就绪
```

### 本地测试（Linux/Mac）

```bash
# 1. 进入系统目录
cd postgres-master-system

# 2. 赋予执行权限
chmod +x scripts/*.sh

# 3. 启动PostgreSQL
./scripts/local-start.sh

# 4. 验证系统
./scripts/local-verify.sh

# 完成！系统已就绪
```

---

## 📦 VPS部署（3步完成）

### 步骤1：打包并上传

```bash
# 本地操作：打包系统
cd postgres-master-system
./scripts/export-to-vps.sh

# 上传到VPS
scp export-to-vps/postgres-master-system.tar.gz root@YOUR_VPS_IP:/tmp/
```

### 步骤2：VPS上解压

```bash
# SSH到VPS
ssh root@YOUR_VPS_IP

# 创建目录并解压
mkdir -p /docker/db_master
cd /docker/db_master
tar -xzf /tmp/postgres-master-system.tar.gz
```

### 步骤3：修改密码并启动

```bash
# 修改Site4密码
nano init-scripts/02_site4_colormagic.sql
# 将 ColorMagic_Local_Test_Pass 改为 ColorMagic_VPS_2024_Secure_Pass

# 修改其他站点密码
nano init-scripts/03_sites_and_functions.sql
# 将 site%s_test_pass 改为 site%s_pass

# 创建网络并启动
docker network create shared_net 2>/dev/null || true
docker compose -f docker-compose.vps.yml up -d

# 等待启动
sleep 15

# 查看日志
docker logs postgres_master --tail 30

# 验证
docker exec postgres_master psql -U admin -d postgres -c "SELECT get_system_stats();"
```

---

## 🔌 Site4 (ColorMagic) 应用接入

### 应用`.env`配置

```bash
# PostgreSQL连接
USE_DATABASE=true
DB_HOST=postgres_master
DB_PORT=5432
DB_NAME=postgres
DB_USER=colormagic_user
DB_PASSWORD=ColorMagic_VPS_2024_Secure_Pass
DB_SSL=false

# 站点标识
SITE_ID=colormagic
```

### 应用Docker配置

```yaml
# docker-compose.yml
services:
  site4:
    image: your-image
    networks:
      - shared_net
    environment:
      - USE_DATABASE=true
      - DB_HOST=postgres_master

networks:
  shared_net:
    external: true
```

### 代码中的表名映射

| 代码中表名 | PostgreSQL实际表名 |
|-----------|-------------------|
| `users` | `colormagic_users` |
| `user_sessions` | `colormagic_sessions` |
| `user_analysis_history` | `colormagic_analysis_history` |
| `user_favorite_palettes` | `colormagic_palettes` |
| `user_usage_stats` | `colormagic_usage_stats` |
| `analysis_history` | `colormagic_color_analysis` |
| `export_history` | `colormagic_export_history` |
| `unified_feedback` | `unified_feedback` (site_id='colormagic') |

---

## ✅ 验证检查清单

### PostgreSQL系统验证

```bash
# 1. 容器运行
docker ps | grep postgres_master

# 2. 数据库连接
docker exec postgres_master psql -U admin -d postgres -c "SELECT version();"

# 3. 系统统计
docker exec postgres_master psql -U admin -d postgres -c "SELECT get_system_stats();"

# 4. ColorMagic用户测试
docker exec postgres_master psql -U colormagic_user -d postgres -c "SELECT current_user;"

# 5. 表检查
docker exec postgres_master psql -U admin -d postgres -c "\dt colormagic_*"
```

### 应用连接验证

```bash
# 1. 网络连接
docker exec site4 ping -c 2 postgres_master

# 2. 端口测试
docker exec site4 nc -zv postgres_master 5432

# 3. 应用日志
docker logs site4 | grep -i database

# 4. 健康检查
curl http://localhost:3000/health
```

---

## 🆘 常见问题快速修复

### 问题1：容器启动失败

```bash
# 查看日志
docker logs postgres_master

# 检查端口冲突
docker compose -f docker-compose.vps.yml down
# 编辑docker-compose.vps.yml，修改端口为5433
docker compose -f docker-compose.vps.yml up -d
```

### 问题2：应用无法连接数据库

```bash
# 检查网络
docker network inspect shared_net

# 重新连接网络
docker network connect shared_net site4

# 测试连接
docker exec site4 ping postgres_master
```

### 问题3：密码认证失败

```bash
# 重置密码
docker exec postgres_master psql -U admin -d postgres -c "
ALTER USER colormagic_user WITH PASSWORD 'NewPassword';
"

# 更新应用.env文件
# DB_PASSWORD=NewPassword

# 重启应用容器
docker stop site4 && docker rm site4
docker compose up -d
```

### 问题4：表不存在

```bash
# 检查初始化日志
docker logs postgres_master | grep -i "初始化"

# 如果没有初始化，重新创建
docker compose down -v
docker compose -f docker-compose.vps.yml up -d
```

---

## 📚 更多信息

- **完整文档**: [README.md](README.md)
- **站点接入指南**: `docs/SITE4_INTEGRATION.md`
- **故障排查**: `docs/TROUBLESHOOTING.md`

---

## 🎯 关键命令速查

```bash
# 启动系统
docker compose -f docker-compose.vps.yml up -d

# 查看日志
docker logs postgres_master -f

# 进入数据库
docker exec -it postgres_master psql -U admin -d postgres

# 查看系统统计
docker exec postgres_master psql -U admin -d postgres -c "SELECT jsonb_pretty(get_system_stats()::jsonb);"

# 查看活跃站点
docker exec postgres_master psql -U admin -d postgres -c "SELECT * FROM get_active_sites();"

# 备份数据库
docker exec postgres_master pg_dumpall -U admin | gzip > backup_$(date +%Y%m%d).sql.gz

# 停止系统
docker compose -f docker-compose.vps.yml down
```

---

**准备好了吗？开始部署吧！** 🚀

