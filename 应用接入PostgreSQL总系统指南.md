# 应用接入 PostgreSQL 总系统指南

> **适用于所有需要连接到 PostgreSQL 总系统的应用程序**  
> **系统版本**: v2.0  
> **最后更新**: 2024-10-02

---

## 📋 目录

1. [系统概述](#系统概述)
2. [接入准备](#接入准备)
3. [环境变量配置](#环境变量配置)
4. [Docker 网络配置](#docker-网络配置)
5. [表名映射规则](#表名映射规则)
6. [连接测试](#连接测试)
7. [完整接入示例](#完整接入示例)
8. [常见问题排查](#常见问题排查)

---

## 系统概述

### PostgreSQL 总系统架构

```
PostgreSQL 总系统 (postgres_master)
├── 数据库: postgres
├── 端口: 5432
├── 网络: shared_net
├── 支持站点: 1-20 个
└── 当前站点:
    └── Site4 (ColorMagic) - 已配置
```

### 核心特性

- ✅ **多站点共享**: 单个 PostgreSQL 实例支持 20 个站点
- ✅ **权限隔离**: 每个站点独立用户，互不干扰
- ✅ **表前缀系统**: 避免表名冲突（colormagic_*, site1_*, site2_*...）
- ✅ **统一反馈**: 所有站点共享 `unified_feedback` 表（通过 site_id 区分）

---

## 接入准备

### 1. 确认系统已部署

```bash
# 在 VPS 上检查 PostgreSQL 是否运行
docker ps | grep postgres_master

# 应该看到：
# CONTAINER ID   IMAGE                 STATUS          NAMES
# abc123def      postgres:15-alpine    Up 10 minutes   postgres_master
```

### 2. 确认你的站点信息

| 站点 | 数据库用户 | 默认密码（需修改） | 表前缀 | site_id |
|------|-----------|-------------------|--------|---------|
| Site4 (ColorMagic) | colormagic_user | ColorMagic_VPS_2024_Secure_Pass | colormagic_ | colormagic |
| Site1 | site1_user | site1_prod_pass_2024 | site1_ | site1 |
| Site2 | site2_user | site2_prod_pass_2024 | site2_ | site2 |
| ... | ... | ... | ... | ... |
| Site20 | site20_user | site20_prod_pass_2024 | site20_ | site20 |

### 3. 确认 shared_net 网络存在

```bash
# 检查网络
docker network ls | grep shared_net

# 如果不存在，创建它
docker network create shared_net
```

---

## 环境变量配置

### 方式 A：使用 .env 文件（推荐）

在你的应用目录创建或编辑 `.env` 文件：

```bash
# ============================================
# PostgreSQL 总系统连接配置
# ============================================

# 数据库连接信息
DB_HOST=postgres_master          # Docker 网络别名（不要改）
DB_PORT=5432                     # PostgreSQL 端口（不要改）
DB_NAME=postgres                 # 数据库名称（不要改）
DB_USER=colormagic_user          # 你的站点用户（根据站点修改）
DB_PASSWORD=ColorMagic_VPS_2024_Secure_Pass  # 你的站点密码（必须修改）

# 数据库连接池配置（可选）
DB_MAX_CONNECTIONS=20            # 最大连接数
DB_IDLE_TIMEOUT=30000           # 空闲超时（毫秒）
DB_CONNECTION_TIMEOUT=2000      # 连接超时（毫秒）

# SSL 配置（本地开发关闭，生产环境建议开启）
DB_SSL=false

# 站点标识（用于 unified_feedback 表）
SITE_ID=colormagic               # 你的站点 ID（根据站点修改）

# ============================================
# 其他配置（根据应用需要）
# ============================================
NODE_ENV=production
PORT=3000
```

### 方式 B：直接在 docker-compose.yml 中配置

```yaml
version: '3.8'

services:
  your-app:
    image: your-app:latest
    container_name: your-app
    environment:
      - DB_HOST=postgres_master
      - DB_PORT=5432
      - DB_NAME=postgres
      - DB_USER=colormagic_user
      - DB_PASSWORD=ColorMagic_VPS_2024_Secure_Pass
      - DB_SSL=false
      - SITE_ID=colormagic
      - NODE_ENV=production
    networks:
      - shared_net
    restart: unless-stopped

networks:
  shared_net:
    external: true
```

### 不同站点的配置示例

#### Site1 配置
```env
DB_USER=site1_user
DB_PASSWORD=site1_prod_pass_2024
SITE_ID=site1
```

#### Site2 配置
```env
DB_USER=site2_user
DB_PASSWORD=site2_prod_pass_2024
SITE_ID=site2
```

---

## Docker 网络配置

### 方式 A：使用 docker run（手动部署）

```bash
# 启动容器时连接到 shared_net 网络
docker run -d \
  --name your-app \
  --network shared_net \
  --env-file .env \
  --restart unless-stopped \
  your-image:latest
```

### 方式 B：使用 docker-compose.yml（推荐）

```yaml
version: '3.8'

services:
  your-app:
    image: your-app:latest
    container_name: your-app
    networks:
      - shared_net        # 连接到 shared_net 网络
      - webproxy          # 如果需要 Nginx 代理
    env_file:
      - .env
    restart: unless-stopped

networks:
  shared_net:
    external: true        # 使用外部网络（必须）
  webproxy:
    external: true        # 如果使用 Nginx
```

### 方式 C：为已运行的容器添加网络

```bash
# 如果容器已经在运行，可以动态连接网络
docker network connect shared_net your-app

# 验证网络连接
docker inspect your-app | grep -A 10 "Networks"
```

---

## 表名映射规则

### 重要：必须使用带前缀的表名！

PostgreSQL 总系统使用 **表前缀** 来区分不同站点的表。你的代码中必须使用完整的表名。

### Site4 (ColorMagic) 表名映射

| 功能 | 代码中可能的表名 | PostgreSQL 实际表名 | 说明 |
|------|----------------|-------------------|------|
| 用户表 | `users` | `colormagic_users` | 用户注册/登录 |
| 会话表 | `sessions` 或 `user_sessions` | `colormagic_sessions` | JWT token 管理 |
| 用户分析历史 | `user_analysis_history` | `colormagic_analysis_history` | 登录用户的分析记录 |
| 收藏调色板 | `favorite_palettes` 或 `palettes` | `colormagic_palettes` | 用户保存的调色板 |
| 使用统计 | `usage_stats` | `colormagic_usage_stats` | 按日统计 |
| 颜色分析记录 | `analysis_history` 或 `color_analysis` | `colormagic_color_analysis` | 所有分析记录（含匿名） |
| 导出历史 | `export_history` | `colormagic_export_history` | 导出操作记录 |
| 反馈表 | `feedback` | `unified_feedback` | 共享表，使用 `site_id='colormagic'` |

### 代码修改示例

#### ❌ 错误写法（旧代码）

```javascript
// 错误：使用不带前缀的表名
const query = 'SELECT * FROM users WHERE email = $1';
const result = await db.query(query, [email]);
```

#### ✅ 正确写法（新代码）

```javascript
// 正确：使用带前缀的表名
const query = 'SELECT * FROM colormagic_users WHERE email = $1';
const result = await db.query(query, [email]);
```

#### 💡 推荐写法（使用配置）

```javascript
// config/database.js
const TABLE_PREFIX = process.env.TABLE_PREFIX || 'colormagic_';

const TABLES = {
  USERS: `${TABLE_PREFIX}users`,
  SESSIONS: `${TABLE_PREFIX}sessions`,
  ANALYSIS_HISTORY: `${TABLE_PREFIX}analysis_history`,
  PALETTES: `${TABLE_PREFIX}palettes`,
  USAGE_STATS: `${TABLE_PREFIX}usage_stats`,
  COLOR_ANALYSIS: `${TABLE_PREFIX}color_analysis`,
  EXPORT_HISTORY: `${TABLE_PREFIX}export_history`,
  FEEDBACK: 'unified_feedback'  // 共享表不需要前缀
};

module.exports = { TABLES };
```

```javascript
// 使用表名常量
const { TABLES } = require('./config/database');

const query = `SELECT * FROM ${TABLES.USERS} WHERE email = $1`;
const result = await db.query(query, [email]);
```

### 反馈表特殊处理

反馈表是所有站点共享的，使用 `site_id` 字段区分：

```javascript
// 插入反馈时必须指定 site_id
const insertFeedback = async (content, category, rating) => {
  const query = `
    INSERT INTO unified_feedback (site_id, content, category, rating)
    VALUES ($1, $2, $3, $4)
    RETURNING id, created_at
  `;
  
  const siteId = process.env.SITE_ID || 'colormagic';
  return await db.query(query, [siteId, content, category, rating]);
};

// 查询反馈时必须过滤 site_id
const getFeedbacks = async () => {
  const query = `
    SELECT id, content, category, rating, created_at
    FROM unified_feedback
    WHERE site_id = $1
    ORDER BY created_at DESC
    LIMIT 50
  `;
  
  const siteId = process.env.SITE_ID || 'colormagic';
  return await db.query(query, [siteId]);
};
```

---

## 连接测试

### 1. 基础连接测试

在你的应用中添加数据库连接测试代码：

#### Node.js (pg) 示例

```javascript
const { Pool } = require('pg');

// 创建连接池
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  max: parseInt(process.env.DB_MAX_CONNECTIONS) || 20,
  idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT) || 30000,
  connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT) || 2000,
});

// 测试连接
const testConnection = async () => {
  try {
    const client = await pool.connect();
    const result = await client.query('SELECT version()');
    console.log('✅ 数据库连接成功');
    console.log('PostgreSQL 版本:', result.rows[0].version);
    client.release();
    return true;
  } catch (error) {
    console.error('❌ 数据库连接失败:', error.message);
    return false;
  }
};

// 测试表访问权限
const testTableAccess = async () => {
  try {
    const client = await pool.connect();
    
    // 测试读取 colormagic_users 表
    const result = await client.query('SELECT COUNT(*) FROM colormagic_users');
    console.log('✅ 表访问权限正常，用户数:', result.rows[0].count);
    
    client.release();
    return true;
  } catch (error) {
    console.error('❌ 表访问权限错误:', error.message);
    return false;
  }
};

module.exports = { pool, testConnection, testTableAccess };
```

#### Python (psycopg2) 示例

```python
import os
import psycopg2
from psycopg2 import pool

# 创建连接池
db_pool = psycopg2.pool.SimpleConnectionPool(
    1,  # 最小连接数
    int(os.getenv('DB_MAX_CONNECTIONS', 20)),  # 最大连接数
    host=os.getenv('DB_HOST'),
    port=os.getenv('DB_PORT'),
    database=os.getenv('DB_NAME'),
    user=os.getenv('DB_USER'),
    password=os.getenv('DB_PASSWORD')
)

def test_connection():
    try:
        conn = db_pool.getconn()
        cursor = conn.cursor()
        cursor.execute('SELECT version()')
        version = cursor.fetchone()[0]
        print(f'✅ 数据库连接成功')
        print(f'PostgreSQL 版本: {version}')
        cursor.close()
        db_pool.putconn(conn)
        return True
    except Exception as e:
        print(f'❌ 数据库连接失败: {e}')
        return False

def test_table_access():
    try:
        conn = db_pool.getconn()
        cursor = conn.cursor()
        cursor.execute('SELECT COUNT(*) FROM colormagic_users')
        count = cursor.fetchone()[0]
        print(f'✅ 表访问权限正常，用户数: {count}')
        cursor.close()
        db_pool.putconn(conn)
        return True
    except Exception as e:
        print(f'❌ 表访问权限错误: {e}')
        return False
```

### 2. VPS 上的容器级测试

```bash
# 1. 测试 DNS 解析
docker exec your-app ping -c 2 postgres_master
# 应该能 ping 通

# 2. 测试端口连接
docker exec your-app nc -zv postgres_master 5432
# 应该显示：Connection to postgres_master 5432 port [tcp/postgresql] succeeded!

# 3. 测试数据库连接（从容器内部）
docker exec your-app psql -h postgres_master -U colormagic_user -d postgres -c "SELECT current_user;"
# 应该返回：colormagic_user

# 4. 查看应用日志
docker logs your-app --tail 50
# 查找 "数据库连接成功" 或类似的日志
```

---

## 完整接入示例

### 示例：Site4 (ColorMagic) 接入流程

#### 步骤 1: 准备 .env 文件

```bash
# 在 VPS 上操作
cd /docker/site4/backend
nano .env
```

```env
# .env 文件内容
USE_DATABASE=true
DB_HOST=postgres_master
DB_PORT=5432
DB_NAME=postgres
DB_USER=colormagic_user
DB_PASSWORD=ColorMagic_VPS_2024_Secure_Pass
DB_SSL=false
DB_MAX_CONNECTIONS=20
SITE_ID=colormagic

# 其他应用配置
NODE_ENV=production
PORT=3000
JWT_SECRET=your-super-secret-jwt-key
ALLOWED_ORIGINS=https://imagecolorpicker.cc,https://www.imagecolorpicker.cc
```

#### 步骤 2: 修改 docker-compose.yml（如果使用）

```yaml
version: '3.8'

services:
  site4:
    build:
      context: ./backend
      dockerfile: Dockerfile.simple
    container_name: site4
    networks:
      - shared_net    # 连接数据库网络
      - webproxy      # Nginx 代理网络
    env_file:
      - backend/.env
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  shared_net:
    external: true
  webproxy:
    external: true
```

#### 步骤 3: 修改代码中的表名

```javascript
// backend/src/config/database.js
const TABLE_PREFIX = 'colormagic_';

module.exports = {
  TABLES: {
    USERS: `${TABLE_PREFIX}users`,
    SESSIONS: `${TABLE_PREFIX}sessions`,
    ANALYSIS_HISTORY: `${TABLE_PREFIX}analysis_history`,
    PALETTES: `${TABLE_PREFIX}palettes`,
    USAGE_STATS: `${TABLE_PREFIX}usage_stats`,
    COLOR_ANALYSIS: `${TABLE_PREFIX}color_analysis`,
    EXPORT_HISTORY: `${TABLE_PREFIX}export_history`,
    FEEDBACK: 'unified_feedback'
  }
};
```

```javascript
// backend/src/index.js
const { TABLES } = require('./config/database');

// 使用新表名
app.get('/api/users/:id', async (req, res) => {
  const query = `SELECT * FROM ${TABLES.USERS} WHERE id = $1`;
  const result = await db.query(query, [req.params.id]);
  res.json(result.rows[0]);
});
```

#### 步骤 4: 部署应用

```bash
# 方式 A: 使用 docker-compose
cd /docker/site4
docker compose down
docker compose build --no-cache
docker compose up -d

# 方式 B: 使用 docker run
cd /docker/site4
docker build -f backend/Dockerfile.simple -t site4:latest ./backend
docker stop site4 && docker rm site4
docker run -d \
  --name site4 \
  --network webproxy \
  --env-file backend/.env \
  --restart unless-stopped \
  site4:latest

# 连接到数据库网络
docker network connect shared_net site4
```

#### 步骤 5: 验证连接

```bash
# 等待启动
sleep 10

# 查看日志
docker logs site4 --tail 30

# 测试 DNS
docker exec site4 ping -c 2 postgres_master

# 测试端口
docker exec site4 nc -zv postgres_master 5432

# 测试健康检查
curl http://localhost:3000/health

# 测试 API（如果有数据库相关接口）
curl http://localhost:3000/api/users
```

---

## 常见问题排查

### 问题 1: 无法连接到 postgres_master

**症状**：
```
Error: getaddrinfo ENOTFOUND postgres_master
```

**原因**：应用容器不在 `shared_net` 网络中

**解决**：
```bash
# 检查网络
docker network inspect shared_net | grep -A 5 your-app

# 如果没有，连接网络
docker network connect shared_net your-app

# 重启应用
docker restart your-app
```

---

### 问题 2: 密码认证失败

**症状**：
```
Error: password authentication failed for user "colormagic_user"
```

**原因**：.env 文件中的密码不正确

**解决**：
```bash
# 检查 .env 密码
cat /docker/your-app/.env | grep DB_PASSWORD

# 检查 PostgreSQL 中的正确密码（在部署时设置的）
# 应该是：ColorMagic_VPS_2024_Secure_Pass（Site4）
# 或：site1_prod_pass_2024（Site1）

# 更新 .env 文件
nano /docker/your-app/.env
# 修改 DB_PASSWORD=正确的密码

# 重启应用
docker restart your-app
```

---

### 问题 3: 表不存在错误

**症状**：
```
Error: relation "users" does not exist
```

**原因**：代码中使用了不带前缀的表名

**解决**：
```javascript
// 错误代码
const query = 'SELECT * FROM users';  // ❌

// 修改为
const query = 'SELECT * FROM colormagic_users';  // ✅

// 或使用配置
const { TABLES } = require('./config/database');
const query = `SELECT * FROM ${TABLES.USERS}`;  // ✅
```

---

### 问题 4: 权限拒绝错误

**症状**：
```
Error: permission denied for table colormagic_users
或
ERROR: permission denied for table site3__users
```

**原因**：使用的数据库用户没有权限

**解决方案（已验证有效）**：

#### 方法 1: 快速解决（推荐）⭐

```bash
# 直接授予所有表和序列的权限（最简单有效）
docker exec postgres_master psql -U admin -d postgres -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO site3_user;"

docker exec postgres_master psql -U admin -d postgres -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO site3_user;"

# 测试权限
docker exec postgres_master psql -U site3_user -d postgres -c "SELECT COUNT(*) FROM site3__users;"
# 应该返回：count (数字)
```

#### 方法 2: 针对特定站点用户

```bash
# 替换 SITE_USER 为你的站点用户（如 site3_user, colormagic_user 等）
SITE_USER="site3_user"

# 授予权限
docker exec postgres_master psql -U admin -d postgres -c "
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $SITE_USER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $SITE_USER;
"

# 验证权限
docker exec postgres_master psql -U admin -d postgres -c "
SELECT DISTINCT grantee, table_name 
FROM information_schema.table_privileges 
WHERE grantee = '$SITE_USER' 
ORDER BY table_name 
LIMIT 10;
"
```

#### 方法 3: 如果上述方法无效，重置用户

```bash
# 完全重置用户和权限
SITE_USER="site3_user"
SITE_PASSWORD="site3_prod_pass_2024"

docker exec postgres_master psql -U admin -d postgres -c "
-- 撤销旧权限
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM $SITE_USER;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM $SITE_USER;

-- 删除并重新创建用户
DROP USER IF EXISTS $SITE_USER;
CREATE USER $SITE_USER WITH PASSWORD '$SITE_PASSWORD';

-- 授予基础权限
GRANT CONNECT ON DATABASE postgres TO $SITE_USER;
GRANT USAGE ON SCHEMA public TO $SITE_USER;

-- 授予表和序列权限
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $SITE_USER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $SITE_USER;
"

# 测试
docker exec postgres_master psql -U $SITE_USER -d postgres -c "SELECT current_user, COUNT(*) FROM site3__users;"
```

#### 常见错误原因

1. **DO 代码块不执行**：在某些 shell 环境中，heredoc 方式的 DO 代码块可能静默失败
2. **GRANT 命令未生效**：需要使用 `-c` 参数明确执行
3. **表所有者问题**：表的所有者如果不是 admin，可能导致授权失败

#### 验证权限是否成功

```bash
# 1. 查看用户权限列表
docker exec postgres_master psql -U admin -d postgres -c "
SELECT DISTINCT table_name 
FROM information_schema.table_privileges 
WHERE grantee = 'site3_user' AND table_name LIKE 'site3__%'
ORDER BY table_name;
"

# 2. 测试读取
docker exec postgres_master psql -U site3_user -d postgres -c "SELECT COUNT(*) FROM site3__users;"

# 3. 测试插入
docker exec postgres_master psql -U site3_user -d postgres -c "
INSERT INTO site3__users (username, email, password_hash) 
VALUES ('testuser', 'test@site3.com', 'test123') 
ON CONFLICT (email) DO NOTHING;
"

# 如果以上三个命令都成功，权限配置正确！
```

---

### 问题 5: 连接池耗尽

**症状**：
```
Error: remaining connection slots are reserved
```

**原因**：连接数超过限制

**解决**：
```bash
# 1. 检查当前连接数
docker exec postgres_master psql -U admin -d postgres -c "
SELECT count(*) as connections, usename 
FROM pg_stat_activity 
GROUP BY usename;
"

# 2. 减少应用的连接池大小
nano /docker/your-app/.env
# 修改：DB_MAX_CONNECTIONS=10

# 3. 清理空闲连接
docker exec postgres_master psql -U admin -d postgres -c "
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE state = 'idle' AND state_change < now() - interval '5 minutes';
"

# 4. 重启应用
docker restart your-app
```

---

### 问题 6: 反馈表数据混乱

**症状**：查询到其他站点的反馈数据

**原因**：查询时未过滤 `site_id`

**解决**：
```javascript
// ❌ 错误：没有过滤 site_id
const query = 'SELECT * FROM unified_feedback';

// ✅ 正确：必须过滤 site_id
const siteId = process.env.SITE_ID || 'colormagic';
const query = 'SELECT * FROM unified_feedback WHERE site_id = $1';
const result = await db.query(query, [siteId]);
```

---

## 📊 验证检查清单

接入完成后，请确认以下所有项目：

```bash
# ✅ 1. 网络连接
docker network inspect shared_net | grep your-app
# 应该看到你的应用容器

# ✅ 2. DNS 解析
docker exec your-app ping -c 2 postgres_master
# 应该能 ping 通

# ✅ 3. 端口连接
docker exec your-app nc -zv postgres_master 5432
# 应该显示连接成功

# ✅ 4. 数据库连接
docker logs your-app | grep -i "database\|connected"
# 应该看到连接成功的日志

# ✅ 5. 表访问权限
docker exec postgres_master psql -U colormagic_user -d postgres -c "SELECT COUNT(*) FROM colormagic_users;"
# 应该返回数字（至少1）

# ✅ 6. 应用健康检查
curl http://localhost:3000/health
# 应该返回正常状态
```

---

## 📞 需要帮助？

### 查看日志

```bash
# PostgreSQL 日志
docker logs postgres_master --tail 100

# 应用日志
docker logs your-app --tail 100

# 实时查看
docker logs your-app -f
```

### 进入数据库检查

```bash
# 使用 admin 用户
docker exec -it postgres_master psql -U admin -d postgres

# 使用站点用户
docker exec -it postgres_master psql -U colormagic_user -d postgres

# 常用命令：
# \dt                    - 列出所有表
# \dt colormagic_*       - 列出 ColorMagic 表
# \d colormagic_users    - 查看表结构
# \du                    - 列出所有用户
# \q                     - 退出
```

### 联系方式

- 📖 查看完整文档：`README.md`
- 🐛 提交问题：GitHub Issues
- 📚 参考文档：`使用指南-完整版.md`

---

**版本**: v1.0  
**最后更新**: 2024-10-02  
**适用系统**: PostgreSQL 总系统 v2.0  
**GitHub**: https://github.com/sicks0214/postgres-master-system

