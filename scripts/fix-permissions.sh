#!/bin/bash

# ============================================================================
# PostgreSQL 总系统 - 权限修复脚本
# 适用于新站点接入时遇到的权限问题
# ============================================================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "=============================================="
echo "PostgreSQL 总系统 - 权限修复工具"
echo "=============================================="
echo ""

# ============================================================================
# 检查参数
# ============================================================================

if [ -z "$1" ]; then
    echo "用法: $0 <站点用户名>"
    echo ""
    echo "示例:"
    echo "  $0 site3_user"
    echo "  $0 colormagic_user"
    echo ""
    exit 1
fi

SITE_USER=$1

echo "目标用户: $SITE_USER"
echo ""

# ============================================================================
# 1. 检查用户是否存在
# ============================================================================

echo "▶ 步骤 1: 检查用户是否存在"
USER_EXISTS=$(docker exec postgres_master psql -U admin -d postgres -t -c "SELECT COUNT(*) FROM pg_user WHERE usename = '$SITE_USER';" | tr -d ' ')

if [ "$USER_EXISTS" -eq "0" ]; then
    echo -e "${RED}❌ 用户 $SITE_USER 不存在${NC}"
    echo ""
    echo "请先创建用户，或检查用户名是否正确"
    exit 1
else
    echo -e "${GREEN}✅ 用户存在${NC}"
fi

echo ""

# ============================================================================
# 2. 检查当前权限
# ============================================================================

