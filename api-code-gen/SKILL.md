---
name: api-code-gen
version: 2.0.0
description: |
  服务端代码生成与一致性检查——覆盖 development-standard §8.6「API 代码实现」全部 7 个子步骤：
  前置检查（ER→ORM gap + API→代码 gap）→ 代码生成（Controller/DTO/Service + ORM Model）→
  数据库迁移 → 业务逻辑实现 → 测试验证 → 后置一致性检查 → 修复循环。
  一次性生成全部代码，避免分步生成导致的编译失败。
  注：本技能与技术框架无关（ASP.NET / Express / FastAPI / Spring 等均适用），
  只定义代码生成的通用原则。
triggers:
  - API 代码生成
  - API 实现
  - 服务端代码
  - 后端代码生成
  - API code generation
  - API 一致性检查
  - API 实现检查
  - ORM 代码生成
  - 数据库迁移
  - 实体类生成
  - API 代码实现
  - 后端实现
  - 服务端实现
---

# api-code-gen — 服务端代码生成与一致性检查

## 技能说明

- **所属流水线：** `development-standard` §8.6「API 代码实现」
- **覆盖范围：** 本 skill 覆盖 §8.6 全部 7 个子步骤，不需要额外调用其他 skill
- **输入源：**
  - `design/04-platform-api/domains/{slug}-api.md`（API 设计文档）
  - `design/03-entity-relationship/data/{slug}.js`（ER 数据）
  - `design/04-platform-api/backend-architecture/data/*.js`（后端架构设计——L2+ 项目必读，L1 项目可忽略）
- **输出目录：** `src/server/`（遵循 development-standard §5.2.1 三层结构规则）
- **具体的目标框架由项目 CLAUDE.md 定义**（如 ASP.NET Core / Express / FastAPI / Spring），本技能只描述通用生成原则

---

## 0. 核心原则：设计即代码，零兼容冗余

**本技能生成的代码永远只反映当前设计。不保留、不兼容、不迁就旧设计。**

| 场景 | 做法 |
|------|------|
| API/ORM 设计有变更 | 旧字段/旧表直接删除，旧路由直接替换，不保留 `[Obsolete]` 或注释掉的代码 |
| 设计删除了实体/字段/端点 | 代码中对应删除，不保留"以后可能有用"的死代码 |
| 设计字段改名/改类型 | 旧字段直接删除，新字段直接上，不保留两套字段或同步逻辑 |
| 数据需要迁移 | 通过 EF Core Migration 或独立迁移脚本解决，不在代码层做兼容 |
| 线上运行环境 | 同样适用——只做数据迁移不做代码兼容，干净的代码是唯一的真相来源 |

> **反例：** 设计把 `Fighter.Weight` 改成了 `Fighter.WeightClass`，于是同时保留两个字段、加一段同步逻辑 → **错误。**
> **正例：** 删除 `Weight` 字段，新增 `WeightClass` 字段，通过 Migration 迁移数据，代码中只有 `WeightClass`。

### 0.1 枚举强制原则

**所有具备离散值域的业务概念，必须定义为 C# enum 类型，严禁在代码中以 `string` 替代。**

| 规则 | 说明 |
|------|------|
| **实体/DTO 属性用 enum，不用 string** | `public OrderStatus OrderStatus { get; set; }` ✅ / `public string OrderStatus { get; set; }` ❌ |
| **比较/赋值用 enum 值，不用字符串字面量** | `if (order.OrderStatus == OrderStatus.Paid)` ✅ / `if (order.OrderStatus == "paid")` ❌ |
| **EF Core 存储用 `HasConversion<string>()`** | DB 存 TEXT（可读），C# 代码层强类型。在 `ConfigureConventions` 中全局注册所有 enum 类型 |
| **JSON 序列化用 `JsonStringEnumConverter`** | API 输出 snake_case 字符串（如 `"pending_payment"`），C# 代码中始终是枚举值 |
| **`Enum.Parse` / `Enum.TryParse` 不使用 `ignoreCase: true`** | 严格 PascalCase 匹配。API 层的字符串→枚举转换由 `JsonStringEnumConverter` 自动完成，业务代码不应绕开 |
| **严禁 `.ToString().ToLower()` 等手动转换** | 枚举→字符串的序列化交给 `JsonStringEnumConverter`，不允许在 Controller/Service 中手动拼字符串 |
| **枚举文件名与类型名一致** | 文件 `OrderStatus.cs` 包含 `enum OrderStatus`，不允许文件名与类型名不同 |
| **枚举文件一类型一文件** | 每个枚举类型独立一个 `.cs` 文件，不把多个枚举塞进同一个文件（如 `CompetitionScheduleEnums.cs` 仅作为历史遗留保留，新枚举禁止放入） |

