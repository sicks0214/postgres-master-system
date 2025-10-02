-- ============================================================================
-- PostgreSQL总系统 - 统一反馈表
-- 所有站点共享，通过site_id区分
-- ============================================================================

CREATE TABLE IF NOT EXISTS unified_feedback (
    id SERIAL PRIMARY KEY,
    site_id VARCHAR(50) NOT NULL,
    user_id UUID,
    content TEXT NOT NULL,
    contact VARCHAR(255),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    category VARCHAR(50) DEFAULT 'general',
    user_ip VARCHAR(45),
    user_agent TEXT,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'archived')),
    admin_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE,
    priority INTEGER DEFAULT 1,
    
    CONSTRAINT chk_content_length CHECK (LENGTH(content) >= 5)
);

-- 索引
CREATE INDEX idx_unified_feedback_site_id ON unified_feedback(site_id);
CREATE INDEX idx_unified_feedback_created_at ON unified_feedback(created_at DESC);
CREATE INDEX idx_unified_feedback_status ON unified_feedback(status);
CREATE INDEX idx_unified_feedback_category ON unified_feedback(category);
CREATE INDEX idx_unified_feedback_user_id ON unified_feedback(user_id);

-- 注释
COMMENT ON TABLE unified_feedback IS 'PostgreSQL总系统 - 统一反馈表（支持20个站点）';
COMMENT ON COLUMN unified_feedback.site_id IS '站点标识：colormagic, site1, site2, ..., site20';
COMMENT ON COLUMN unified_feedback.user_id IS '用户ID（可选，来自各站点的用户表）';

-- 插入系统初始化记录
INSERT INTO unified_feedback (site_id, content, category, status, processed) 
VALUES ('system', 'PostgreSQL总系统初始化完成', 'system', 'resolved', true);

-- 插入测试数据（仅用于验证）
INSERT INTO unified_feedback (site_id, content, category, rating) VALUES
('colormagic', '这是一个测试反馈 - 用于验证系统功能', 'general', 5),
('colormagic', '测试反馈2 - ColorMagic站点', 'bug', 4);

