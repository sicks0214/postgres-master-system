# ColorMagic 数据库结构详解

## 📊 数据库概览

**站点**: Site4 (ColorMagic) - 图片取色工具  
**数据库用户**: `colormagic_user`  
**表前缀**: `colormagic_`  
**总表数**: 7个专用表 + 1个共享表

---

## 🗂️ 表结构详细说明

### 1. colormagic_users - 用户表

**用途**: 存储注册用户信息

```sql
CREATE TABLE colormagic_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    avatar_url VARCHAR(500),
    display_name VARCHAR(100),
    status VARCHAR(20) DEFAULT 'active',
    email_verified BOOLEAN DEFAULT false,
    subscription_type VARCHAR(20) DEFAULT 'free',
    subscription_expires_at TIMESTAMP,
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP,
    login_count INTEGER DEFAULT 0,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP
);
```

**字段说明**:
- `id`: UUID主键，自动生成
- `email`: 邮箱，唯一索引
- `username`: 用户名，唯一索引
- `password_hash`: 密码哈希值（bcrypt）
- `status`: 用户状态（active/suspended/deleted）
- `subscription_type`: 订阅类型（free/premium/vip）
- `preferences`: JSONB格式的用户偏好设置
- `login_count`: 登录次数统计
- `failed_login_attempts`: 失败登录次数（用于账户锁定）

**索引**:
- `idx_colormagic_users_email`
- `idx_colormagic_users_username`
- `idx_colormagic_users_status`

---

### 2. colormagic_sessions - 会话表

**用途**: 管理用户登录会话和JWT Token

```sql
CREATE TABLE colormagic_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES colormagic_users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    refresh_token_hash VARCHAR(255),
    expires_at TIMESTAMP NOT NULL,
    refresh_expires_at TIMESTAMP NOT NULL,
    ip_address INET,
    user_agent TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**字段说明**:
- `token_hash`: 访问令牌的哈希值
- `refresh_token_hash`: 刷新令牌的哈希值
- `expires_at`: 访问令牌过期时间
- `refresh_expires_at`: 刷新令牌过期时间
- `ip_address`: 客户端IP地址（INET类型）
- `user_agent`: 客户端User-Agent
- `is_active`: 会话是否激活（可手动失效）

**索引**:
- `idx_colormagic_sessions_user_id`
- `idx_colormagic_sessions_token_hash`
- `idx_colormagic_sessions_expires_at`

---

### 3. colormagic_analysis_history - 用户分析历史表

**用途**: 记录登录用户的图片分析历史

```sql
CREATE TABLE colormagic_analysis_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES colormagic_users(id) ON DELETE SET NULL,
    image_url VARCHAR(500),
    image_hash VARCHAR(64),
    analysis_result JSONB NOT NULL,
    analysis_type VARCHAR(50) NOT NULL,
    processing_time_ms INTEGER,
    tags TEXT[],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**字段说明**:
- `analysis_result`: JSONB格式的分析结果
- `analysis_type`: 分析类型（basic/advanced/ai_powered）
- `processing_time_ms`: 处理时间（毫秒）
- `tags`: PostgreSQL数组类型的标签

**约束**:
- `CHECK (analysis_type IN ('basic', 'advanced', 'ai_powered'))`

---

### 4. colormagic_palettes - 收藏调色板表

**用途**: 用户收藏的调色板