> **反例：** `AdmissionPass.cs:15` 定义 `public string Status { get; set; } = "pending"`，然后 `CheckinController.cs` 里写 `if (pass.Status == "cancelled")`。
> 一旦拼错 `"cancelled"` → `"canceld"`，编译器不报错，运行时才发现。
>
> **正例：** 实体属性 `public AdmissionPassStatus Status { get; set; } = AdmissionPassStatus.Pending`，
> 控制器里 `if (pass.Status == AdmissionPassStatus.Cancelled)`。拼错立即红波浪线。

**代码生成检查清单（枚举）：**

- [ ] 所有 ER 中定义为 `enum('a','b')` 的字段，在 C# 中有对应 `enum` 类型
- [ ] 实体属性使用 enum 类型，默认值使用 `EnumType.Value` 格式
- [ ] DTO 属性使用 enum 类型（非 `string`）
- [ ] Controller/Service 中无字符串字面量比较（`== "pending"` 等）
- [ ] 无 `.ToString().ToLower()` / `.ToString().ToUpper()` 手动转换
- [ ] `Enum.Parse` 无 `ignoreCase: true` 参数
- [ ] DbContext `ConfigureConventions` 中已注册所有 enum 类型的 `HasConversion<string>()`
- [ ] `Program.cs` 中已配置 `JsonStringEnumConverter`

---

## 1. 完整执行流程（§8.6 七步流水线）

> **铁律：** 每一步必须严格按序执行，不可跳过。后置检查发现差异必须回到步骤 2 修复，
> 循环直到测试全绿 + 一致性检查零差异。

### 1.1 前置检查

**目标：** 在生成/修改代码之前，先了解当前代码与设计资产之间的差距。

#### 1.1.1 ER→ORM Gap 分析

| 检查维度 | 内容 |
|---------|------|
| **实体→类映射** | ER 中的每个 entity，在 Models 目录中查找同名类（entity.id → PascalCase 类名）。标记 ER 中有但 Models 中缺失的实体，以及 Models 中有但 ER 中无定义的类（可能是代码临时添加的未设计实体） |
| **字段→属性映射** | 对每个已找到的实体-类对，逐字段检查：字段名对应（snake_case → PascalCase）、类型兼容（varchar(128) ↔ `string`，bigint ↔ `long`，datetime ↔ `DateTime`）、非空约束一致（nn=true ↔ `[Required]` 或 nullable 标记）、唯一约束一致（uq=true ↔ `[Index(IsUnique=true)]`） |
| **关系→导航属性** | ER 中的 relation 对照 Model 类中的导航属性：1:N 关系源端应有 `ICollection<T>`、1:1 关系两端互相引用、M:N 关系需要中间类、FK 字段应在 Model 中定义外键属性 + `[ForeignKey]` 标注 |
| **表名映射** | ER 中定义的 table 名 ↔ Model 类的 `[Table("name")]` 注解 |

#### 1.1.2 API→代码 Gap 分析

- 读取 API 设计文档中的每个 endpoint，检查代码中是否有对应路由注册
- 检查现有 Controller 的方法签名是否与设计文档一致

#### 1.1.3 后端架构→代码 Gap 分析（L2+ 项目）

> 如果项目复杂度 < L2 或架构设计资产不存在，跳过本步骤。

