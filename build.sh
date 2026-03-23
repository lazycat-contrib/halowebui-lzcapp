#!/bin/bash

# ============================================
# HaloWebUI LazyCat 应用发布脚本
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置
APP_NAME="HaloWebUI"
APP_VERSION="1.0.0"
PACKAGE_NAME="cloud.lazycat.app.halowebui"
ORIGINAL_IMAGE="ghcr.io/ztx888/halowebui:main"

# 打印函数
print_header() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║          HaloWebUI LazyCat 应用发布工具                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓ ${NC}$1"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${NC}$1"
}

print_error() {
    echo -e "${RED}✗ ${NC}$1"
}

# 检查必需文件
check_files() {
    print_info "检查必需文件..."

    local missing_files=()

    if [[ ! -f "lzc-manifest.yml" ]]; then
        missing_files+=("lzc-manifest.yml")
    fi

    if [[ ! -f "lzc-build.yml" ]]; then
        missing_files+=("lzc-build.yml")
    fi

    if [[ ! -f "icon.png" ]]; then
        print_warning "缺少 icon.png 文件 (需要 512x512 PNG 格式)"
        print_info "请准备一个应用图标后继续"
    fi

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        print_error "缺少必需文件:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        return 1
    fi

    print_success "所有必需文件检查通过"
    return 0
}

# 显示应用信息
show_info() {
    print_header
    echo -e "${YELLOW}应用信息:${NC}"
    echo "  名称: $APP_NAME"
    echo "  版本: $APP_VERSION"
    echo "  包名: $PACKAGE_NAME"
    echo ""
    echo -e "${YELLOW}镜像信息:${NC}"
    echo "  原始镜像: $ORIGINAL_IMAGE"
    echo ""
    echo -e "${YELLOW}存储配置:${NC}"
    echo "  /lzcapp/var/open-webui → /app/backend/data"
    echo ""
    echo -e "${YELLOW}特殊配置:${NC}"
    echo "  extra_hosts: host.docker.internal:host-gateway"
    echo ""
}

