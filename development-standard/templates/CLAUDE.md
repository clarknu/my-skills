# {{project-name}}

{{project-description}}

> **开发标准**：本项目遵循单人全栈开发标准 v1（`.claude/skills/development-standard/SKILL.md`）。
> 设计原则、代码规范、流程约定等全部方法论由标准文档定义，不再在本文件重复。

---

## 项目概况

| 维度 | 说明 |
|------|------|
| **目标用户** | {{target-users}} |
| **运行环境** | {{environment}} |
| **技术栈** | {{tech-stack}} |
| **技术栈状态** | {{tech-stack-note}} |

## 领域定义

本平台业务领域定义见 [`design/domain-registry.js`](design/domain-registry.js)——域注册表文件，
在初始域范围界定阶段创建初版，随流水线执行持续演进，为各步骤提供 `{domain-slug}` 参数。
