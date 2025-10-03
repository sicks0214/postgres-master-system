# VPS 端查看反馈表和注册表指南

> **适用环境**: VPS 生产环境  
> **容器名称**: postgres_master  
> **最后更新**: 2024-10-03

---

## 📋 目录

1. [快速开始](#快速开始)
2. [查看反馈表 (unified_feedback)](#查看反馈表-unified_feedback)
3. [查看注册表 (colormagic_users)](#查看注册表-colormagic_users)
4. [进入数据库交互模式](#进入数据库交互模式)
5. [导出数据](#导出数据)
6. [常用快捷脚本](#常用快捷脚本)

---

## 🚀 快速开始

### 前置条件

```bash
# 1. SSH 连接到 VPS
ssh root@YOUR_VPS_IP

# 2. 进入数据库目录
cd /docker/db_master

# 3. 验证容器运行
docker ps | grep postgres_master
```

---

## 📊 查看反馈表 (unified_feedback)

### 1. 使用自动化脚本（推荐）⭐

```bash
# 进入数据库目录
cd /docker/db_master

# 查看所有反馈（最新20条）
./scripts/view-feedbacks.sh

# 查看 ColorMagic 站点的反馈
./scripts/view-feedbacks.sh colormagic

# 查看 Site3 的反馈
./scripts/view-feedbacks.sh site3

# 查看统计信息
./scripts/view-feedbacks.sh stats

# 查看待处理的反馈
./scripts/view-feedbacks.sh pending

# 查看更多反馈（指定数量）
./scripts/view-feedbacks.sh colormagic 50
```

---

### 2. 查看所有站点的反馈

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    id,
    site_id,
    LEFT(content, 50) as content_preview,
    rating,
    status,
    created_at
FROM unified_feedback 
ORDER BY created_at DESC 
LIMIT 20;
"
```

**预期输出：**
```
 id | site_id    | content_preview                    | rating | status  | created_at
----+------------+------------------------------------+--------+---------+-------------------
  5 | colormagic | 测试反馈内容...                      |      5 | pending | 2024-10-03 10:30
  4 | site3      | 用户反馈...                         |      4 | reviewed| 2024-10-03 09:15
```

---

### 3. 按站点查看反馈

#### ColorMagic 站点反馈

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    id,
    LEFT(content, 60) as content,
    contact,
    rating,
    status,
    created_at
FROM unified_feedback 
WHERE site_id = 'colormagic' 
ORDER BY created_at DESC 
LIMIT 20;
"
```

#### Site3 反馈

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT * FROM unified_feedback 
WHERE site_id = 'site3' 
ORDER BY created_at DESC;
"
```

---

### 4. 按状态查看反馈

#### 待处理的反馈（重要）⚠️

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    id,
    site_id,
    LEFT(content, 40) as content,
    rating,
    contact,
    created_at
FROM unified_feedback 
WHERE status = 'pending' 
ORDER BY created_at DESC;
"
```

#### 已解决的反馈

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    id,
    site_id,
    LEFT(content, 40) as content,
    status,
    created_at
FROM unified_feedback 
WHERE status = 'resolved' 
ORDER BY created_at DESC 
LIMIT 10;
"
```

---

### 5. 按评分查看反馈

#### 高分反馈（4-5分）

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    site_id,
    LEFT(content, 50) as content,
    rating,
    contact,
    created_at
FROM unified_feedback 
WHERE rating >= 4 
ORDER BY rating DESC, created_at DESC;
"
```

#### 低分反馈（1-2分）- 需要重点关注 ⚠️

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    site_id,
    LEFT(content, 50) as content,
    rating,
    contact,
    status,
    created_at
FROM unified_feedback 
WHERE rating <= 2 
ORDER BY created_at DESC;
"
```

---

### 6. 反馈统计查询

#### 各站点反馈统计

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    site_id,
    COUNT(*) as total_feedbacks,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_count,
    COUNT(CASE WHEN status = 'resolved' THEN 1 END) as resolved_count,
    ROUND(AVG(rating), 2) as avg_rating,
    MAX(created_at) as last_feedback_time
FROM unified_feedback 
WHERE site_id != 'system'
GROUP BY site_id
ORDER BY total_feedbacks DESC;
"
```

#### 最近7天的反馈趋势

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    DATE(created_at) as date,
    site_id,
    COUNT(*) as count,
    ROUND(AVG(rating), 2) as avg_rating
FROM unified_feedback 
WHERE created_at > NOW() - INTERVAL '7 days'
  AND site_id != 'system'
GROUP BY DATE(created_at), site_id
ORDER BY date DESC, site_id;
"
```

---

### 7. 搜索反馈内容

```bash
# 搜索包含关键词的反馈
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    id,
    site_id,
    content,
    rating,
    created_at
FROM unified_feedback 
WHERE content LIKE '%关键词%' 
   OR content LIKE '%bug%'
   OR content LIKE '%问题%'
ORDER BY created_at DESC;
"
```

---

## 👥 查看注册表 (colormagic_users)

### 1. 查看所有用户

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    id,
    email,
    username,
    display_name,
    status,
    email_verified,
    subscription_type,
    login_count,
    last_login_at,
    created_at
FROM colormagic_users 
ORDER BY created_at DESC;
"
```

---

### 2. 查看最近注册的用户（前20个）

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    username,
    email,
    display_name,
    status,
    email_verified,
    created_at
FROM colormagic_users 
ORDER BY created_at DESC 
LIMIT 20;
"
```

---

### 3. 查看活跃用户（最近登录）

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    username,
    email,
    login_count,
    last_login_at,
    status
FROM colormagic_users 
WHERE last_login_at IS NOT NULL
ORDER BY last_login_at DESC 
LIMIT 20;
"
```

---

### 4. 用户统计分析

#### 按状态统计

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    status,
    COUNT(*) as user_count,
    COUNT(CASE WHEN email_verified = true THEN 1 END) as verified_count
FROM colormagic_users 
GROUP BY status;
"
```

**预期输出：**
```
 status    | user_count | verified_count
-----------+------------+---------------
 active    |         45 |            42
 suspended |          2 |             1
 deleted   |          3 |             0
```

#### 按订阅类型统计

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    subscription_type,
    COUNT(*) as user_count,
    ROUND(AVG(login_count), 2) as avg_logins
FROM colormagic_users 
WHERE status = 'active'
GROUP BY subscription_type
ORDER BY user_count DESC;
"
```

---

### 5. 查看用户详细信息

#### 查询特定用户

```bash
# 按用户名查询
docker exec postgres_master psql -U admin -d postgres -c "
SELECT * FROM colormagic_users 
WHERE username = 'testuser';
"

# 按邮箱查询
docker exec postgres_master psql -U admin -d postgres -c "
SELECT * FROM colormagic_users 
WHERE email = 'test@example.com';
"

# 按 ID 查询
docker exec postgres_master psql -U admin -d postgres -c "
SELECT * FROM colormagic_users 
WHERE id = 'your-uuid-here';
"
```

---

### 6. 用户登录分析

#### 最活跃用户（按登录次数）

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    username,
    email,
    login_count,
    last_login_at,
    created_at
FROM colormagic_users 
WHERE status = 'active'
ORDER BY login_count DESC 
LIMIT 10;
"
```

#### 今天登录的用户

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    username,
    email,
    login_count,
    last_login_at
FROM colormagic_users 
WHERE last_login_at::DATE = CURRENT_DATE
ORDER BY last_login_at DESC;
"
```

---

### 7. 新用户增长趋势

#### 最近7天的注册趋势

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    DATE(created_at) as date,
    COUNT(*) as new_users,
    COUNT(CASE WHEN email_verified = true THEN 1 END) as verified_users
FROM colormagic_users 
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;
"
```

---

## 🔄 联合查询

### 用户及其反馈统计

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    u.username,
    u.email,
    u.subscription_type,
    COUNT(f.id) as feedback_count,
    ROUND(AVG(f.rating), 2) as avg_feedback_rating,
    u.created_at as user_since
FROM colormagic_users u
LEFT JOIN unified_feedback f ON f.user_id = u.id AND f.site_id = 'colormagic'
WHERE u.status = 'active'
GROUP BY u.id, u.username, u.email, u.subscription_type, u.created_at
ORDER BY feedback_count DESC
LIMIT 20;
"
```

---

### 用户使用统计（完整视图）

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    u.username,
    u.email,
    u.login_count,
    COUNT(DISTINCT a.id) as analysis_count,
    COUNT(DISTINCT p.id) as palette_count,
    COUNT(DISTINCT f.id) as feedback_count
FROM colormagic_users u
LEFT JOIN colormagic_color_analysis a ON a.user_id = u.id
LEFT JOIN colormagic_palettes p ON p.user_id = u.id
LEFT JOIN unified_feedback f ON f.user_id = u.id
WHERE u.status = 'active'
GROUP BY u.id, u.username, u.email, u.login_count
ORDER BY u.login_count DESC
LIMIT 20;
"
```

---

## 💻 进入数据库交互模式

### 使用管理员用户（完全权限）

```bash
docker exec -it postgres_master psql -U admin -d postgres
```

### 使用 ColorMagic 用户（受限权限）

```bash
docker exec -it postgres_master psql -U colormagic_user -d postgres
```

### 进入后常用命令

```sql
-- 列出所有表
\dt

-- 列出 ColorMagic 的表
\dt colormagic_*

-- 查看表结构
\d colormagic_users
\d unified_feedback

-- 查看所有用户
\du

-- 查看当前用户
SELECT current_user;

-- 查看数据库大小
SELECT pg_size_pretty(pg_database_size('postgres'));

-- 执行查询（示例）
SELECT COUNT(*) FROM colormagic_users;
SELECT COUNT(*) FROM unified_feedback WHERE site_id = 'colormagic';

-- 退出
\q
```

---

## 📤 导出数据

### 导出反馈表为 CSV

```bash
# 导出所有反馈
docker exec postgres_master psql -U admin -d postgres -c "
COPY (
    SELECT 
        id, site_id, content, category, rating, 
        status, contact, created_at
    FROM unified_feedback 
    ORDER BY created_at DESC
) TO STDOUT WITH CSV HEADER
" > /tmp/feedbacks_all.csv

# 导出 ColorMagic 反馈
docker exec postgres_master psql -U admin -d postgres -c "
COPY (
    SELECT * FROM unified_feedback 
    WHERE site_id = 'colormagic' 
    ORDER BY created_at DESC
) TO STDOUT WITH CSV HEADER
" > /tmp/feedbacks_colormagic.csv
```

---

### 导出用户表为 CSV

```bash
# 导出所有用户
docker exec postgres_master psql -U admin -d postgres -c "
COPY (
    SELECT 
        id, email, username, display_name, status, 
        email_verified, subscription_type, login_count, 
        created_at, last_login_at
    FROM colormagic_users 
    ORDER BY created_at DESC
) TO STDOUT WITH CSV HEADER
" > /tmp/colormagic_users.csv

# 导出活跃用户
docker exec postgres_master psql -U admin -d postgres -c "
COPY (
    SELECT * FROM colormagic_users 
    WHERE status = 'active' 
    ORDER BY created_at DESC
) TO STDOUT WITH CSV HEADER
" > /tmp/colormagic_active_users.csv
```

---

### 导出为 JSON

```bash
# 导出反馈为 JSON
docker exec postgres_master psql -U admin -d postgres -t -c "
SELECT json_agg(row_to_json(t))
FROM (
    SELECT * FROM unified_feedback 
    WHERE site_id = 'colormagic' 
    ORDER BY created_at DESC 
    LIMIT 100
) t
" > /tmp/feedbacks_colormagic.json

# 导出用户为 JSON
docker exec postgres_master psql -U admin -d postgres -t -c "
SELECT json_agg(row_to_json(t))
FROM (
    SELECT id, email, username, status, created_at 
    FROM colormagic_users 
    ORDER BY created_at DESC
) t
" > /tmp/colormagic_users.json
```

---

### 下载导出的文件到本地

```bash
# 在本地机器执行（非 VPS）
scp root@YOUR_VPS_IP:/tmp/feedbacks_all.csv ./
scp root@YOUR_VPS_IP:/tmp/colormagic_users.csv ./
scp root@YOUR_VPS_IP:/tmp/feedbacks_colormagic.json ./
```

---

## 🛠️ 常用快捷脚本

### 创建快速查看脚本

在 VPS 上创建一个便捷的查看脚本：

```bash
# 创建脚本
cat > /docker/db_master/quick-view.sh << 'EOF'
#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "PostgreSQL 总系统 - 快速数据查看"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 1. 系统统计
echo -e "${GREEN}📊 系统统计:${NC}"
docker exec postgres_master psql -U admin -d postgres -c "SELECT jsonb_pretty(get_system_stats()::jsonb);"

echo ""
echo "=========================================="

# 2. 反馈表统计
echo -e "${GREEN}📝 反馈表统计（按站点）:${NC}"
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    site_id,
    COUNT(*) as total,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending,
    COUNT(CASE WHEN status = 'resolved' THEN 1 END) as resolved,
    ROUND(AVG(rating), 2) as avg_rating
FROM unified_feedback 
WHERE site_id != 'system'
GROUP BY site_id
ORDER BY total DESC;
"

echo ""
echo "=========================================="

# 3. ColorMagic 用户统计
echo -e "${GREEN}👥 ColorMagic 用户统计:${NC}"
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    status,
    subscription_type,
    COUNT(*) as count
FROM colormagic_users 
GROUP BY status, subscription_type
ORDER BY count DESC;
"

echo ""
echo "=========================================="

# 4. 最新反馈（5条）
echo -e "${GREEN}📬 最新反馈（前5条）:${NC}"
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    id,
    site_id,
    LEFT(content, 40) as content,
    rating,
    status,
    created_at
FROM unified_feedback 
ORDER BY created_at DESC 
LIMIT 5;
"

echo ""
echo "=========================================="

# 5. 最新注册用户（5个）
echo -e "${GREEN}🆕 最新注册用户（前5个）:${NC}"
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    username,
    email,
    status,
    created_at
FROM colormagic_users 
ORDER BY created_at DESC 
LIMIT 5;
"

echo ""
echo "=========================================="

# 6. 今日活跃
echo -e "${GREEN}📅 今日活动:${NC}"
echo "今日反馈数:"
docker exec postgres_master psql -U admin -d postgres -t -c "
SELECT COUNT(*) FROM unified_feedback 
WHERE created_at::DATE = CURRENT_DATE;
"

echo "今日新用户:"
docker exec postgres_master psql -U admin -d postgres -t -c "
SELECT COUNT(*) FROM colormagic_users 
WHERE created_at::DATE = CURRENT_DATE;
"

echo ""
echo "=========================================="
echo ""
EOF

# 赋予执行权限
chmod +x /docker/db_master/quick-view.sh
```

### 使用快速查看脚本

```bash
# 在 VPS 上执行
cd /docker/db_master
./quick-view.sh
```

---

### 创建待处理反馈提醒脚本

```bash
cat > /docker/db_master/check-pending.sh << 'EOF'
#!/bin/bash

PENDING=$(docker exec postgres_master psql -U admin -d postgres -t -c "
SELECT COUNT(*) FROM unified_feedback WHERE status = 'pending';
" | tr -d ' ')

echo "=========================================="
echo "待处理反馈检查"
echo "=========================================="
echo ""

if [ "$PENDING" -gt "0" ]; then
    echo "⚠️  当前有 $PENDING 条待处理的反馈"
    echo ""
    echo "详细列表："
    docker exec postgres_master psql -U admin -d postgres -c "
    SELECT 
        id,
        site_id,
        LEFT(content, 40) as content,
        rating,
        created_at
    FROM unified_feedback 
    WHERE status = 'pending' 
    ORDER BY created_at DESC;
    "
else
    echo "✅ 没有待处理的反馈"
fi

echo ""
EOF

chmod +x /docker/db_master/check-pending.sh
```

---

## 📊 系统监控命令

### 查看系统整体状态

```bash
# 完整系统统计
docker exec postgres_master psql -U admin -d postgres -c "SELECT jsonb_pretty(get_system_stats()::jsonb);"

# ColorMagic 详细统计
docker exec postgres_master psql -U admin -d postgres -c "SELECT jsonb_pretty(get_colormagic_system_stats()::jsonb);"

# 活跃站点列表
docker exec postgres_master psql -U admin -d postgres -c "SELECT * FROM get_active_sites();"
```

---

### 查看数据库连接数

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    usename,
    COUNT(*) as connections,
    state
FROM pg_stat_activity 
WHERE state IS NOT NULL
GROUP BY usename, state
ORDER BY connections DESC;
"
```

---

### 查看数据库大小

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    pg_database.datname,
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;
"
```

---

### 查看表大小

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size('public.'||tablename)) AS size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size('public.'||tablename) DESC
LIMIT 10;
"
```

---

## 🔍 高级查询示例

### 用户留存分析（最近30天注册用户的登录情况）

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    DATE(created_at) as signup_date,
    COUNT(*) as new_users,
    COUNT(CASE WHEN login_count > 1 THEN 1 END) as returned_users,
    ROUND(COUNT(CASE WHEN login_count > 1 THEN 1 END)::NUMERIC / COUNT(*) * 100, 2) as retention_rate
FROM colormagic_users 
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY signup_date DESC;
"
```

---

### 反馈质量分析

```bash
docker exec postgres_master psql -U admin -d postgres -c "
SELECT 
    site_id,
    ROUND(AVG(rating), 2) as avg_rating,
    COUNT(*) as total_feedbacks,
    COUNT(CASE WHEN rating >= 4 THEN 1 END) as positive,
    COUNT(CASE WHEN rating <= 2 THEN 1 END) as negative,
    ROUND(COUNT(CASE WHEN rating >= 4 THEN 1 END)::NUMERIC / COUNT(*) * 100, 2) as satisfaction_rate
FROM unified_feedback 
WHERE site_id != 'system'
GROUP BY site_id
ORDER BY avg_rating DESC;
"
```

---

## 📚 相关文档

- **完整系统文档**: `README.md`
- **反馈数据详细指南**: `反馈数据查看指南.md`
- **表结构说明**: `ColorMagic数据库结构详解.md`
- **应用接入指南**: `应用接入PostgreSQL总系统指南.md`

---

## 💡 使用技巧

### 1. 保存常用命令为别名

在 VPS 的 `~/.bashrc` 中添加：

```bash
# PostgreSQL 查询别名
alias pgm='docker exec postgres_master psql -U admin -d postgres'
alias pgc='docker exec postgres_master psql -U colormagic_user -d postgres'
alias pg-stats='docker exec postgres_master psql -U admin -d postgres -c "SELECT jsonb_pretty(get_system_stats()::jsonb);"'
alias pg-feedbacks='cd /docker/db_master && ./scripts/view-feedbacks.sh'
alias pg-quick='cd /docker/db_master && ./quick-view.sh'
```

然后执行：`source ~/.bashrc`

使用示例：
```bash
pgm -c "SELECT COUNT(*) FROM colormagic_users;"
pg-stats
pg-feedbacks colormagic
```

---

### 2. 定时任务监控

```bash
# 编辑 crontab
crontab -e

# 添加定时任务（每天上午9点检查待处理反馈）
0 9 * * * /docker/db_master/check-pending.sh >> /var/log/pg-pending-check.log 2>&1
```

---

## ⚠️ 注意事项

1. **权限问题**: 如果遇到 `permission denied`，参考 `权限问题快速解决方案.md`
2. **性能影响**: 大量数据查询时建议使用 `LIMIT` 限制结果数量
3. **数据备份**: 导出重要数据前建议先备份数据库
4. **安全性**: 不要将导出的 CSV/JSON 文件包含敏感信息的发送给他人

---

## 📞 获取帮助

如遇到问题：

1. 查看日志：`docker logs postgres_master --tail 100`
2. 参考完整文档：`README.md`
3. 使用验证脚本：`./scripts/local-verify.sh`（本地）

---

**版本**: v1.0  
**创建日期**: 2024-10-03  
**适用系统**: PostgreSQL 总系统 v2.0+  
**环境**: VPS 生产环境

---

**祝使用愉快！** 🚀