| 检查维度 | 内容 |
|---------|------|
| **分层一致性** | 对照 `layering-strategy.js`，检查 Controller 是否只做协议适配（无业务逻辑）、Domain Service 是否无 Infrastructure 依赖、Repository 是否通过接口被调用 |
| **模块边界一致性** | 对照 `module-boundaries.js`，检查是否存在跨域直接查表、跨模块循环依赖、禁止依赖被突破 |
| **缓存策略一致性** | 对照 `caching-strategy.js`，检查缓存实现（Redis/内存/HTTP）是否匹配设计、TTL 和失效策略是否一致 |
| **幂等策略一致性** | 对照 `resilience-policy.js` 的 `idempotency.requiredEndpoints`，检查对应 Controller Action 是否实现了 Idempotency-Key 校验 |
| **健康检查** | 检查 `/api/v1/health` 端点是否存在，健康检查覆盖项是否与 `observability-policy.js` 一致 |
| **配置与安全** | 检查数据库连接串、Redis 连接、外部 API Key 是否从配置/Secret 读取（无硬编码），敏感字段是否脱敏 |

#### 1.1.4 追溯链 Gap 分析

| 检查维度 | 内容 |
|---------|------|
| **API 端点追溯** | 检查每个 API 设计文档中的 endpoint 是否填写了 `consumes` / `produces` 字段。未填写者标记为 ⚠️ 警告——该端点缺少上游/下游追溯，可能导致数据流不可追踪 |
| **ER 字段追溯** | 检查每个 ER 实体字段是否填写了 `source` / `consumers` 字段。未填写者标记为 ⚠️ 警告——该字段缺少数据来源/消费者追溯 |
| **追溯链完整性** | 验证 `consumes` → `produces` → `page_input` 全链字段匹配。若 API consumes 引用了不存在的 workflow 输出节点，或 produces 与下游 page_input 不匹配，标记为 🔴 严重断裂——**拒绝生成代码**，必须先行修复追溯链 |

**输出：** 结构化 gap 报告，每个 issue 含：严重度 / 类型 / 差距描述 / 修复方向。

---

### 1.2 代码生成（一次性全量）

**目标：** 从设计资产一次性生成全部代码骨架，避免分步生成导致编译失败。

> **为什么必须一次性生成：** Controller 引用 DTO，Service 引用 Model。如果先生成 Controller 不生成 Model，
> 项目无法编译，静态检查工具（IDE、linter、编译器）无法工作。一次性生成保证代码始终处于可编译状态。

> **架构约束驱动生成（L2+）：** 如果 `backend-architecture/data/` 下存在架构设计资产，代码生成必须遵守以下硬约束：
> - Controller 只生成参数绑定和 `IActionResult` 返回，不包含任何业务判断
> - Application Service 接口 + 实现类按 `module-boundaries.js` 的 `exposes` 生成
> - Domain Service 生成为纯函数，不含任何 Infrastructure 引用
> - Infrastructure 类（Redis/Cache/MessageQueue/ExternalClient）只通过接口暴露
> - 健康检查端点按 `observability-policy.js` 的配置生成
> - 幂等端点按 `resilience-policy.js` 的 `idempotency.requiredEndpoints` 生成 Idempotency-Key 校验

#### 1.2.1 从 API 设计生成

1. **读取 API 设计文档**：解析所有 endpoint 定义（URL、Method、请求参数、响应格式、错误场景）
2. **生成路由处理**：为每个 endpoint 生成路由注册 + HTTP 方法绑定代码
3. **生成输入验证**：路径参数 / 查询参数 / 请求体的类型定义和校验
4. **生成响应模型**：每个端点的正常响应和错误响应结构
5. **生成业务逻辑骨架**：Service 层接口（前置条件→执行→后置效果）
6. **生成追溯注释 — Controller Action**：每个 Controller Action 方法上方生成 `/// <trace consumes="workflow:{node_id}.outputs.{field}" produces="page:{page_id}.page_input.{param}" />` 注释，标记该端点消费和产出的追溯信息
7. **生成追溯注释 — DTO 属性**：每个 DTO 属性上方生成 `/// <trace source="er:{entity}.{field}" />` 注释，标记该属性的数据来源

**生成原则：**
- 代码只依赖 API 设计文档中的契约，不预设业务实现细节
- 输入校验应与设计文档中的参数约束一致（必填/类型/长度/枚举值）
- 错误响应覆盖设计文档中列出的所有错误场景

#### 1.2.2 从 ER 数据生成 ORM 模型