echo "▶ 步骤 2: 检查当前权限"
CURRENT_PERMS=$(docker exec postgres_master psql -U admin -d postgres -t -c "
SELECT COUNT(*) 
FROM information_schema.table_privileges 
WHERE grantee = '$SITE_USER';
" | tr -d ' ')

echo "当前权限数: $CURRENT_PERMS"

if [ "$CURRENT_PERMS" -gt "0" ]; then
    echo "已有权限的表："
    docker exec postgres_master psql -U admin -d postgres -c "
    SELECT DISTINCT table_name 
    FROM information_schema.table_privileges 
    WHERE grantee = '$SITE_USER' 
    ORDER BY table_name 
    LIMIT 10;
    "
fi

echo ""

# ============================================================================
# 3. 授予所有权限
# ============================================================================

echo "▶ 步骤 3: 授予所有权限"

# 授予表权限
echo "→ 授予表权限..."
docker exec postgres_master psql -U admin -d postgres -c "
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $SITE_USER;
" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 表权限授予成功${NC}"
else
    echo -e "${RED}❌ 表权限授予失败${NC}"
fi

# 授予序列权限
echo "→ 授予序列权限..."
docker exec postgres_master psql -U admin -d postgres -c "
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $SITE_USER;
" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 序列权限授予成功${NC}"
else
    echo -e "${RED}❌ 序列权限授予失败${NC}"
fi

# 授予基础权限（如果还没有）
echo "→ 授予数据库连接权限..."
docker exec postgres_master psql -U admin -d postgres -c "
GRANT CONNECT ON DATABASE postgres TO $SITE_USER;
GRANT USAGE ON SCHEMA public TO $SITE_USER;
" > /dev/null 2>&1

echo ""

# ============================================================================
# 4. 验证权限
# ============================================================================

echo "▶ 步骤 4: 验证权限"

NEW_PERMS=$(docker exec postgres_master psql -U admin -d postgres -t -c "
SELECT COUNT(*) 
FROM information_schema.table_privileges 
WHERE grantee = '$SITE_USER';
" | tr -d ' ')

echo "授权后权限数: $NEW_PERMS"

if [ "$NEW_PERMS" -gt "$CURRENT_PERMS" ]; then
    echo -e "${GREEN}✅ 权限数量增加了 $(($NEW_PERMS - $CURRENT_PERMS)) 个${NC}"
else
    echo -e "${YELLOW}⚠️  权限数量未增加，可能已经有权限${NC}"
fi

echo ""
echo "已授权的表（前10个）："
docker exec postgres_master psql -U admin -d postgres -c "
SELECT DISTINCT table_name 
FROM information_schema.table_privileges 
WHERE grantee = '$SITE_USER' 
ORDER BY table_name 
LIMIT 10;
"

echo ""

# ============================================================================
# 5. 测试访问
# ============================================================================

echo "▶ 步骤 5: 测试访问"

# 提取表前缀（从用户名）
TABLE_PREFIX=""
if [[ "$SITE_USER" == "colormagic_user" ]]; then
    TABLE_PREFIX="colormagic_"
elif [[ "$SITE_USER" =~ ^site([0-9]+)_user$ ]]; then
    SITE_NUM="${BASH_REMATCH[1]}"
    TABLE_PREFIX="site${SITE_NUM}_"
fi

echo "检测到的表前缀: $TABLE_PREFIX"
echo ""

# 查找该用户的表
if [ ! -z "$TABLE_PREFIX" ]; then
    # 查找可能的表名（支持单下划线和双下划线）
    FIRST_TABLE=$(docker exec postgres_master psql -U admin -d postgres -t -c "
    SELECT tablename 
    FROM pg_tables 
    WHERE schemaname = 'public' 
      AND (tablename LIKE '${TABLE_PREFIX}%' OR tablename LIKE '${TABLE_PREFIX}_%')
    LIMIT 1;
    " | tr -d ' ')
    
    if [ ! -z "$FIRST_TABLE" ]; then
        echo "→ 测试表: $FIRST_TABLE"
        
        # 测试读取
        TEST_RESULT=$(docker exec postgres_master psql -U $SITE_USER -d postgres -t -c "SELECT COUNT(*) FROM $FIRST_TABLE;" 2>&1)
        
        if [[ "$TEST_RESULT" =~ "permission denied" ]]; then
            echo -e "${RED}❌ 测试失败：权限被拒绝${NC}"
            echo ""
            echo "可能的原因："
            echo "1. 表的所有者不是 admin"
            echo "2. PostgreSQL 配置有特殊限制"
            echo ""
            echo "建议运行: $0 --reset $SITE_USER"
        elif [[ "$TEST_RESULT" =~ [0-9]+ ]]; then
            COUNT=$(echo $TEST_RESULT | tr -d ' ')
            echo -e "${GREEN}✅ 测试成功：可以访问表（记录数: $COUNT）${NC}"
        else
            echo -e "${YELLOW}⚠️  测试结果不确定：$TEST_RESULT${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  未找到 ${TABLE_PREFIX} 开头的表${NC}"
        echo "如果你还没有创建表，请先创建表后再测试"
    fi
else
    echo -e "${YELLOW}⚠️  无法自动检测表前缀，跳过访问测试${NC}"
fi

echo ""

# ============================================================================
# 6. 测试 unified_feedback 表
# ============================================================================

echo "▶ 步骤 6: 测试统一反馈表访问"

FEEDBACK_TEST=$(docker exec postgres_master psql -U $SITE_USER -d postgres -t -c "SELECT COUNT(*) FROM unified_feedback;" 2>&1)

if [[ "$FEEDBACK_TEST" =~ "permission denied" ]]; then
    echo -e "${RED}❌ 无法访问 unified_feedback 表${NC}"
    
    # 尝试授予权限
    echo "→ 尝试授予权限..."
    docker exec postgres_master psql -U admin -d postgres -c "
    GRANT SELECT, INSERT, UPDATE ON unified_feedback TO $SITE_USER;
    GRANT USAGE ON SEQUENCE unified_feedback_id_seq TO $SITE_USER;
    " > /dev/null 2>&1
    
    # 再次测试
    FEEDBACK_TEST2=$(docker exec postgres_master psql -U $SITE_USER -d postgres -t -c "SELECT COUNT(*) FROM unified_feedback;" 2>&1)
    if [[ "$FEEDBACK_TEST2" =~ [0-9]+ ]]; then
        echo -e "${GREEN}✅ 授权后可以访问${NC}"
    else
        echo -e "${RED}❌ 仍然无法访问${NC}"
    fi
elif [[ "$FEEDBACK_TEST" =~ [0-9]+ ]]; then
    COUNT=$(echo $FEEDBACK_TEST | tr -d ' ')
    echo -e "${GREEN}✅ 可以访问 unified_feedback 表（记录数: $COUNT）${NC}"
fi

echo ""

# ============================================================================
# 完成
# ============================================================================

echo "=============================================="
echo "权限修复完成"
echo "=============================================="
echo ""

if [ "$NEW_PERMS" -gt "0" ]; then
    echo -e "${GREEN}✅ $SITE_USER 已具有访问权限${NC}"
    echo ""
    echo "📝 下一步："
    echo "1. 确认应用的 .env 文件中的 DB_USER 和 DB_PASSWORD 正确"
    echo "2. 确认应用的 TABLE_PREFIX 与数据库表名匹配"
    echo "3. 重新部署应用"
    echo ""
else
    echo -e "${RED}❌ 权限授予可能失败${NC}"
    echo ""
    echo "建议："
    echo "1. 检查 PostgreSQL 日志: docker logs postgres_master"
    echo "2. 手动执行授权命令"
    echo "3. 联系管理员"
    echo ""
fi

