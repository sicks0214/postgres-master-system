-- ============================================================================
-- Site4 (ColorMagic) 专用表
-- 表前缀: colormagic_
-- 用户: colormagic_user
-- ============================================================================

-- 创建ColorMagic专用用户
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'colormagic_user') THEN
        -- 本地测试密码：ColorMagic_Local_Test_Pass
        -- VPS生产密码：ColorMagic_VPS_2024_Secure_Pass
        CREATE USER colormagic_user WITH ENCRYPTED PASSWORD 'ColorMagic_Local_Test_Pass';
        RAISE NOTICE '✅ 创建用户: colormagic_user';
    ELSE
        RAISE NOTICE 'ℹ️  用户已存在: colormagic_user';
    END IF;
END
$$;

-- ============================================
-- 认证系统表
-- ============================================

-- 用户表
CREATE TABLE IF NOT EXISTS colormagic_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    avatar_url VARCHAR(500),
    display_name VARCHAR(100),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')),
    email_verified BOOLEAN DEFAULT false,
    subscription_type VARCHAR(20) DEFAULT 'free' CHECK (subscription_type IN ('free', 'premium', 'vip')),
    subscription_expires_at TIMESTAMP,
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP,
    login_count INTEGER DEFAULT 0,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP
);

CREATE INDEX idx_colormagic_users_email ON colormagic_users(email);
CREATE INDEX idx_colormagic_users_username ON colormagic_users(username);
CREATE INDEX idx_colormagic_users_status ON colormagic_users(status);
COMMENT ON TABLE colormagic_users IS 'Site4 (ColorMagic) - 用户表';

-- 会话表
CREATE TABLE IF NOT EXISTS colormagic_sessions (
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

CREATE INDEX idx_colormagic_sessions_user_id ON colormagic_sessions(user_id);
CREATE INDEX idx_colormagic_sessions_token_hash ON colormagic_sessions(token_hash);
CREATE INDEX idx_colormagic_sessions_expires_at ON colormagic_sessions(expires_at);
COMMENT ON TABLE colormagic_sessions IS 'Site4 (ColorMagic) - 会话表';

-- 分析历史表（用户关联）
CREATE TABLE IF NOT EXISTS colormagic_analysis_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES colormagic_users(id) ON DELETE SET NULL,
    image_url VARCHAR(500),
    image_hash VARCHAR(64),
    analysis_result JSONB NOT NULL,
    analysis_type VARCHAR(50) NOT NULL CHECK (analysis_type IN ('basic', 'advanced', 'ai_powered')),
    processing_time_ms INTEGER,
    tags TEXT[],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_colormagic_analysis_history_user_id ON colormagic_analysis_history(user_id);
CREATE INDEX idx_colormagic_analysis_history_created_at ON colormagic_analysis_history(created_at);
CREATE INDEX idx_colormagic_analysis_history_type ON colormagic_analysis_history(analysis_type);
COMMENT ON TABLE colormagic_analysis_history IS 'Site4 (ColorMagic) - 分析历史表（用户关联）';

-- 收藏调色板表
CREATE TABLE IF NOT EXISTS colormagic_palettes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES colormagic_users(id) ON DELETE CASCADE,
    palette_name VARCHAR(100) NOT NULL,
    colors JSONB NOT NULL,
    source_type VARCHAR(20) DEFAULT 'manual' CHECK (source_type IN ('manual', 'extracted', 'ai_generated')),
    tags TEXT[],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_colormagic_palettes_user_id ON colormagic_palettes(user_id);
CREATE INDEX idx_colormagic_palettes_created_at ON colormagic_palettes(created_at);
COMMENT ON TABLE colormagic_palettes IS 'Site4 (ColorMagic) - 收藏调色板表';

-- 使用统计表
CREATE TABLE IF NOT EXISTS colormagic_usage_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES colormagic_users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    analyses_count INTEGER DEFAULT 0,
    ai_analyses_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, date)
);

CREATE INDEX idx_colormagic_usage_stats_user_id ON colormagic_usage_stats(user_id);
CREATE INDEX idx_colormagic_usage_stats_date ON colormagic_usage_stats(date);
COMMENT ON TABLE colormagic_usage_stats IS 'Site4 (ColorMagic) - 使用统计表';

-- ============================================
-- 颜色分析表（无用户关联 - 用于匿名访问）
-- ============================================