这是本 skill 最关键的代码生成能力——从 ER 结构化数据直接生成 EF Core 实体类。

**输入：** `design/03-entity-relationship/data/{slug}.js`（ER 数据文件）

**生成范围：**

| ER 元素 | 生成目标 | 说明 |
|---------|---------|------|
| `entity.id` | PascalCase 类名 | `competition` → `Competition` |
| `entity.table` | `[Table("name")]` 注解 | `competitions` → `[Table("competitions")]` |
| `entity.fields[].name` | PascalCase 属性名 | `created_at` → `CreatedAt` |
| `entity.fields[].type` | C# 类型映射 | 见下方类型映射表 |
| `entity.fields[].pk` | `[Key]` 注解 | pk=true → `[Key]` |
| `entity.fields[].nn` | `[Required]` 或非 nullable | nn=true → `[Required]` |
| `entity.fields[].uq` | `[Index(IsUnique=true)]` | uq=true → 唯一索引 |
| `entity.fields[].fk` | `[ForeignKey("NavProp")]` | 外键属性 + 导航属性 |
| `entity.relations[]` | 导航属性 | 见下方关系映射表 |

**ER 类型 → C# 类型映射：**

| ER type | C# type | 备注 |
|---------|---------|------|
| `UUID` | `Guid` | — |
| `varchar(N)` | `string` | `[MaxLength(N)]` 或 `[StringLength(N)]` |
| `text` | `string` | — |
| `integer` / `int` | `int` | — |
| `bigint` | `long` | — |
| `boolean` / `bool` | `bool` | — |
| `datetime` | `DateTime` | — |
| `date` | `DateOnly` | .NET 6+ |
| `decimal(M,D)` | `decimal` | `[Column(TypeName = "decimal(M,D)")]` |
| `json` | `string` 或 `JsonDocument` | 视业务需要 |
| `enum('a','b')` | 生成 C# enum 类型 | `public enum XxxStatus { A, B }` |

**ER 关系 → C# 导航属性映射：**

| ER type | 源端 | 目标端 |
|---------|------|--------|
| `1:1` | `public TargetType TargetType { get; set; }` | `public SourceType SourceType { get; set; }` |
| `1:N` | `public ICollection<TargetType> TargetTypes { get; set; }` | `public Guid SourceTypeId { get; set; }` + `public SourceType SourceType { get; set; }` |
| `N:1` | `public Guid TargetTypeId { get; set; }` + `public TargetType TargetType { get; set; }` | `public ICollection<SourceType> SourceTypes { get; set; }` |
| `M:N` | 生成中间 join 实体类 + 两端各 `ICollection<T>` | 中间类含两个 FK + 两个导航属性 |

**DbContext 生成：**
- 为每个域生成对应的 `DbSet<T>` 属性
- 在 `OnModelCreating` 中配置关系（Fluent API）、索引、复合主键
- 跨域关系的实体，在 DbContext 中以 ghost 注释标注来源域

---

### 1.3 数据库迁移

> **铁律：** ORM 代码变更后必须执行数据库迁移，否则运行时 DB 与代码不一致。见 development-standard §10.3 硬约束规则 4 和 5。

**执行步骤：**

```
dotnet ef migrations add <MigrationName>
dotnet ef database update
```

**迁移命名规范：** 使用描述性名称，如 `AddCompetitionEntity`、`UpdateVenueFields`、`AddFighterNavigationProps`。

**前置条件守卫：** 执行迁移前确认项目编译通过（`dotnet build` 成功）。

---

### 1.4 业务逻辑实现

**目标：** 填充 Service 层实现，使 TDD 测试通过。

- 实现 Service 接口中每个方法的前置条件校验→执行→后置效果
- 每个方法的实现必须对照 API 设计文档中的"前置条件/执行步骤/后置效果"
- 状态机转换逻辑必须对照业务工作流中的状态转换表

---

### 1.5 测试验证

```
dotnet test
```

- 所有测试必须全部通过（绿色）
- 测试失败时的处理链：
  - 测试代码问题 → 修正测试
  - API 实现问题 → 修正实现
  - API 设计问题 → 回溯 `api-design` skill
  - 业务流程问题 → 回溯 `business-workflow` skill

