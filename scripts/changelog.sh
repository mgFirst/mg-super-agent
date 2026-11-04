#!/usr/bin/env bash
# changelog.sh —— 项目变更日志记录工具
#
# 用途：把项目每次变更的“任务详情描述”追加记录到仓库根目录的 CHANGELOG.md，
# 新记录始终插入「未发布」小节顶部（最新在前）。
#
# 用法：
#   scripts/changelog.sh add --title "任务标题"
#       [--type feat] [--details "任务详情，可重复传多次"] [--ref "关联任务/PR，可重复传多次"]
#       [--date YYYY-MM-DD]
#   scripts/changelog.sh show [N]        # 显示最近 N 条记录（缺省显示全部）
#   scripts/changelog.sh help            # 显示帮助
#
# 变更类型（--type，缺省 feat）：
#   feat 新功能 | fix 修复 | docs 文档 | style 样式 | refactor 重构 | perf 性能
#   test 测试 | build 构建 | ci 持续集成 | chore 杂务 | revert 回滚 | other 其他

set -euo pipefail

SECTION_HEADING='## [未发布]'
VALID_TYPES='feat fix docs style refactor perf test build ci chore revert other'

# 解析 CHANGELOG.md 路径：优先仓库根目录，否则当前目录。
resolve_file() {
    local root
    root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$root" ]; then
        printf '%s/CHANGELOG.md\n' "$root"
    else
        printf '%s/CHANGELOG.md\n' "$(pwd)"
    fi
}

usage() {
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
    printf '错误：%s\n' "$1" >&2
    exit 2
}

default_header() {
    cat <<'EOF'
# 变更日志（CHANGELOG）

本文件记录项目每次变更的任务详情描述，最新记录在前。
新记录追加在「未发布」小节顶部；发版时将「未发布」内容归档为 `## [版本号]` 小节。
可用 `scripts/changelog.sh add` 追加记录，`scripts/changelog.sh show [N]` 查看记录。
EOF
}

cmd_add() {
    local title='' type='feat' date_str=''
    local details='' refs=''
    local key

    while [ "$#" -gt 0 ]; do
        key="$1"
        case "$key" in
            --title|--type|--date)
                [ "$#" -ge 2 ] || die "$key 缺少参数值"
                [ -n "$2" ] || die "$key 参数值为空"
                case "$key" in
                    --title) title="$2" ;;
                    --type)  type="$2" ;;
                    --date)  date_str="$2" ;;
                esac
                shift 2
                ;;
            --details|--ref)
                [ "$#" -ge 2 ] || die "$key 缺少参数值"
                [ -n "$2" ] || die "$key 参数值为空"
                case "$key" in
                    --details) details="${details}${details:+
}$2" ;;
                    --ref)     refs="${refs}${refs:+
}$2" ;;
                esac
                shift 2
                ;;
            *)
                die "未知参数：$key（用法见 scripts/changelog.sh help）"
                ;;
        esac
    done

    [ -n "$title" ] || die "必须提供 --title 任务标题"

    local ok=0 t
    for t in $VALID_TYPES; do
        [ "$t" = "$type" ] && ok=1 && break
    done
    [ "$ok" -eq 1 ] || die "非法的 --type：${type}（可选：${VALID_TYPES}）"

    if [ -z "$date_str" ]; then
        date_str="$(date +%F)"
    fi
    printf '%s' "$date_str" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' \
        || die "--date 需为 YYYY-MM-DD 格式，收到：${date_str}"

    local file entry
    file="$(resolve_file)"

    # 组装变更记录块（不含前后空行）。
    entry="### ${date_str} · ${type} · ${title}"
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        entry="${entry}
- 任务详情：${line}"
    done <<EOF
$details
EOF
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        entry="${entry}
- 关联任务：${line}"
    done <<EOF
$refs
EOF

    if [ ! -f "$file" ]; then
        {
            default_header
            printf '\n%s\n\n%s\n' "$SECTION_HEADING" "$entry"
        } >"$file"
        printf '已创建 %s 并写入首条记录。\n' "$file"
        return
    fi

    if ! grep -qF "$SECTION_HEADING" "$file"; then
        printf '\n%s\n\n%s\n' "$SECTION_HEADING" "$entry" >>"$file"
        printf '已在 %s 末尾重建「未发布」小节并写入记录。\n' "$file"
        return
    fi

    # 将记录插入「未发布」小节内第一条记录之前（最新在前）。
    CL_ENTRY="$entry" awk '
        index($0, "## [未发布]") == 1 { insec = 1 }
        insec && !inserted && $0 ~ /^### / {
            printf "%s\n\n", ENVIRON["CL_ENTRY"]
            inserted = 1
        }
        { print }
        END {
            if (!inserted) printf "\n%s\n", ENVIRON["CL_ENTRY"]
        }
    ' "$file" >"$file.tmp" && mv "$file.tmp" "$file"

    printf '已记录变更：%s\n' "$title"
}

cmd_show() {
    local n="${1:-}"
    local file
    file="$(resolve_file)"
    [ -f "$file" ] || die "未找到 $file，请先用 scripts/changelog.sh add 记录变更"
    if [ -n "$n" ]; then
        printf '%s' "$n" | grep -Eq '^[0-9]+$' || die "N 需为正整数，收到：$n"
        [ "$n" -ge 1 ] || die "N 需为正整数，收到：$n"
    fi

    CL_MAXN="$n" awk '
        BEGIN { maxn = ENVIRON["CL_MAXN"] + 0 }
        /^### / { c++ }
        maxn > 0 && c > maxn { exit }
        c >= 1
    ' "$file"
}

main() {
    local cmd="${1:-help}"
    [ "$#" -gt 0 ] && shift
    case "$cmd" in
        add)  cmd_add "$@" ;;
        show) cmd_show "$@" ;;
        help|-h|--help) usage ;;
        *) die "未知命令：$cmd（可用命令：add / show / help）" ;;
    esac
}

main "$@"