# 构建应用
build_app() {
    print_info "构建 LPK 包..."

    if ! check_files; then
        return 1
    fi

    local output_file="${APP_NAME,,}-${APP_VERSION}.lpk"
    output_file=${output_file// /-}

    if lzc-cli project build -o "$output_file"; then
        print_success "构建成功: $output_file"
        echo ""
        print_info "本地安装命令:"
        echo "  lzc-cli app install $output_file"
        return 0
    else
        print_error "构建失败"
        return 1
    fi
}

# 检查登录状态
check_login() {
    print_info "检查登录状态..."
    if ! lzc-cli appstore my-images &> /dev/null 2>&1; then
        print_warning "未登录懒猫应用商店"
        print_info "请先执行: lzc-cli appstore login"
        return 1
    fi
    print_success "已登录懒猫应用商店"
    return 0
}

# 复制镜像到懒猫仓库
copy_image() {
    print_info "复制镜像到懒猫仓库..."

    if ! check_login; then
        return 1
    fi

    print_info "正在复制: $ORIGINAL_IMAGE"
    echo ""

    local result
    result=$(lzc-cli appstore copy-image "$ORIGINAL_IMAGE" 2>&1)
    echo "$result"
    echo ""

    # 提取新镜像地址
    local new_image
    new_image=$(echo "$result" | grep "^uploaded:" | awk '{print $2}')

    if [[ -n "$new_image" ]]; then
        print_success "镜像复制成功"
        echo ""
        print_info "新镜像地址: $new_image"

        # 更新 manifest 文件
        update_manifest_image "$new_image"
    else
        print_error "镜像复制失败"
        return 1
    fi
}

# 更新 manifest 中的镜像地址
update_manifest_image() {
    local new_image="$1"

    print_info "更新 manifest 文件..."

    # 更新 lzc-manifest.yml
    if [[ -f "lzc-manifest.yml" ]]; then
        # 备份原文件
        cp lzc-manifest.yml lzc-manifest.yml.bak

        # 使用 awk 更新镜像行，保留原始镜像为注释
        awk -v new="$new_image" '
        /image: ghcr\.io\/ztx888\/halowebui/ {
            print "    # ghcr.io/ztx888/halowebui:main"
            print "    image: " new
            next
        }
        { print }
        ' lzc-manifest.yml.bak > lzc-manifest.yml

        rm lzc-manifest.yml.bak
        print_success "已更新 lzc-manifest.yml"
    fi

    # 更新 manifest.yml (如果存在)
    if [[ -f "manifest.yml" ]]; then
        cp manifest.yml manifest.yml.bak
        awk -v new="$new_image" '
        /image: ghcr\.io\/ztx888\/halowebui/ {
            print "    # ghcr.io/ztx888/halowebui:main"
            print "    image: " new
            next
        }
        { print }
        ' manifest.yml.bak > manifest.yml
        rm manifest.yml.bak
        print_success "已更新 manifest.yml"
    fi
}

# 发布到应用商店
publish_app() {
    print_info "发布到应用商店..."

    if ! check_login; then
        return 1
    fi

    local lpk_file="${APP_NAME,,}-${APP_VERSION}.lpk"
    lpk_file=${lpk_file// /-}

    if [[ ! -f "$lpk_file" ]]; then
        print_error "找不到 LPK 文件: $lpk_file"
        print_info "请先构建应用"
        return 1
    fi

    print_info "发布: $lpk_file"
    echo ""

    if lzc-cli appstore publish "$lpk_file"; then
        print_success "发布成功！"
        print_info "应用将进入审核流程 (1-3 天)"
        return 0
    else
        print_error "发布失败"
        return 1
    fi
}

# 一键发布
one_click_publish() {
    print_header
    print_info "🚀 开始一键发布流程..."
    echo ""

    # 阶段 1: 初始构建
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}阶段 1/4: 初始构建（原始镜像）${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if ! build_app; then
        print_error "构建失败，终止发布流程"
        return 1
    fi
    echo ""

    # 阶段 2: 复制镜像
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}阶段 2/4: 复制镜像到懒猫仓库${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if ! copy_image; then
        print_error "镜像复制失败，终止发布流程"
        return 1
    fi
    echo ""

    # 阶段 3: 重新构建
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}阶段 3/4: 重新构建（新镜像）${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if ! build_app; then
        print_error "重新构建失败，终止发布流程"
        return 1
    fi
    echo ""

    # 阶段 4: 发布
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}阶段 4/4: 发布到应用商店${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if ! publish_app; then
        print_error "发布失败"
        return 1
    fi
    echo ""

    print_success "🎉 一键发布完成！"
}

# 主菜单
show_menu() {
    print_header
    echo -e "${YELLOW}请选择操作:${NC}"
    echo ""
    echo "  1. 📦 构建应用 (Build)"
    echo "  2. 🔧 复制镜像到懒猫仓库 (Copy Image)"
    echo "  3. 📤 发布到应用商店 (Publish)"
    echo "  4. 🚀 一键构建+镜像复制+发布 (One-Click)"
    echo "  5. 📋 查看应用信息 (Info)"
    echo "  6. ❌ 退出"
    echo ""
    echo -n "请输入选项 [1-6]: "
}

# 主程序
main() {
    while true; do
        show_menu
        read -r choice
        echo ""

        case $choice in
            1)
                build_app
                ;;
            2)
                copy_image
                ;;
            3)
                publish_app
                ;;
            4)
                one_click_publish
                ;;
            5)
                show_info
                ;;
            6)
                print_info "退出"
                exit 0
                ;;
            *)
                print_error "无效选项，请重新选择"
                ;;
        esac

        echo ""
        echo -e "${CYAN}按 Enter 返回菜单...${NC}"
        read -r
    done
}

# 运行主程序
main