---

### 1.6 后置一致性检查

**目标：** 验证生成的代码与设计资产完全对齐。这是进入收敛判定的前置条件。

#### 1.6.1 ER→ORM 一致性检查

使用与 §1.1.1 完全相同的四个维度（实体→类、字段→属性、关系→导航属性、表名映射）重新检查。生成后应**零差异**——若有差异，回到 §1.2 修复。

#### 1.6.2 API 设计→代码一致性检查

| 检查维度 | 内容 |
|---------|------|
| **路由一致性** | 每个设计中的 endpoint（URL+Method）→ 代码中的路由注册 |
| **参数一致性** | 设计中的请求参数 → 代码中的参数定义（缺、多余、类型不匹配） |
| **响应结构一致性** | 设计中的响应格式 → 代码中的返回结构 |
| **错误码覆盖** | 设计中列出的错误场景 → 代码中是否有处理 |
| **权限标注** | 设计中的权限要求 → 代码中的鉴权机制 |
| **枚举使用合规** | 全量扫描代码，检查是否存在：实体/DTO 使用 `string` 承载枚举值、`== "字符串"` 比较、`.ToString().ToLower()` 手动转换、`Enum.Parse` 带 `ignoreCase: true`。详见 §0.1 |
| **追溯一致性** | API 代码中的 @trace consumes/produces 注释与设计文档中的 consumes/produces 声明是否一致 |
| **后端架构合规（L2+）** | 对照 `backend-architecture/data/` 下的架构设计资产，检查：分层约束是否被遵守（Controller 无业务逻辑、Domain Service 无 Infrastructure 依赖）、模块边界是否被突破（跨域直接查表、禁止依赖被突破）、缓存实现是否匹配策略、幂等端点是否全部实现 Idempotency-Key 校验、健康检查端点是否存在、审计日志是否接入、配置是否无硬编码 |

---

### 1.7 修复循环

```
后置检查发现差异
    │
    ├── 差异类型：缺失类/字段/路由
    │     └── 回到步骤 1.2 补充生成
    │
    ├── 差异类型：类型不匹配 / 约束不一致
    │     └── 回到步骤 1.2 修正生成
    │
    └── 差异类型：API 契约偏差
          └── 回到步骤 1.2 修复 → 重新测试 → 重新检查

循环终止条件：dotnet test 全绿 + 后置一致性检查零差异
```

---

## 2. 一致性检查模式（独立调用）

本 skill 的一致性检查模式支持两种独立触发方式：

### 2.1 作为独立检查

对 Claude 说：
- "使用 api-code-gen 检查 {domain-slug} 的 API 代码与设计一致性"
- "使用 api-code-gen 检查 ER 与 ORM 模型的一致性"
- "使用 api-code-gen 检查 {domain-slug} 的代码与后端架构一致性"

### 2.2 被 review 调度

`review` skill 在以下维度中委托本技能执行检查：

| 委托维度 | 内容 |
|---------|------|
| API 设计 → API 代码 | 路由/参数/DTO/错误码一致性 |
| ER → ORM | 实体→类、字段→属性、关系→导航属性一致性 |
| 后端架构 → API 代码 | 分层合规/模块边界/缓存实现/幂等实现/健康检查/配置安全（由 `backend-architecture-design` 提供检查逻辑，本 skill 执行代码层比对） |

### 2.3 结构化输出格式

> 输出格式遵循共享规范：`.claude/skills/_shared/consistency-check-format.md`。
> 本 skill 的 `type` 枚举：`missing_route`, `param_mismatch`, `response_mismatch`, `error_not_handled`, `permission_missing`, `missing_class`, `extra_class`, `field_missing`, `type_mismatch`, `constraint_mismatch`, `relation_mismatch`, `table_name_mismatch`, `layer_violation`, `boundary_breach`, `cache_mismatch`, `idempotency_missing`, `health_check_missing`, `audit_log_missing`, `trace_inconsistency`。
> 本 skill 的 `source` 枚举：`api`, `orm`, `architecture`。

