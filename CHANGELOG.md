# PostgreSQL总系统 - 更新日志

所有重要更改都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)

---

## [2.0.0] - 2024-10-02

### 新增 (Added)

#### 架构重新设计
- ✨ 全新的PostgreSQL总系统架构，支持20个站点
- ✨ Site4 (ColorMagic) 完整表结构和权限配置
- ✨ 统一反馈系统（unified_feedback表）
- ✨ 表前缀系统（colormagic_*, site1_*, site2_*, ...）

#### 表结构
- ✨ `colormagic_users` - 用户表（UUID主键）
- ✨ `colormagic_sessions` - 会话表（支持JWT refresh token）
- ✨ `colormagic_analysis_history` - 用户分析历史表
- ✨ `colormagic_palettes` - 收藏调色板表
- ✨ `colormagic_usage_stats` - 使用统计表
- ✨ `colormagic_color_analysis` - 颜色分析记录表
- ✨ `colormagic_export_history` - 导出历史表
- ✨ `unified_feedback` - 统一反馈表（支持所有站点）

#### 系统函数
- ✨ `get_system_stats()` - 获取系统统计信息（JSON格式）
- ✨ `get_active_sites()` - 获取活跃站点列表
- ✨ `get_site_stats(site_id)` - 获取指定站点详细统计
- ✨ `cleanup_expired_sessions()` - 清理过期会话

#### 部署工具
- ✨ 本地测试环境配置（docker-compose.local.yml）
- ✨ VPS生产环境配置（docker-compose.vps.yml）
- ✨ Windows启动/验证脚本（.bat）
- ✨ Linux/Mac启动/验证脚本（.sh）
- ✨ VPS导出脚本（export-to-vps.sh）

#### 文档
- 📚 完整的README.md（包含所有部署步骤）
- 📚 快速上手指南（QUICKSTART.md）
- 📚 更新日志（本文件）
- 📚 部署说明（自动生成）

### 改进 (Changed)

#### 数据库配置
- 🔧 使用PostgreSQL 15-alpine镜像
- 🔧 增加连接池配置（max_connections=200）
- 🔧 优化内存配置（shared_buffers=256MB）
- 🔧 添加健康检查（pg_isready）

#### 权限管理
- 🔧 精细化权限控制（表级和序列级）
- 🔧 用户隔离（每个站点独立用户）
- 🔧 统一反馈表共享权限

#### 网络配置
- 🔧 使用Docker网络别名（postgres_master）
- 🔧 本地测试使用独立网络（local_test_net）
- 🔧 VPS使用共享网络（shared_net）

### 修复 (Fixed)
- 🐛 修复站点用户权限配置问题
- 🐛 修复表前缀命名冲突问题
- 🐛 修复初始化脚本执行顺序问题

### 安全 (Security)
- 🔒 支持密码加密（ENCRYPTED PASSWORD）
- 🔒 会话管理（token_hash和refresh_token_hash）
- 🔒 用户状态管理（active/suspended/deleted）
- 🔒 登录失败次数限制（failed_login_attempts）

### 已知问题
- ⚠️ 默认密码需要在VPS部署时手动修改
- ⚠️ 本地测试环境使用5433端口，避免冲突

---

## [1.0.0] - 2024-09-30

### 新增
- 🎉 初始版本发布
- ✨ 基础PostgreSQL容器配置
- ✨ 简单的站点用户管理

### 已弃用
- ⚠️ v1.0的表结构和权限配置已被v2.0完全重新设计

---

## 升级指南

### 从 v1.0 升级到 v2.0

**⚠️ 重要：v2.0是完全重新设计的架构，不兼容v1.0**

**推荐方式：全新部署**

1. 备份v1.0数据（如果有重要数据）
   ```bash
   docker exec postgres_master pg_dumpall -U admin > backup_v1.sql
   ```

2. 停止并删除v1.0系统
   ```bash
   cd /docker/db_master
   docker compose down -v
   rm -rf *
   ```

3. 部署v2.0系统
   ```bash
   # 上传并解压v2.0文件
   tar -xzf postgres-master-system.tar.gz
   
   # 启动新系统
   docker compose -f docker-compose.vps.yml up -d
   ```

4. 如需迁移数据，请手动导入到新表结构

---

## 反馈和贡献

有问题或建议？请通过以下方式联系：
- GitHub Issues
- 邮件反馈
- 团队内部沟通

---

**保持系统更新，享受最新功能！** 🚀

