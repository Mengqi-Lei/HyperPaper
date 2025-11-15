#!/bin/bash

# 版本管理脚本
# 用法: ./version.sh [major|minor|patch|show|tag]

VERSION_FILE="VERSION"
CHANGELOG_FILE="CHANGELOG.md"

# 读取当前版本
get_current_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE" | tr -d ' \n'
    else
        echo "0.0.0"
    fi
}

# 显示当前版本
show_version() {
    echo "当前版本: $(get_current_version)"
}

# 版本号递增
increment_version() {
    local version=$(get_current_version)
    local part=$1
    
    IFS='.' read -ra PARTS <<< "$version"
    local major=${PARTS[0]}
    local minor=${PARTS[1]}
    local patch=${PARTS[2]}
    
    case $part in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo "错误: 无效的版本部分 '$part'。使用 major, minor 或 patch"
            exit 1
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# 更新版本文件
update_version_file() {
    local new_version=$1
    echo "$new_version" > "$VERSION_FILE"
    echo "版本已更新为: $new_version"
}

# 创建Git标签
create_tag() {
    local version=$1
    local tag_name="v$version"
    
    if git rev-parse "$tag_name" >/dev/null 2>&1; then
        echo "警告: 标签 $tag_name 已存在"
        read -p "是否强制创建？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "取消操作"
            exit 1
        fi
        git tag -d "$tag_name"
        git push origin :refs/tags/"$tag_name" 2>/dev/null || true
    fi
    
    git tag -a "$tag_name" -m "版本 $version"
    echo "已创建Git标签: $tag_name"
    
    read -p "是否推送到远程仓库？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push origin "$tag_name"
        echo "标签已推送到远程仓库"
    fi
}

# 主函数
main() {
    case "${1:-show}" in
        show)
            show_version
            ;;
        major|minor|patch)
            local current_version=$(get_current_version)
            local new_version=$(increment_version $1)
            
            echo "当前版本: $current_version"
            echo "新版本: $new_version"
            read -p "确认更新版本？(y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "取消操作"
                exit 0
            fi
            
            update_version_file "$new_version"
            git add "$VERSION_FILE"
            git commit -m "版本升级: $current_version -> $new_version"
            echo "版本文件已提交"
            
            read -p "是否创建Git标签？(Y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                create_tag "$new_version"
            fi
            ;;
        tag)
            local version=$(get_current_version)
            create_tag "$version"
            ;;
        *)
            echo "用法: $0 [major|minor|patch|show|tag]"
            echo ""
            echo "命令说明:"
            echo "  major  - 主版本号递增 (1.0.0 -> 2.0.0)"
            echo "  minor  - 次版本号递增 (1.0.0 -> 1.1.0)"
            echo "  patch  - 修订版本号递增 (1.0.0 -> 1.0.1)"
            echo "  show   - 显示当前版本 (默认)"
            echo "  tag    - 为当前版本创建Git标签"
            exit 1
            ;;
    esac
}

main "$@"

