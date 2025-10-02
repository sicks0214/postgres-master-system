-- ============================================================================
-- PostgreSQL总系统 - 站点1-20用户预留和系统函数
-- ============================================================================

-- ============================================
-- 批量创建站点用户（site1_user ~ site20_user）
-- ============================================

DO $$
DECLARE
    i INTEGER;
    test_password TEXT := 'site%s_test_pass';  -- 本地测试密码
    prod_password TEXT := 'site%s_pass';       -- VPS生产密码（部署时修改）
BEGIN
    FOR i IN 1..20 LOOP
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'site' || i || '_user') THEN
            -- 创建用户（使用测试密码，VPS部署时需要修改）
            EXECUTE format('CREATE USER site%s_user WITH ENCRYPTED PASSWORD ''site%s_test_pass''', i, i);
            
            -- 授予统一反馈表权限
            EXECUTE format('GRANT SELECT, INSERT, UPDATE ON unified_feedback TO site%s_user', i);
            EXECUTE format('GRANT USAGE ON SEQUENCE unified_feedback_id_seq TO site%s_user', i);
            
            RAISE NOTICE '✅ 创建用户: site%_user', i;
        ELSE
            RAISE NOTICE 'ℹ️  用户已存在: site%_user', i;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ 所有站点用户创建完成（site1_user ~ site20_user）';
    RAISE NOTICE '⚠️  注意: VPS部署时请修改密码为生产密码';
END
$$;

-- ============================================
-- 系统统计函数
-- ============================================

-- 获取总系统统计
CREATE OR REPLACE FUNCTION get_system_stats()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'systemName', 'PostgreSQL总系统',
        'version', '2.0',
        'timestamp', CURRENT_TIMESTAMP,
        'totalSites', (
            SELECT COUNT(DISTINCT site_id) 
            FROM unified_feedback 
            WHERE site_id != 'system'
        ),
        'totalFeedbacks', (
            SELECT COUNT(*) 
            FROM unified_feedback 
            WHERE site_id != 'system'
        ),
        'colormagic', json_build_object(
            'users', (SELECT COUNT(*) FROM colormagic_users WHERE status = 'active'),
            'analyses', (SELECT COUNT(*) FROM colormagic_color_analysis),
            'palettes', (SELECT COUNT(*) FROM colormagic_palettes),
            'exports', (SELECT COUNT(*) FROM colormagic_export_history)
        ),
        'system', json_build_object(
            'database', current_database(),
            'dbSize', pg_size_pretty(pg_database_size(current_database())),
            'activeConnections', (
                SELECT count(*) 
                FROM pg_stat_activity 
                WHERE state = 'active'
            )
        )
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_system_stats() IS 'PostgreSQL总系统 - 获取系统统计信息';

-- 获取活跃站点列表
CREATE OR REPLACE FUNCTION get_active_sites()
RETURNS TABLE(
    site_id VARCHAR, 
    feedback_count BIGINT, 
    last_activity TIMESTAMP,
    status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        f.site_id,
        COUNT(*) as feedback_count,
        MAX(f.created_at) as last_activity,
        CASE 
            WHEN MAX(f.created_at) > NOW() - INTERVAL '7 days' THEN 'active'
            WHEN MAX(f.created_at) > NOW() - INTERVAL '30 days' THEN 'inactive'
            ELSE 'dormant'
        END as status
    FROM unified_feedback f
    WHERE f.site_id != 'system'
    GROUP BY f.site_id
    ORDER BY last_activity DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_active_sites() IS 'PostgreSQL总系统 - 获取活跃站点列表和状态';

-- 获取站点详细统计
CREATE OR REPLACE FUNCTION get_site_stats(p_site_id VARCHAR)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'siteId', p_site_id,
        'feedback', json_build_object(
            'total', (SELECT COUNT(*) FROM unified_feedback WHERE site_id = p_site_id),
            'pending', (SELECT COUNT(*) FROM unified_feedback WHERE site_id = p_site_id AND status = 'pending'),
            'resolved', (SELECT COUNT(*) FROM unified_feedback WHERE site_id = p_site_id AND status = 'resolved'),
            'lastFeedback', (SELECT MAX(created_at) FROM unified_feedback WHERE site_id = p_site_id)
        ),
        'avgRating', (
            SELECT ROUND(AVG(rating)::numeric, 2) 
            FROM unified_feedback 
            WHERE site_id = p_site_id AND rating IS NOT NULL
        )
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_site_stats(VARCHAR) IS 'PostgreSQL总系统 - 获取指定站点的详细统计';

-- 清理过期会话（通用函数）
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS TABLE(deleted_count INTEGER) AS $$
BEGIN
    RETURN QUERY
    WITH deleted AS (
        DELETE FROM colormagic_sessions 
        WHERE expires_at < CURRENT_TIMESTAMP 
           OR (refresh_expires_at < CURRENT_TIMESTAMP AND is_active = false)
        RETURNING *
    )
    SELECT COUNT(*)::INTEGER FROM deleted;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_expired_sessions() IS 'PostgreSQL总系统 - 清理过期会话';

-- ============================================
-- 显示初始化完成信息
-- ============================================

DO $$
DECLARE
    user_count INTEGER;
    table_count INTEGER;
    function_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count 
    FROM pg_user 
    WHERE usename LIKE '%_user' OR usename = 'admin';
    
    SELECT COUNT(*) INTO table_count 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
      AND table_type = 'BASE TABLE';
    
    SELECT COUNT(*) INTO function_count 
    FROM information_schema.routines 
    WHERE routine_schema = 'public';
    
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════';
    RAISE NOTICE '  PostgreSQL总系统初始化完成';
    RAISE NOTICE '════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE '📊 系统信息:';
    RAISE NOTICE '   • 数据库: %', current_database();
    RAISE NOTICE '   • 版本: PostgreSQL 15.x';
    RAISE NOTICE '   • 时区: %', current_setting('timezone');
    RAISE NOTICE '';
    RAISE NOTICE '👥 用户统计:';
    RAISE NOTICE '   • 总用户数: %', user_count;
    RAISE NOTICE '   • ColorMagic用户: colormagic_user';
    RAISE NOTICE '   • 站点用户: site1_user ~ site20_user';
    RAISE NOTICE '';
    RAISE NOTICE '📦 数据对象:';
    RAISE NOTICE '   • 表数量: %', table_count;
    RAISE NOTICE '   • 函数数量: %', function_count;
    RAISE NOTICE '';
    RAISE NOTICE '🔐 安全提醒:';
    RAISE NOTICE '   ⚠️  请修改默认管理员密码';
    RAISE NOTICE '   ⚠️  VPS部署时修改所有用户密码';
    RAISE NOTICE '';
    RAISE NOTICE '📖 使用指南:';
    RAISE NOTICE '   • 查看系统统计: SELECT get_system_stats();';
    RAISE NOTICE '   • 查看活跃站点: SELECT * FROM get_active_sites();';
    RAISE NOTICE '   • 查看站点详情: SELECT get_site_stats(''colormagic'');';
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════';
    RAISE NOTICE '';
END
$$;