```json
{
  "summary": {
    "total_issues": 0,
    "api_issues": 0,
    "orm_issues": 0,
    "entities_in_er": 0,
    "classes_in_code": 0,
    "matched_entities": 0
  },
  "issues": [
    {
      "severity": "high",
      "type": "missing_route",
      "source": "api",
      "detail": "...",
      "suggestion": "..."
    }
  ]
}
```

---

## 3. 使用方式

1. **完整 §8.6 执行**：对 Claude 说"使用 api-code-gen 实现 {domain-slug} 的 API 代码"
2. **前置检查**：对 Claude 说"使用 api-code-gen 检查 {domain-slug} 的代码与设计 gap"
3. **一致性检查**：对 Claude 说"使用 api-code-gen 检查 {domain-slug} 的代码与设计一致性"
4. **仅 ORM 检查**：对 Claude 说"使用 api-code-gen 检查 ER 与 ORM 模型的一致性"
5. **被 review 调用**：review skill 在 API 代码一致性 + ER→ORM 维度中自动委托本技能

---

## 4. 域注册表同步

`{domain-slug}` 和 `{slug}` 参数从 `design/domain-registry.js` 获取。领域边界调整时按 development-standard §5.3 规则操作。

---

## 5. CHANGELOG 规范

每次代码生成或变更后，在 `src/server/` 目录下更新 `CHANGELOG.md`。

---

## 6. 完成检查清单

| 检查项 | 要求 |
|--------|------|
| ER→ORM 前置 gap 分析已完成 | 生成前已知晓当前代码与 ER 的差距 |
| Controller 已生成 | 所有 API endpoint 有对应路由 |
| DTO 已生成 | 请求参数/体有对应类型定义 |
| ORM Model 已生成 | ER 中所有实体在 Models 中有对应类 |
| DbContext 已更新 | 所有 DbSet + Fluent API 配置就绪 |
| 导航属性已生成 | 所有 ER 关系在 Model 中有对应导航属性 |
| 数据库迁移已执行 | `dotnet ef database update` 完成 |
| 业务逻辑已实现 | Service 层方法已填充 |
| 测试全绿 | `dotnet test` 全部通过 |
| 后置 API 一致性检查通过 | 路由/参数/DTO/错误码与设计一致 |
| 后置 ER→ORM 一致性检查通过 | 实体/字段/关系/表名与 ER 完全对齐 |
| **后置架构合规检查通过（L2+）** | 分层约束/模块边界/缓存/幂等/健康检查/审计日志/配置安全与架构设计一致 |
| **入口无测试感知** | 生产入口文件无 `if (isTest)` / `Environment("Testing")` 等分支；数据库连接串等生产配置仅来自配置文件，不含测试专用配置键 |
| **上游追溯字段已验证** | API consumes/produces 和 ER source/consumers 是否已填写 |
| **生成代码已标注 @trace 注释** | 每个 Controller Action 和 DTO 属性是否有追溯标记 |
| **追溯链无断裂** | 验证 consumes→produces→page_input 全链字段匹配 |

---

## 7. 与相关技能的关系

| 技能 | 关系 |
|------|------|
| `api-design` | 上游——提供 API 设计文档 |
| `backend-architecture-design` | 上游——提供后端架构设计（分层/模块边界/缓存/可靠性/可观测性/安全策略），代码生成时作为架构约束。L2+ 项目必读 |
| `entity-relationship` | 上游——提供 ER 数据作为 ORM 模型来源 |
| `tdd-build` | 协同——生成的代码需通过 tdd-build 设计的测试；TDD 设计文档 + 测试代码为验收标准。**注意：** tdd-build §2.1.1 要求测试通过 DI 拦截替换数据库，因此 api-code-gen 生成的生产入口代码不得包含测试/生产分支逻辑，不得定义测试专用配置键 |
| `tdd-execute` | 验收——代码生成完成后由 tdd-execute 执行全量测试验证 |
| `business-workflow` | 上游——业务工作流提供状态机和业务规则，Service 层实现时参照 |
| `mobile-code-gen` | 协同——前端 API 调用需与后端端点对齐 |
| `desktop-code-gen` | 协同——前端 API 调用需与后端端点对齐 |
| `review` | 调度——review 委托本技能做 API 代码一致性检查 + ER→ORM 一致性检查 |
