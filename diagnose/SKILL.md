# Skill: diagnose — 诊断修复（旧入口，已委托给 iterate）

> ⚠️ **本 skill 已升级为 `iterate` skill 的路径 B（诊断修复模式）。**
> 保留此入口仅为向后兼容——所有调用会自动委托给 `iterate`。

---

## 委托规则

当用户通过 `/diagnose` 或触发词"诊断、bug、问题排查、根因分析"调用本 skill 时：

1. **立即加载 `iterate` skill**（`~/.agents/skills/iterate/SKILL.md`）
2. 以 **路径 B：诊断修复** 模式执行
3. 本 skill 不再包含独立的工作流程定义

---

## 为什么升级

原 `diagnose` skill 的核心机制（追溯→级联）被证明同样适用于功能迭代场景。
新的 `iterate` skill 将"修 bug"和"加功能"统一为两条路径 + 一个共享级联引擎，
避免了机制重复，同时让功能迭代首次获得了结构化的级联编排能力。

详见 `iterate` skill 的完整定义。
