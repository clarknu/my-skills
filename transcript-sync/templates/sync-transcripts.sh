#!/bin/bash
# =============================================================================
# sync-transcripts.sh
# Claude Code Hook — 每轮对话结束 & 会话结束时自动将 transcript 同步到项目目录
#
# 由 .claude/settings.local.json 中的两个 hook 调用：
#   - UserPromptSubmit: 每当用户提交新 prompt 时触发（捕获上一轮完整响应）
#   - Stop:             agent 决定结束会话时触发（兜底捕获最后一轮）
#
# 从 stdin 读取 JSON（含 session_id / transcript_path / cwd / hook_event_name），
# 将 transcript 及其 subagent 子目录拷贝到 <项目根>/transcripts/ 下。
#
# 依赖：仅使用 bash 内置 + grep/sed/cp/mkdir（标准 Unix 工具，无 Python/Node 依赖）
#
# 性能说明：
#   - 每次只操作当前这一个 session 的目录，不遍历历史 session → O(1)
#   - 主 .jsonl 文件：用 cp 覆盖（每次必有新内容）
#   - subagents / tool-results：用 cp -u 按 mtime 跳过不变文件
#
# 目的：将所有 AI 对话记录纳入 Git 版本控制，为软件著作权和发明专利申请
#        提供完整的开发过程证据链。
# =============================================================================
set -euo pipefail

INPUT=$(cat)

# --- 纯 bash JSON 值提取（无外部依赖，grep+sed 标准工具）--------------------
# 仅适用于扁平、单层、无转义引号的 JSON — hook 的 stdin 恰好满足此条件
json_extract() {
  local key="$1"
  # grep 找不到 key 时返回 1，pipefail 下会触发 set -e → 用 || true 兜底
  echo "$INPUT" | grep -o "\"$key\":\"[^\"]*\"" 2>/dev/null | head -1 | sed "s/\"$key\":\"//;s/\"$//" || true
}

SESSION_ID=$(json_extract "session_id")
TRANSCRIPT_PATH=$(json_extract "transcript_path")
CWD=$(json_extract "cwd")
HOOK_EVENT=$(json_extract "hook_event_name")

# --- Windows 路径归一化 -------------------------------------------------------
# hook 在某些场景下传入 Windows 格式路径（C:\Users\...），
# 需转换为 Unix 格式（/c/Users/...），否则 bash 会把 C: 当成目录名
normalize_path() {
  local p="$1"
  case "$p" in
    [A-Za-z]:*)
      # C:\foo\bar → /c/foo/bar
      p=$(echo "$p" | sed 's|^\([A-Za-z]\):|\1|;s|\\|/|g')
      p="/$p"
      ;;
  esac
  echo "$p"
}

TRANSCRIPT_PATH=$(normalize_path "$TRANSCRIPT_PATH")
CWD=$(normalize_path "$CWD")

# --- 基本校验 ----------------------------------------------------------------
fail() {
  local reason="$1"
  # 始终 exit 0 — 不同步 transcript 不应阻塞用户操作
  # systemMessage 字段会出现在 transcript 中，agent 看到后可提醒用户
  echo "{\"continue\": true, \"decision\": \"approve\", \"systemMessage\": \"[sync-transcripts] FAILED: $reason\"}"
  exit 0
}

if [ -z "$TRANSCRIPT_PATH" ]; then
  fail "transcript_path is empty — hook may not have provided it"
fi

if [ ! -f "$TRANSCRIPT_PATH" ]; then
  fail "transcript file not found: $TRANSCRIPT_PATH"
fi

# --- 使用 CLAUDE_PROJECT_DIR 而非 CWD -------------------------------------------------
# CWD 在某些场景下指向子目录（如 agent 在子目录中工作），会导致 transcript 写入子目录。
# CLAUDE_PROJECT_DIR 由 hook system 设置，始终指向项目根目录。
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$CWD}"
if [ -z "$PROJECT_ROOT" ]; then
  fail "cannot determine project root (CLAUDE_PROJECT_DIR=$CLAUDE_PROJECT_DIR, cwd=$CWD)"
fi
PROJECT_ROOT=$(normalize_path "$PROJECT_ROOT")

# --- 计算路径 -----------------------------------------------------------------
TRANSCRIPT_DIR="${TRANSCRIPT_PATH%/*}"
TRANSCRIPT_NAME="${TRANSCRIPT_PATH##*/}"
SESSION_UUID="${TRANSCRIPT_NAME%.jsonl}"
TARGET_DIR="$PROJECT_ROOT/transcripts/$SESSION_UUID"

# --- 检查目标目录是否在项目内（防止意外写入其他位置）--------------------------
case "$TARGET_DIR" in
  "$PROJECT_ROOT/transcripts/"*) ;;
  *) fail "target dir outside project root transcripts/: $TARGET_DIR (root=$PROJECT_ROOT)" ;;
esac

# --- 同步主 transcript 文件 ---------------------------------------------------
if ! mkdir -p "$TARGET_DIR" 2>/dev/null; then
  fail "cannot create directory: $TARGET_DIR"
fi

if ! cp "$TRANSCRIPT_PATH" "$TARGET_DIR/$TRANSCRIPT_NAME" 2>/dev/null; then
  fail "cannot copy transcript to: $TARGET_DIR/$TRANSCRIPT_NAME"
fi

# --- 同步 subagents 子目录 ----------------------------------------------------
SUBSRC="$TRANSCRIPT_DIR/$SESSION_UUID/subagents"
if [ -d "$SUBSRC" ]; then
  mkdir -p "$TARGET_DIR/subagents" 2>/dev/null || true
  for srcfile in "$SUBSRC"/*; do
    [ -f "$srcfile" ] || continue
    cp -u "$srcfile" "$TARGET_DIR/subagents/" 2>/dev/null || true
  done
fi

# --- 同步 tool-results 子目录 ------------------------------------------------
TOOLSRC="$TRANSCRIPT_DIR/$SESSION_UUID/tool-results"
if [ -d "$TOOLSRC" ]; then
  mkdir -p "$TARGET_DIR/tool-results" 2>/dev/null || true
  for srcfile in "$TOOLSRC"/*; do
    [ -f "$srcfile" ] || continue
    cp -u "$srcfile" "$TARGET_DIR/tool-results/" 2>/dev/null || true
  done
fi

# --- 清理误写入子目录的 transcript 残留 ----------------------------------------
# 当本项目内子目录出现同 session UUID 的 transcripts 目录时，说明某次 hook 触发时
# CWD 被传成了子目录路径。transcript 已通过 PROJECT_ROOT 正确同步到根目录，
# 子目录下的残留应主动清理。
CLEANED=0
while IFS= read -r stray_dir; do
  if [ -d "$stray_dir" ] && [ "$stray_dir" != "$TARGET_DIR" ]; then
    rm -rf "$stray_dir" 2>/dev/null || true
    CLEANED=$((CLEANED + 1))
  fi
done < <(find "$PROJECT_ROOT" -type d -path "*/transcripts/$SESSION_UUID" 2>/dev/null || true)

CLEANUP_MSG=""
if [ "$CLEANED" -gt 0 ]; then
  CLEANUP_MSG=", cleaned $CLEANED stray transcript dir(s)"
fi

# --- 成功返回 -----------------------------------------------------------------
echo "{\"continue\": true, \"decision\": \"approve\", \"systemMessage\": \"[sync-transcripts] OK: [$HOOK_EVENT] $SESSION_UUID$CLEANUP_MSG\"}"
exit 0