```sql
CREATE TABLE colormagic_palettes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES colormagic_users(id) ON DELETE CASCADE,
    palette_name VARCHAR(100) NOT NULL,
    colors JSONB NOT NULL,
    source_type VARCHAR(20) DEFAULT 'manual',
    tags TEXT[],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**字段说明**:
- `colors`: JSONB格式的颜色数组，例如：
  ```json
  [
    {"hex": "#FF6B6B", "name": "Coral"},
    {"hex": "#FFD93D", "name": "Gold"}
  ]
  ```
- `source_type`: 来源类型（manual/extracted/ai_generated）

---

### 5. colormagic_usage_stats - 使用统计表

**用途**: 按日统计用户使用情况

```sql
CREATE TABLE colormagic_usage_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES colormagic_users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    analyses_count INTEGER DEFAULT 0,
    ai_analyses_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, date)
);
```

**字段说明**:
- `date`: 统计日期
- `analyses_count`: 普通分析次数
- `ai_analyses_count`: AI分析次数

**约束**:
- `UNIQUE(user_id, date)`: 每个用户每天只有一条记录

---

### 6. colormagic_color_analysis - 颜色分析记录表

**用途**: 记录所有的颜色分析（包括匿名用户）

```sql
CREATE TABLE colormagic_color_analysis (
    id SERIAL PRIMARY KEY,
    analysis_id VARCHAR(100) UNIQUE NOT NULL,
    user_id UUID REFERENCES colormagic_users(id) ON DELETE SET NULL,
    image_name VARCHAR(255),
    image_size_bytes INTEGER,
    original_width INTEGER,
    original_height INTEGER,
    processed_width INTEGER,
    processed_height INTEGER,
    extracted_colors JSONB,
    dominant_colors JSONB,
    palette JSONB,
    metadata JSONB,
    processing_time_ms REAL,
    algorithm VARCHAR(50) DEFAULT 'production',
    user_ip VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**字段说明**:
- `id`: SERIAL自增主键
- `analysis_id`: 业务ID（唯一）
- `user_id`: 可选，NULL表示匿名用户
- `extracted_colors`: 提取的所有颜色
- `dominant_colors`: 主导颜色
- `palette`: 最终调色板
- `metadata`: 额外的元数据（JSONB）

**数据示例**:
```json
{
  "extracted_colors": [
    {"hex": "#FF6B6B", "count": 1234, "percentage": 15.2},
    {"hex": "#4ECDC4", "count": 987, "percentage": 12.1}
  ],
  "dominant_colors": [
    {"hex": "#FF6B6B", "name": "Coral Red"}
  ]
}
```

---

### 7. colormagic_export_history - 导出历史表

**用途**: 记录用户导出调色板的历史

```sql
CREATE TABLE colormagic_export_history (
    id SERIAL PRIMARY KEY,
    analysis_id VARCHAR(100) REFERENCES colormagic_color_analysis(analysis_id),
    user_id UUID REFERENCES colormagic_users(id) ON DELETE SET NULL,
    export_format VARCHAR(20) NOT NULL,
    color_count INTEGER NOT NULL,
    file_size_bytes INTEGER,
    user_ip VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**字段说明**:
- `export_format`: 导出格式（css/json/scss/adobe/txt）
- `color_count`: 导出的颜色数量

**约束**:
- `CHECK (export_format IN ('css', 'json', 'scss', 'adobe', 'txt'))`

---

### 8. unified_feedback - 统一反馈表（共享）

**用途**: 所有站点共享的反馈表

```sql
-- ColorMagic 使用时，site_id = 'colormagic'
SELECT * FROM unified_feedback WHERE site_id = 'colormagic';
```

**字段说明**:
- `site_id`: 站点标识（colormagic）
- `content`: 反馈内容
- `category`: 分类（general/bug/feature/other）
- `rating`: 评分（1-5）
- `status`: 状态（pending/reviewed/resolved/archived）

---

## 🔧 系统函数

### 1. get_colormagic_system_stats()

**用途**: 获取 ColorMagic 系统统计信息

```sql
SELECT get_colormagic_system_stats();
```

**返回示例**:
```json
{
  "total_users": 1,
  "total_analyses": 0,
  "total_exports": 0,
  "total_palettes": 1,
  "avg_processing_time_ms": null,
  "today_analyses": 0,
  "active_sessions": 0
}
```

---

### 2. get_colormagic_popular_colors(limit)

**用途**: 获取最近30天的热门颜色

```sql
SELECT * FROM get_colormagic_popular_colors(10);
```

**返回示例**:
```
hex_color  | color_name  | usage_count
-----------|-------------|-------------
#FF6B6B    | Coral       | 125
#4ECDC4    | Turquoise   | 98
```

---

## 📦 测试数据

系统已预置以下测试数据：

### 测试用户
- **邮箱**: test@colormagic.com
- **用户名**: testuser
- **密码**: test123
- **状态**: active, email_verified=true

### 测试调色板
- **名称**: Sunset Colors
- **颜色**: Coral (#FF6B6B), Gold (#FFD93D)
- **标签**: sunset, warm

---

## 🔐 权限配置

### colormagic_user 权限

```sql
-- 所有 colormagic_* 表的完整权限
GRANT SELECT, INSERT, UPDATE, DELETE ON colormagic_users TO colormagic_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON colormagic_sessions TO colormagic_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON colormagic_analysis_history TO colormagic_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON colormagic_palettes TO colormagic_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON colormagic_usage_stats TO colormagic_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON colormagic_color_analysis TO colormagic_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON colormagic_export_history TO colormagic_user;

-- 统一反馈表权限（只能读写）
GRANT SELECT, INSERT, UPDATE ON unified_feedback TO colormagic_user;

-- 序列权限
GRANT USAGE ON SEQUENCE unified_feedback_id_seq TO colormagic_user;
GRANT USAGE ON SEQUENCE colormagic_color_analysis_id_seq TO colormagic_user;
GRANT USAGE ON SEQUENCE colormagic_export_history_id_seq TO colormagic_user;
```

---

## 📊 ER 图（关系图）

```
colormagic_users (用户表)
    |
    ├─→ colormagic_sessions (会话表)
    ├─→ colormagic_analysis_history (用户分析历史)
    ├─→ colormagic_palettes (收藏调色板)
    ├─→ colormagic_usage_stats (使用统计)
    └─→ colormagic_color_analysis (颜色分析) ← 也支持匿名用户
            |
            └─→ colormagic_export_history (导出历史)

unified_feedback (统一反馈表)
    ├─ site_id = 'colormagic' (ColorMagic的反馈)
    ├─ site_id = 'site1' (其他站点)
    └─ ...
```

---

## 🎯 常用查询示例

### 查询活跃用户
```sql
SELECT username, email, login_count, last_login_at
FROM colormagic_users
WHERE status = 'active'
ORDER BY last_login_at DESC
LIMIT 10;
```

### 查询最近的分析记录
```sql
SELECT 
    ca.analysis_id,
    u.username,
    ca.image_name,
    ca.processing_time_ms,
    ca.created_at
FROM colormagic_color_analysis ca
LEFT JOIN colormagic_users u ON ca.user_id = u.id
ORDER BY ca.created_at DESC
LIMIT 20;
```

### 查询热门调色板
```sql
SELECT 
    p.palette_name,
    u.username,
    p.colors,
    p.tags,
    p.created_at
FROM colormagic_palettes p
JOIN colormagic_users u ON p.user_id = u.id
ORDER BY p.created_at DESC;
```

### 查询导出统计
```sql
SELECT 
    export_format,
    COUNT(*) as total_exports,
    AVG(color_count) as avg_colors,
    SUM(file_size_bytes) as total_size
FROM colormagic_export_history
GROUP BY export_format
ORDER BY total_exports DESC;
```

### 查询用户使用统计
```sql
SELECT 
    u.username,
    SUM(s.analyses_count) as total_analyses,
    SUM(s.ai_analyses_count) as total_ai_analyses
FROM colormagic_usage_stats s
JOIN colormagic_users u ON s.user_id = u.id
WHERE s.date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY u.username
ORDER BY total_analyses DESC;
```

---

## 📝 注意事项

1. **UUID vs SERIAL**
   - 用户相关表使用 UUID（更安全，不暴露用户数量）
   - 分析记录使用 SERIAL（性能更好，方便排序）

2. **JSONB 字段**
   - 使用 JSONB 而不是 JSON（支持索引和高效查询）
   - 可以使用 GIN 索引加速 JSONB 查询

3. **外键约束**
   - `ON DELETE CASCADE`: 删除用户时自动删除相关数据
   - `ON DELETE SET NULL`: 删除用户时保留记录，但清空用户ID

4. **触发器**
   - `updated_at` 字段自动更新（通过触发器）
   - 适用于 `colormagic_users` 和 `colormagic_palettes`

---

## 🚀 性能优化建议

1. **索引优化**
   ```sql
   -- 为 JSONB 字段创建 GIN 索引（如果需要）
   CREATE INDEX idx_analysis_result_gin ON colormagic_analysis_history USING GIN(analysis_result);
   ```

2. **分区表**（如果数据量大）
   ```sql
   -- colormagic_color_analysis 可以按月分区
   ```

3. **定期清理**
   ```sql
   -- 清理过期会话
   SELECT cleanup_expired_sessions();
   
   -- 归档旧的分析记录（保留最近6个月）
   ```

---

**文档版本**: v2.0  
**更新日期**: 2024-10-02

