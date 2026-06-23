---
name: transcript-sync
version: 1.0.0
description: |
  Claude 对话记录自动同步到项目目录——将每轮对话的 transcript（含 subagents、tool-results）
  自动拷贝到项目 transcripts/ 目录，纳入 Git 版本控制。
  为开发过程提供完整的可追溯证据链（软著申请、专利答辩等场景）。
triggers:
  - 同步会话
  - 会话存档
  - transcript sync
  - 对话记录同步
  - 证据链
  - 过程追溯
  - 开发过程记录
  - transcript backup
  - 会话备份
  - 同步 transcript
---

# Transcript Sync — 对话记录自动同步 Skill

## 适用场景

- 需要为软件著作权、发明专利申请保留完整的开发过程证据链
- 需要追溯某个设计决策的原始对话上下文
- 团队评审时需要引用 AI 辅助开发的完整过程

---

## 1. 初始化流程

当用户说"配置会话同步"或"开启转录同步"时，按以下步骤执行。

### 1.1 发现 Claude 会话存储路径

首先探测当前系统中 Claude Code 的 session 存储位置：

| 平台 | 默认路径 | 检测方法 |
|------|---------|---------|
| **Windows** | `%USERPROFILE%\AppData\Local\Claude\sessions\` | 检查 `~/.claude/sessions/` 或 AppData |
| **macOS** | `~/Library/Application Support/Claude/sessions/` | 检查标准路径 |
| **Linux** | `~/.local/share/Claude/sessions/` | 检查 XDG 数据目录 |

探测完成后，自动查找一个真实的 transcript 文件验证路径可用性：

```bash
# 查找最近的 session 文件（示例逻辑）
find "$SESSION_DIR" -name "*.jsonl" -type f | head -3
```

> 如果找不到 session 目录，让用户手动指定路径。

### 1.2 复制同步脚本

从本 skill 的 `templates/` 复制 `sync-transcripts.sh` 到项目的 `scripts/`：

```bash
mkdir -p {project-root}/scripts
cp {skill-path}/templates/sync-transcripts.sh {project-root}/scripts/sync-transcripts.sh
chmod +x {project-root}/scripts/sync-transcripts.sh
```

### 1.3 注册 Hook

读取项目 `.claude/settings.local.json`，如果没有则从模板创建。

**需要保持的已有配置：** `permissions`, `autoMemoryDirectory`, `outputStyle`, `mcpServers` 等不变。

**需要添加/合并的 hooks 段：**

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PROJECT_DIR}/scripts/sync-transcripts.sh\"",
            "timeout": 30
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PROJECT_DIR}/scripts/sync-transcripts.sh\"",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

**合并策略：**
1. 如果 `settings.local.json` 不存在 → 创建完整文件（含 hooks + 现有权限配置）
2. 如果存在但不含 hooks 段 → 追加 hooks
3. 如果已含 hooks 段 → 提示用户确认是否覆盖（避免覆盖自定义 hook）

### 1.4 创建 transcripts 目录

```bash
mkdir -p {project-root}/transcripts
```

可选：添加 `.gitignore` 条目（如果 transcripts 目录不需要全部纳入版本控制，但作为证据链建议纳入）。

### 1.5 验证配置

```bash
# 1. 检查脚本是否存在且可执行
ls -la scripts/sync-transcripts.sh

# 2. 检查 settings.local.json 中 hooks 段已注册
grep -A 3 "sync-transcripts" .claude/settings.local.json

# 3. 手动触发一次同步验证
# (下次提交 prompt 时 hook 会自动触发)
```

### 1.6 初始化完成摘要

```
## ✅ 会话同步配置完成

### 已配置
- scripts/sync-transcripts.sh —— 同步脚本
- .claude/settings.local.json —— hooks 注册（UserPromptSubmit + Stop）
- transcripts/ —— 会话存档目录

### 验证方式
下次提交 prompt 后，检查 transcripts/ 下是否会生成新的会话目录。
也可以查看 Claude 返回中的 systemMessage: "[sync-transcripts] OK: ..."
```

---

## 2. 故障排查

| 问题 | 原因 | 修复 |
|------|------|------|
| 同步脚本找不到 transcript 文件 | session 路径配置不对 | 在 settings.local.json 中确认 hook 是否能收到 stdin JSON |
| transcripts 目录为空 | hook 未触发或脚本执行失败 | 检查 settings.local.json hooks 段语法，手动运行脚本测试 |
| 出现 stray transcript 目录（子目录下） | 某次 hook 的 cwd 传成了子目录 | 脚本已有自动清理逻辑，检查下次同步时的清理消息 |
| Windows 路径格式错误 | 路径未正确归一化 | 确认 normalized_path 函数覆盖了当前路径格式 |

---

## 3. 提交策略

> transcripts 目录中的会话文件是开发过程的原始证据链，应与代码变更一并纳入版本控制。

**每次涉及代码或内容提交时，顺带提交 transcripts 目录下的变更：**

```bash
# 正常提交代码时，同时包含 transcripts 变更
git add .  # 或 git add src/ design/ transcripts/ ...
git commit -m "xxx"
```

**原因：**
- 代码变更 + 对应会话存档 = 完整的"为什么这么改"的证据链
- 单个 transcript 文件很小（通常几十 KB），不会显著膨胀仓库
- 后续如需追溯某个设计决策的原始对话，提交记录中就能找到对应的 session

**不推荐的策略：**
- ❌ 单独为 transcripts 建仓库（管理成本高）
- ❌ 用 `.gitignore` 忽略 transcripts（丢失证据链）
- ❌ 等所有开发完成再统一提交 transcripts（丢失时序关联）

> 本 skill 的 hook 仅负责 **同步**（将 session 文件从 Claude 缓存复制到项目目录），不涉及 **提交**（git commit）。
> 提交由开发者在每次代码变更时顺带执行，保持证据链与代码变更的时间对齐。

## 4. 本 skill 的迭代说明

**迭代-发布周期：**
1. 在本项目 `.claude/skills/transcript-sync/` 中修改本文件和模板
2. 稳定后复制到 `~/.agents/skills/transcript-sync/` 全局发布

**更新原则：**
- 同步脚本逻辑优化 → 更新 `templates/sync-transcripts.sh`
- 配置流程优化 → 更新本 SKILL.md
- 跨平台兼容 → 测试 Windows/macOS/Linux 后更新 SKILL.md 中的路径检测
