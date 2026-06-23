# My Skills — Reasonix AI Agent Skills

个人 Reasonix AI 编码助手的技能库。每个技能对应一个专业领域，AI 在匹配到触发词时自动加载执行。

## 技能清单

### 编排
| 技能 | 说明 |
|------|------|
| `iterate` | 功能迭代 + Bug 修复的统一级联编排器。覆盖"加功能"到"修问题"的全部变更场景，以同步螺旋协议为核心 |

### 设计
| 技能 | 说明 |
|------|------|
| `business-workflow` | 业务梳理与流程设计（工作流、状态机） |
| `entity-relationship` | 实体关系图设计与数据建模 |
| `api-design` | REST API 契约设计 |
| `backend-architecture-design` | 后端架构与服务体系设计 |
| `mobile-app-design` | 移动端/小程序页面功能设计 |
| `desktop-ui-design` | 桌面/Web 端页面功能设计 |

### 验证
| 技能 | 说明 |
|------|------|
| `tdd-build` | TDD 测试设计与编码 |
| `tdd-execute` | TDD 测试执行与验证 |
| `review` | 多维度全项目复查与一致性校核 |

### 实现
| 技能 | 说明 |
|------|------|
| `api-code-gen` | 服务端代码生成与一致性检查 |
| `mobile-code-gen` | 移动端/小程序代码生成 |
| `desktop-code-gen` | 桌面/Web 端代码生成 |

### 基础
| 技能 | 说明 |
|------|------|
| `development-standard` | SFDS v1 单人全栈开发标准（方法论全文 + 项目初始化） |
| `transcript-sync` | 对话记录自动同步到项目 |
| `consolidate-raw-input` | 原始输入整合归档 |

### 其他
| 技能 | 说明 |
|------|------|
| `b2c-webdav` | Salesforce B2C Commerce WebDAV 文件管理 |
| `brain-ops` | 思考与知识管理操作 |

> ⚠️ `diagnose` 已升级为 `iterate` 的路径 B（诊断修复模式），保留此为向后兼容入口。

## 目录结构

```
~/.agents/skills/
├── README.md
├── iterate/
│   └── SKILL.md
├── business-workflow/
│   ├── SKILL.md
│   └── templates/
│       ├── loader.js
│       ├── example-domain.js
│       └── workflow-viewer.html
├── entity-relationship/
│   ├── SKILL.md
│   └── templates/
│       ├── er-viewer.html
│       ├── loader.js
│       ├── core-er.js
│       └── example-entity-domain.js
└── ...
```

每个技能目录至少包含一个 `SKILL.md`（技能定义），可选包含 `templates/`（模板文件）或 `scripts/`（辅助脚本）。

## 使用方式

这些技能由 [Reasonix](https://github.com/clarknu/my-skills) AI 编码助手自动加载。在对话中说出触发词（如"设计工作流"、"加一个字段"、"排查 bug"），AI 会自动匹配并执行对应技能。

## 技能开发

每个 `SKILL.md` 遵循 Reasonix skill 格式：

```markdown
---
name: skill-name
description: 一句话描述
---

# Skill: skill-name

## 适用场景
...

## 工作流程
...
```

## 许可

个人使用。