-- 颜色分析记录表
CREATE TABLE IF NOT EXISTS colormagic_color_analysis (
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

CREATE INDEX idx_colormagic_color_analysis_created_at ON colormagic_color_analysis(created_at);
CREATE INDEX idx_colormagic_color_analysis_user_id ON colormagic_color_analysis(user_id);
CREATE INDEX idx_colormagic_color_analysis_analysis_id ON colormagic_color_analysis(analysis_id);
COMMENT ON TABLE colormagic_color_analysis IS 'Site4 (ColorMagic) - 颜色分析记录表';

-- 导出历史表
CREATE TABLE IF NOT EXISTS colormagic_export_history (
    id SERIAL PRIMARY KEY,
    analysis_id VARCHAR(100) REFERENCES colormagic_color_analysis(analysis_id),
    user_id UUID REFERENCES colormagic_users(id) ON DELETE SET NULL,
    export_format VARCHAR(20) NOT NULL CHECK (export_format IN ('css', 'json', 'scss', 'adobe', 'txt')),
    color_count INTEGER NOT NULL,
    file_size_bytes INTEGER,
    user_ip VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_colormagic_export_history_created_at ON colormagic_export_history(created_at);
CREATE INDEX idx_colormagic_export_history_analysis_id ON colormagic_export_history(analysis_id);
COMMENT ON TABLE colormagic_export_history IS 'Site4 (ColorMagic) - 导出历史表';

-- ============================================
-- 触发器和函数
-- ============================================

CREATE OR REPLACE FUNCTION colormagic_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER colormagic_users_updated_at 
    BEFORE UPDATE ON colormagic_users 
    FOR EACH ROW EXECUTE FUNCTION colormagic_update_updated_at();

CREATE TRIGGER colormagic_palettes_updated_at 
    BEFORE UPDATE ON colormagic_palettes 
    FOR EACH ROW EXECUTE FUNCTION colormagic_update_updated_at();

-- ============================================
-- 数据分析函数
-- ============================================

-- 获取热门颜色
CREATE OR REPLACE FUNCTION get_colormagic_popular_colors(p_limit INTEGER)
RETURNS TABLE(
    hex_color VARCHAR,
    color_name VARCHAR,
    usage_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH color_usage AS (
        SELECT 
            jsonb_array_elements(palette) AS color_obj
        FROM colormagic_color_analysis
        WHERE created_at > NOW() - INTERVAL '30 days'
    )
    SELECT 
        (color_obj->>'hex')::VARCHAR AS hex_color,
        (color_obj->>'name')::VARCHAR AS color_name,
        COUNT(*)::BIGINT AS usage_count
    FROM color_usage
    WHERE color_obj->>'hex' IS NOT NULL
    GROUP BY color_obj->>'hex', color_obj->>'name'
    ORDER BY usage_count DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_colormagic_popular_colors(INTEGER) IS 'Site4 (ColorMagic) - 获取最近30天的热门颜色';

-- 获取ColorMagic系统统计
CREATE OR REPLACE FUNCTION get_colormagic_system_stats()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total_users', (SELECT COUNT(*) FROM colormagic_users WHERE status = 'active'),
        'total_analyses', (SELECT COUNT(*) FROM colormagic_color_analysis),
        'total_exports', (SELECT COUNT(*) FROM colormagic_export_history),
        'total_palettes', (SELECT COUNT(*) FROM colormagic_palettes),
        'avg_processing_time_ms', (SELECT ROUND(AVG(processing_time_ms)::numeric, 2) FROM colormagic_color_analysis WHERE processing_time_ms IS NOT NULL),
        'today_analyses', (SELECT COUNT(*) FROM colormagic_color_analysis WHERE created_at::DATE = CURRENT_DATE),
        'active_sessions', (SELECT COUNT(*) FROM colormagic_sessions WHERE is_active = true AND expires_at > CURRENT_TIMESTAMP)
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_colormagic_system_stats() IS 'Site4 (ColorMagic) - 获取系统统计信息';

-- ============================================
-- 插入测试数据（仅用于验证系统）
-- ============================================

-- 测试用户（密码: test123）
INSERT INTO colormagic_users (email, username, password_hash, display_name, email_verified) VALUES
('test@colormagic.com', 'testuser', '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Test User', true)
ON CONFLICT DO NOTHING;

-- 测试调色板
INSERT INTO colormagic_palettes (user_id, palette_name, colors, source_type, tags) 
SELECT 
    id,
    'Sunset Colors',
    '[{"hex":"#FF6B6B","name":"Coral"},{"hex":"#FFD93D","name":"Gold"}]'::jsonb,
    'manual',
    ARRAY['sunset', 'warm']
FROM colormagic_users 
WHERE username = 'testuser'
ON CONFLICT DO NOTHING;

-- ============================================
-- 权限配置
-- ============================================

-- ColorMagic用户完整权限
GRANT SELECT, INSERT, UPDATE, DELETE ON colormagic_users TO colormagic_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON colormagic_sessions TO colormagic_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON colormagic_analysis_history TO colormagic_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON colormagic_palettes TO colormagic_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON colormagic_usage_stats TO colormagic_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON colormagic_color_analysis TO colormagic_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON colormagic_export_history TO colormagic_user;

-- 统一反馈表权限（只能读写自己站点的数据）
GRANT SELECT, INSERT, UPDATE ON unified_feedback TO colormagic_user;

-- 序列权限
GRANT USAGE ON SEQUENCE unified_feedback_id_seq TO colormagic_user;
GRANT USAGE ON SEQUENCE colormagic_color_analysis_id_seq TO colormagic_user;
GRANT USAGE ON SEQUENCE colormagic_export_history_id_seq TO colormagic_user;

-- 显示配置完成信息
DO $$
BEGIN
    RAISE NOTICE '✅ Site4 (ColorMagic) 表和权限配置完成';
    RAISE NOTICE 'ℹ️  用户: colormagic_user';
    RAISE NOTICE 'ℹ️  表数: 7个表';
    RAISE NOTICE 'ℹ️  注意: VPS部署时请修改密码';
END
$$;

