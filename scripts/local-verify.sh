#!/bin/bash
# ============================================
# PostgreSQL总系统 - 本地验证脚本 (Linux/Mac)
# ============================================

set -e

echo ""
echo "============================================"
echo "PostgreSQL总系统 - 本地验证测试"
echo "============================================"
echo ""

CONTAINER="postgres_local_test"
SUCCESS=0
FAILED=0

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================
# 1. 测试数据库连接
# ============================================
echo "1️⃣  测试数据库连接..."
if docker exec $CONTAINER psql -U admin -d postgres -c "SELECT version();" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ 数据库连接成功${NC}"
    ((SUCCESS++))
else
    echo -e "   ${RED}❌ 数据库连接失败${NC}"
    ((FAILED++))
fi
echo ""

# ============================================
# 2. 检查统一反馈表
# ============================================
echo "2️⃣  检查统一反馈表..."
COUNT=$(docker exec $CONTAINER psql -U admin -d postgres -t -c "SELECT COUNT(*) FROM unified_feedback;" 2>/dev/null | xargs)
if [ -n "$COUNT" ]; then
    echo -e "   ${GREEN}✅ 统一反馈表: ${COUNT}条记录${NC}"
    ((SUCCESS++))
else
    echo -e "   ${RED}❌ 统一反馈表检查失败${NC}"
    ((FAILED++))
fi
echo ""

# ============================================
# 3. 检查ColorMagic表
# ============================================
echo "3️⃣  检查ColorMagic表..."
COUNT=$(docker exec $CONTAINER psql -U admin -d postgres -t -c "SELECT COUNT(*) FROM pg_tables WHERE tablename LIKE 'colormagic_%';" 2>/dev/null | xargs)
if [ -n "$COUNT" ]; then
    echo -e "   ${GREEN}✅ ColorMagic表: ${COUNT}个表${NC}"
    ((SUCCESS++))
else
    echo -e "   ${RED}❌ ColorMagic表检查失败${NC}"
    ((FAILED++))
fi
echo ""

# ============================================
# 4. 检查系统用户
# ============================================
echo "4️⃣  检查系统用户..."
COUNT=$(docker exec $CONTAINER psql -U admin -d postgres -t -c "SELECT COUNT(*) FROM pg_user WHERE usename LIKE '%_user' OR usename = 'admin';" 2>/dev/null | xargs)
if [ -n "$COUNT" ]; then
    echo -e "   ${GREEN}✅ 系统用户: ${COUNT}个用户${NC}"
    ((SUCCESS++))
else
    echo -e "   ${RED}❌ 系统用户检查失败${NC}"
    ((FAILED++))
fi
echo ""

# ============================================
# 5. 测试ColorMagic用户连接
# ============================================
echo "5️⃣  测试ColorMagic用户连接..."
if docker exec $CONTAINER psql -U colormagic_user -d postgres -c "SELECT current_user;" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ ColorMagic用户连接成功${NC}"
    ((SUCCESS++))
else
    echo -e "   ${RED}❌ ColorMagic用户连接失败${NC}"
    ((FAILED++))
fi
echo ""

# ============================================
# 6. 测试ColorMagic用户权限
# ============================================
echo "6️⃣  测试ColorMagic用户权限..."
if docker exec $CONTAINER psql -U colormagic_user -d postgres -c "SELECT COUNT(*) FROM colormagic_users;" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ ColorMagic用户权限验证通过${NC}"
    ((SUCCESS++))
else
    echo -e "   ${RED}❌ ColorMagic用户权限验证失败${NC}"
    ((FAILED++))
fi
echo ""

# ============================================
# 7. 测试系统统计函数
# ============================================
echo "7️⃣  测试系统统计函数..."
if docker exec $CONTAINER psql -U admin -d postgres -c "SELECT get_system_stats();" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ 系统统计函数正常${NC}"
    ((SUCCESS++))
else
    echo -e "   ${RED}❌ 系统统计函数失败${NC}"
    ((FAILED++))
fi
echo ""

# ============================================
# 8. 测试插入反馈
# ============================================
echo "8️⃣  测试插入反馈..."
if docker exec $CONTAINER psql -U colormagic_user -d postgres -c "INSERT INTO unified_feedback (site_id, content, category) VALUES ('colormagic', '本地验证测试反馈', 'test') RETURNING id;" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ 反馈插入成功${NC}"
    ((SUCCESS++))
else
    echo -e "   ${RED}❌ 反馈插入失败${NC}"
    ((FAILED++))
fi
echo ""

# ============================================
# 显示结果
# ============================================
echo "============================================"
echo "📊 验证结果:"
echo "   成功: $SUCCESS/8"
echo "   失败: $FAILED/8"
echo "============================================"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ 所有验证测试完成 - 系统正常运行${NC}"
    echo ""
    echo "📝 系统统计:"
    docker exec $CONTAINER psql -U admin -d postgres -c "SELECT jsonb_pretty(get_system_stats()::jsonb);"
else
    echo -e "${RED}❌ 部分测试失败，请检查日志${NC}"
    echo ""
    echo "查看详细日志: docker logs $CONTAINER"
fi

echo ""

