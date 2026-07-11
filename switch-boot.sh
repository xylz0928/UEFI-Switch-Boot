#!/usr/bin/env bash

# ============================================================================
# switch-boot - 一次性切换 GRUB 启动项
# 支持单键响应：按 q 立即取消，按 Enter 立即确认默认
# ============================================================================

set -o errexit
set -o nounset
set -o pipefail

# ----------------------------------------------------------------------------
# 颜色定义（使用 tput 更规范）
# ----------------------------------------------------------------------------
if [ -t 1 ]; then
    readonly COLOR_RED=$(tput setaf 1)
    readonly COLOR_GREEN=$(tput setaf 2)
    readonly COLOR_YELLOW=$(tput setaf 3)
    readonly COLOR_RESET=$(tput sgr0)
else
    readonly COLOR_RED=""
    readonly COLOR_GREEN=""
    readonly COLOR_YELLOW=""
    readonly COLOR_RESET=""
fi

# ----------------------------------------------------------------------------
# 错误处理函数
# ----------------------------------------------------------------------------
error_exit() {
    printf "${COLOR_RED}错误：%s${COLOR_RESET}\n" "$*" >&2
    exit 1
}

# ----------------------------------------------------------------------------
# 权限检查
# ----------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    error_exit "此脚本需要 root 权限，请使用：sudo switch-boot"
fi

# ----------------------------------------------------------------------------
# 检查 GRUB 配置文件
# ----------------------------------------------------------------------------
GRUB_CFG="/boot/grub/grub.cfg"
if [ ! -f "$GRUB_CFG" ]; then
    error_exit "找不到 GRUB 配置文件：$GRUB_CFG"
fi

# ----------------------------------------------------------------------------
# 解析 GRUB 菜单项
# ----------------------------------------------------------------------------
if ! mapfile -t menu_items < <(awk -F\' '/^menuentry / {print $2}' "$GRUB_CFG" 2>/dev/null); then
    error_exit "无法解析 GRUB 配置文件"
fi

if [ ${#menu_items[@]} -eq 0 ]; then
    error_exit "未找到任何 GRUB 启动项"
fi

# ----------------------------------------------------------------------------
# 显示菜单列表
# ----------------------------------------------------------------------------
printf "\n${COLOR_GREEN}====== GRUB 启动菜单项 ======${COLOR_RESET}\n"
for i in "${!menu_items[@]}"; do
    printf "  %2d : %s\n" "$i" "${menu_items[$i]}"
done
printf "${COLOR_GREEN}===============================${COLOR_RESET}\n\n"

# ----------------------------------------------------------------------------
# 自动检测默认目标（Windows）
# ----------------------------------------------------------------------------
DEFAULT_INDEX=-1
DEFAULT_TITLE=""
for i in "${!menu_items[@]}"; do
    if [[ "${menu_items[$i]}" =~ Windows|Boot[[:space:]]Manager ]]; then
        DEFAULT_INDEX="$i"
        DEFAULT_TITLE="${menu_items[$i]}"
        break
    fi
done

if [ "$DEFAULT_INDEX" -eq -1 ]; then
    DEFAULT_INDEX=0
    DEFAULT_TITLE="${menu_items[0]}"
    printf "${COLOR_YELLOW}警告：未找到 Windows 启动项，将默认选择：%s${COLOR_RESET}\n" "$DEFAULT_TITLE"
fi

# ----------------------------------------------------------------------------
# 显示提示信息
# ----------------------------------------------------------------------------
printf "${COLOR_GREEN}默认选中：${COLOR_RESET}[%d] %s\n" "$DEFAULT_INDEX" "$DEFAULT_TITLE"
printf "等待 ${COLOR_YELLOW}10${COLOR_RESET} 秒，若无操作将自动重启进入上述系统。\n"
printf "按 ${COLOR_YELLOW}Enter${COLOR_RESET} 确认默认，输入 ${COLOR_YELLOW}序号${COLOR_RESET} 切换到其他项，"
printf "按 ${COLOR_YELLOW}q${COLOR_RESET} 立即取消\n"
printf "\n请选择："

# ----------------------------------------------------------------------------
# 读取用户输入（单字符或数字，10秒超时）
# ----------------------------------------------------------------------------
TARGET=""
# 使用 -n1 读取单个字符，-t 设置超时
if read -r -t 10 -n1 key; then
    # 检查是否为空（按 Enter 键）
    if [ -z "$key" ]; then
        TARGET="$DEFAULT_TITLE"
        printf "\n\n${COLOR_GREEN}确认默认选择${COLOR_RESET}\n"
    elif [ "$key" = "q" ] || [ "$key" = "Q" ]; then
        printf "\n\n${COLOR_GREEN}操作已取消，系统不会重启。${COLOR_RESET}\n"
        exit 0
    elif [[ "$key" =~ ^[0-9]$ ]]; then
        # 只按了一个数字键（0-9），但可能是个位序号
        # 需要等待用户决定是否输入更多数字
        # 这里处理：先记录已按的数字，然后继续读取完整输入
        number="$key"
        # 再等待 2 秒看是否还有更多数字输入
        printf "\n"
        if read -r -t 2 -n1 extra; then
            # 如果又输入了数字，拼接起来
            if [[ "$extra" =~ ^[0-9]$ ]]; then
                number="${number}${extra}"
                # 继续读取直到不是数字或超时
                while read -r -t 1 -n1 extra2; do
                    if [[ "$extra2" =~ ^[0-9]$ ]]; then
                        number="${number}${extra2}"
                    else
                        break
                    fi
                done
            fi
        fi
        printf "\n"
        if [ "$number" -ge 0 ] && [ "$number" -lt "${#menu_items[@]}" ]; then
            TARGET="${menu_items[$number]}"
            printf "${COLOR_GREEN}切换到：${COLOR_RESET}[%d] %s\n" "$number" "$TARGET"
        else
            error_exit "序号 %d 超出范围（0-%d）" "$number" "$((${#menu_items[@]} - 1))"
        fi
    else
        # 按了其他键（如字母），当作无效输入，使用默认
        TARGET="$DEFAULT_TITLE"
        printf "\n\n${COLOR_YELLOW}无效输入，使用默认选择${COLOR_RESET}\n"
    fi
else
    # 超时
    TARGET="$DEFAULT_TITLE"
    printf "\n\n${COLOR_YELLOW}输入超时，自动选择默认项${COLOR_RESET}\n"
fi

# ----------------------------------------------------------------------------
# 执行 grub-reboot
# ----------------------------------------------------------------------------
printf "\n${COLOR_GREEN}设置下次启动项为：${COLOR_RESET}%s\n" "$TARGET"

if ! grub-reboot "$TARGET" 2>/dev/null; then
    error_exit "grub-reboot 执行失败，请检查目标项是否存在：%s" "$TARGET"
fi

# ----------------------------------------------------------------------------
# 确认并重启
# ----------------------------------------------------------------------------
printf "\n${COLOR_GREEN}✓ 设置成功，系统即将重启...${COLOR_RESET}\n"
printf "${COLOR_YELLOW}提示：按 Ctrl+C 可取消重启（但下次启动项已设置）${COLOR_RESET}\n"
sleep 3

systemctl reboot -i
