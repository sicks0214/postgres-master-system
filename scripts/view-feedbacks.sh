#!/bin/bash

# ============================================================================
# PostgreSQL 总系统 - 反馈数据查看工具
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "=============================================="
echo "PostgreSQL 总系统 - 反馈数据查看"
echo "=============================================="
echo ""

# 检查参数
SITE_ID=${1:-"all"}
LIMIT=${2:-20}

# ============================================================================
# 功能菜单
# ============================================================================

if [ "$SITE_ID" = "help" ] || [ "$SITE_ID" = "--help" ] || [ "$SITE_ID" = "-h" ]; then
    echo "用法: $0 [站点ID] [限制数量]"
    echo ""
    echo "示例:"
    echo "  $0                    # 查看所有站点的反馈（最近20条）"
    echo "  $0 site3              # 查看 Site3 的反馈"
    echo "  $0 colormagic         # 查看 ColorMagic 的反馈"
    echo "  $0 site3 50           # 查看 Site3 的最近50条反馈"
    echo "  $0 stats              # 查看统计信息"
    echo "  $0 pending            # 查看待处理的反馈"
    echo ""
    exit 0
fi

# ============================================================================
# 查看统计信息
# ============================================================================

if [ "$SITE_ID" = "stats" ]; then
    echo "📊 反馈统计信息"
    echo "=============================================="
    echo ""
    
    docker exec postgres_master psql -U admin -d postgres -c "
    SELECT 
        site_id as 站点,
        COUNT(*) as 总数,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as 待处理,
        COUNT(CASE WHEN status = 'reviewed' THEN 1 END) as 已查看,
        COUNT(CASE WHEN status = 'resolved' THEN 1 END) as 已解决,
        ROUND(AVG(rating), 2) as 平均评分
    FROM unified_feedback 
    WHERE site_id != 'system'
    GROUP BY site_id
    ORDER BY COUNT(*) DESC;
    "
    
    echo ""
    echo "📈 总体统计"
    echo "=============================================="
    echo ""
    
    docker exec postgres_master psql -U admin -d postgres -c "
    SELECT 
        COUNT(*) as 总反馈数,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as 待处理,
        COUNT(CASE WHEN status = 'resolved' THEN 1 END) as 已解决,
        COUNT(DISTINCT site_id) - 1 as 活跃站点数,
        ROUND(AVG(rating), 2) as 平均评分
    FROM unified_feedback 
    WHERE site_id != 'system';
    "
    
    exit 0
fi

# ============================================================================
# 查看待处理的反馈
# ============================================================================

if [ "$SITE_ID" = "pending" ]; then
    echo "⏳ 待处理的反馈"
    echo "=============================================="
    echo ""
    
    docker exec postgres_master psql -U admin -d postgres -c "
    SELECT 
        id,
        site_id as 站点,
        LEFT(content, 40) as 内容,
        category as 分类,
        rating as 评分,
        contact as 联系方式,
        created_at as 创建时间
    FROM unified_feedback 
    WHERE status = 'pending'
    ORDER BY created_at DESC
    LIMIT $LIMIT;
    "
    
    exit 0
fi

# ============================================================================
# 查看特定站点或所有站点的反馈
# ============================================================================

if [ "$SITE_ID" = "all" ]; then
    echo "📋 所有站点的反馈（最近 $LIMIT 条）"
    echo "=============================================="
    echo ""
    
    docker exec postgres_master psql -U admin -d postgres -c "
    SELECT 
        id,
        site_id as 站点,
        LEFT(content, 50) as 内容,
        category as 分类,
        rating as 评分,
        status as 状态,
        created_at as 创建时间
    FROM unified_feedback 
    WHERE site_id != 'system'
    ORDER BY created_at DESC 
    LIMIT $LIMIT;
    "
else
    echo "📋 站点 '$SITE_ID' 的反馈（最近 $LIMIT 条）"
    echo "=============================================="
    echo ""
    
    # 检查站点是否有反馈
    COUNT=$(docker exec postgres_master psql -U admin -d postgres -t -c "
    SELECT COUNT(*) FROM unified_feedback WHERE site_id = '$SITE_ID';
    " | tr -d ' ')
    
    if [ "$COUNT" -eq "0" ]; then
        echo -e "${YELLOW}⚠️  站点 '$SITE_ID' 暂无反馈数据${NC}"
        echo ""
        echo "提示: 使用 '$0 stats' 查看所有站点统计"
        exit 0
    fi
    
    docker exec postgres_master psql -U admin -d postgres -c "
    SELECT 
        id,
        LEFT(content, 60) as 内容,
        category as 分类,
        rating as 评分,
        status as 状态,
        contact as 联系方式,
        user_ip as IP,
        created_at as 创建时间
    FROM unified_feedback 
    WHERE site_id = '$SITE_ID'
    ORDER BY created_at DESC 
    LIMIT $LIMIT;
    "
    
    echo ""
    echo -e "${GREEN}✅ 找到 $COUNT 条反馈${NC}"
fi

echo ""
echo "=============================================="
echo ""
echo "💡 更多选项:"
echo "  - 查看统计: $0 stats"
echo "  - 待处理: $0 pending"
echo "  - 查看帮助: $0 help"
echo ""

