---
name: entity-relationship
version: 2.0.0
description: |
  实体关系图（ER 图）设计技能——使用 er-viewer.html + data/*.js 模式
  进行实体定义、关系设计、字段约束设定，生成带力导向/网格布局的交互式 SVG 文档。
  本技能 v2 新增：完整设计过程定义、实体提取方法论、可迭代执行计划、流水线关联。
triggers:
  - ER 图
  - 实体关系
  - 实体设计
  - 关系设计
  - 数据建模
  - 数据库设计
  - 字段定义
  - 领域建模
  - entity relationship
  - 数据模型
  - 表结构
  - schema 设计
---

# Entity Relationship (ER) Design

本技能封装了 `er-viewer.html` + `data/*.js` 的完整工具链。
所有模板文件内置在技能的 `templates/` 目录下，无需依赖外部项目。

## 本技能规则

| # | 规则 | 说明 |
|---|------|------|
| 1 | **不重复定义** | 每个实体只在归属域定义一次，其他域通过 `cross_domain` 引用。`core-er.js` 汇总所有跨域关系 |
| 2 | **结构化数据优先** | ER 数据以 JS 文件为唯一权威源，`er-viewer.html` 只是渲染层 |
| 3 | **单一渲染器** | 所有领域共用 `er-viewer.html`（`?domain=XX` 单域 / `?domain=all` 全景），零外部依赖 |
| 4 | **域注册表同步** | 开工前先读取 `design/domain-registry.js`，改领域边界时必须先写注册表（development-standard §5.3） |
| 5 | **决策可追溯** | 每次设计操作前，将原始输入原文追加到 `design/01-raw-input/{domain-slug}.md` |
| 6 | **实体粒度由业务决定** | 不强设数量上限，核心字段优先在主视图显示，其余折叠为 "+N fields" |
| 7 | **CHANGELOG 必写** | 每次变更后在 `design/03-entity-relationship/data/CHANGELOG.md` 记录 |

---

## 1. 设计流程总览

实体关系设计遵循 **"5 步法"**流水线：

```
输入源                         处理步骤                         输出
┌──────────────────┐          ┌──────────────┐              ┌──────────────┐
│ 业务工作流数据     │          │ 1. 输入采集与  │              │ data/XX.js   │
│ data/*.js         │ ───────→ │    需求理解    │              │（JSON 数据源） │
│（业务流程+状态机） │          │              │              │ 包含：        │
├──────────────────┤          │ 2. 实体提取    │ ───────────→ │ - entities  │
│ 原始需求讨论记录   │ ───────→ │   （从业务描述  │              │   (字段+约束) │
│ raw-input/        │          │    中识别      │              │ - relations │
│（"人""事""对象"） │          │    实体要素）   │              │   (关系定义)  │
├──────────────────┤          │              │              │              │
│ 已有 ER 数据文件  │ ───────→ │ 3. 关系识别    │              │ er-viewer    │
│（迭代基线）       │          │   + 字段约束   │              │ .html        │
├──────────────────┤          │              │              │（SVG 渲染器）  │
│ 业务领域描述      │ ───────→ │ 4. 输出生成    │              │              │
│（终端输入）       │          │              │              │ core-er.js   │
├──────────────────┤          │ 5. 迭代验证    │              │（跨域关系）    │
│ API 设计文档      │ ───────→ │              │              └──────────────┘
│（回推验证）       │          └──────────────┘
└──────────────────┘
```

**每次被调用时，skill 必须先输出执行计划与用户确认，然后再开始执行。**

---

## 2. 输入规格

### 2.1 输入来源（按优先级排序）

| 优先级 | 输入来源 | 路径/方式 | 为什么需要 |
|--------|---------|----------|-----------|
| **P0 — 必需** | **业务工作流数据** | `design/02-business-workflow/data/XX-slug.js` | **这是实体提取的主要来源**——业务流程中涉及的"人"（角色）、"事"（操作记录）、"对象"（业务实体）本身就是实体定义的原始素材 |
| **P0 — 必需** | **原始需求讨论记录** | `design/01-raw-input/XX.md` | 提供原始的业务描述，其中包含自然语言表达的实体、属性和关系 |
| **P1 — 推荐** | **终端文字输入** | 对话方式分块输入 | 当需求文档不全时，通过对话补充业务描述，从中提取实体 |
| **P2 — 参考** | **API 设计文档** | `design/04-platform-api/domains/XX-api.md` | 回推验证：API 请求/响应的字段反向验证实体定义是否完整 |
| **P3 — 迭代** | **已有 ER 数据文件** | `data/XX-slug.js` | 当需要迭代更新时作为基线文件 |

### 2.2 关键输入与实体的映射关系

| 业务描述中的元素 | 映射为 ER 中的什么 | 示例（通用，实际替换为业务对应物） |
|----------------|-------------------|------|
| **角色**（用户、管理员、成员、访客） | 实体（Entity） | `User`, `Staff`, `Member` |
| **业务对象**（商品、订单、项目、文章） | 实体（Entity） | `Product`, `Order`, `Project`, `Article` |
| **业务记录**（审核记录、操作日志、支付流水） | 实体（Entity） | `AuditLog`, `PaymentTransaction`, `ApprovalRecord` |
| **属性**（名称、价格、状态、描述） | 字段（Field） | `order.status`, `product.price`, `user.email` |
| **关联**（属于、包含、持有、创建） | 关系（Relation） | `Order` 1:N `OrderItem` |
| **状态**（draft/active/suspended） | 字段 + 枚举 | `Order.status` → `enum('pending','paid','shipped','cancelled')` |
| **引用**（指向其他实体的标识） | 外键（FK） | `order.user_id` → FK `user.id` |

---

## 3. 设计过程（5 步法）

### 步骤 1：输入采集与需求理解

**目标：** 收集所有相关输入，全面理解业务领域的实体要素。

1. **识别并读取输入源：**
   - **首先读取域注册表 `design/domain-registry.js`**（development-standard skill §5.3），获取当前领域 slug 列表。后续的 `{domain-slug}` 参数以此为准
   - 读取该领域的**业务工作流数据**（主要实体来源）
   - 读取该领域的**原始需求讨论记录**（如有）
   - 如果用户通过终端描述，解析自然语言输入
   - 如果有已有 ER 数据文件，作为迭代基线

2. **从业务工作流中提取实体要素：**
   - 阅读每一个 section 中的业务描述，识别"操作者"、"操作对象"、"操作记录"
   - 阅读 flowchart 中的节点标签，识别业务流程中出现的业务实体
   - 阅读状态转换表，确定业务对象的状态枚举
   - 找出跨 section/跨 flowchart 重复出现的概念——这些很可能就是实体

3. **存档原始输入：**
   将本次读取/接收到的所有输入来源信息追加到 `design/01-raw-input/{domain-slug}.md`：
   - 业务工作流数据：记录工作流文件名和关键实体候选
   - 原始需求记录：记录文档路径和关键段落
   - 终端输入：记录对话原文
   - 每条记录标注 `YYYY-MM-DD HH:mm` 时间戳

4. **输出需求理解摘要：**
   向用户总结：基于对工作流和需求的理解，初步识别出哪些潜在实体，并请求确认。

### 步骤 2：实体提取（核心步骤）

**目标：** 从业务描述中系统地提取实体定义。

#### 2.1 实体识别规则

| 识别线索 | 示例（通用，实际替换为业务对应物） | 是否实体 |
|---------|------|---------|
| 业务描述中的**名词** | "用户提交订单" → `User`, `Order` | ✅ 是 |
| **有状态的对象** | "订单有 paid/shipped/cancelled 状态" → `Order` | ✅ 是 |
| **需要存储记录的操作** | "记录每次登录行为" → `LoginRecord` | ✅ 是 |
| **多对多关系的连接** | "用户属于多个组织" → `UserOrganizationMembership` | ✅ 是 |
| **单纯的属性值** | "用户的手机号" → 不是独立实体，是字段 | ❌ 否 |
| **单纯的统计值** | "订单总数" → 不是独立实体，是派生值 | ❌ 否 |
| **外键引用** | "订单引用用户 ID" → `User`（已在其他域定义） | ⚠️ 跨域引用 |

#### 2.2 实体粒度控制

| 粒度原则 | 说明 |
|---------|------|
| **实体粒度由业务决定** | 不要为了凑数而强行拆分或合并实体。实体数量和字段数量由业务逻辑自然决定，设计不应预设数量上限 |
| **核心字段优先显示** | 最常用的核心字段在主视图中显示，其余字段折叠到详情中 "+N fields"。具体展示多少个由设计者根据业务场景定，视图层面只做折叠处理 |
| **能独立存在且有状态的才是实体** | 不要为每个属性建实体，不要为纯查询结果建实体 |
| **关联实体才有必要求** | 如果 A 和 B 是多对多关系，需要一个中间实体 |

#### 2.3 实体定义内容

每个实体必须定义：

| 字段 | 说明 | 来源 |
|------|------|------|
| `id` | 实体标识，snake_case | 按命名规范 |
| `name` | 中文名 | 业务中的通用称呼 |
| `table` | 数据库表名 | 按命名规范（复数 snake_case） |
| `description` | 实体说明 | 从业务描述中提炼 |
| `fields` | 字段列表 | 从业务属性中提取（参见下方字段定义） |

#### 2.4 字段定义规则

| 维度 | 规则 | 示例 |
|------|------|------|
| **命名** | snake_case，全小写 | `created_at`, `login_user_id` |
| **类型** | 精确的数据类型 | `varchar(64)`, `integer`, `datetime`, `decimal(10,2)`, `enum('a','b')` |
| **主键** | 标注 pk=true | 每个实体必须有 pk |
| **非空** | 必填字段标注 nn=true | 业务上必有的字段 |
| **唯一** | 唯一约束标注 uq=true | 需要唯一索引的字段 |
| **外键** | 标注 fk="目标实体.字段" | `fk="venue.id"` |
| **说明** | 必须写清楚业务含义 | 不要写"名称"而要写"俱乐部全称（工商注册名）" |
| **来源** | 标注 source="工作流节点id.outputs.字段"——该字段对应的业务操作来源 | `source="select_seat.outputs.seat_id"` |
| **消费者** | 标注 consumers=["api:端点路径", ...]——哪些 API 消费了该字段 | `consumers=["api:GET_available_seats", "api:POST_orders"]` |

> `source` 和 `consumers` 为可选字段（初始设计时可能无法确定），但 §8.9 和复查阶段必须检查：无 source/consumers 的字段标记为 ⚠️ untraced。

### 步骤 3：关系识别与字段约束

**目标：** 定义实体之间的关系，完善字段级约束。

#### 3.1 关系识别规则

从业务描述中识别关系：

| 业务描述 | 关系类型 | ER 中的表示 |
|---------|---------|------------|
| "一个分类包含多个商品" | 1:N | `Category` 1:N `Product` |
| "一个订单包含多个订单项" | 1:N | `Order` 1:N `OrderItem` |
| "一个用户可以有多个角色" | M:N | `User` M:N `Role`（通过 `UserRole`） |
| "一张票对应一个座位" | 1:1 | `Ticket` 1:1 `Seat` |

#### 3.2 基数判断标准

| 数量词 | 基数 | 示例 |
|--------|------|------|
| "一个 x 有**一个** y" | 1:1 | 一个用户 → 一个实名认证记录 |
| "一个 x 有**多个** y" | 1:N | 一个分类 → 多个商品 |
| "多个 x 属于**一个** y" | N:1 | 多个订单项 → 属于一个订单 |
| "x 可以有**多个** y，y 也可以有**多个** x" | M:N | 用户 ↔ 角色（通过中间表） |

#### 3.3 跨域关系处理

当关系涉及不同领域时：
- 该关系在**源域**的 `relations` 数组中定义
- 标注 `cross_domain` 为目标域编号
- 目标域的实体在渲染时自动显示为橙色虚线 ghost 节点
- **实体只在归属域定义一次**，其他域通过 cross_domain 引用
- 跨域关系同时在 `core-er.js` 的 `core_relations` 中汇总

### 步骤 4：输出生成

**目标：** 将实体和关系数据写入文件。

#### 4.1 单域文件生成

```
File: data/{domain-slug}.js（{domain-slug} 从域注册表获取）
├── entities[]      — 实体定义
│   ├── id          — 唯一标识
│   ├── name        — 中文名
│   ├── table       — 数据库表名
│   ├── description — 说明
│   └── fields[]    — 字段列表（name/type/pk/nn/uq/fk/desc/comment/default）
├── relations[]    — 关系定义
│   ├── from        — 源端 "实体.字段"
│   ├── to          — 目标端 "实体.字段"
│   ├── type        — 基数 1:1 / 1:N / N:1 / M:N
│   ├── desc        — 关系描述
│   └── cross_domain — 跨域时填目标域编号
```

#### 4.2 跨域总纲文件生成

`core-er.js` 汇总所有域的跨域关系。每新增或修改跨域关系时同步更新此文件。

#### 4.3 与 viewer 的同步

每次数据文件变更后：
1. 更新 `er-viewer.html` 中的内联数据（使 `er-viewer.html?domain=XX` 可直接查看）
2. 更新 `er-viewer.html` 中的内联数据（`?domain=all` 全景图反映最新关系）

### 步骤 5：迭代验证

**目标：** 根据用户反馈持续更新 ER 设计。

1. **存档修正输入：** 按步骤 1 的存档规则（追加到 `design/01-raw-input/{domain-slug}.md`，标注时间戳），将用户的修正意见原文存档。

2. **域注册表同步：** 如果在设计过程中发现需要调整领域边界（新增/合并/拆分/重命名领域），**必须按 development-standard skill §5.3 的规则操作：先更新 `design/domain-registry.js`，再更新本数据文件和 `core-er.js`**。不允许先改自己的数据再考虑是否更新注册表

3. **增量修改：** 用户提出修正后定位到对应的实体或关系
4. **局部更新：** 只修改受影响的字段或关系，不重写整个文件
5. **同步更新：** 修改后同步到 `er-viewer.html`（`?domain=all` 全景 + 单域视图）
6. **从反馈中提取：** 用户的新描述可能引入新实体或新关系——及时识别并补充
7. **版本控制友好：** 由于数据文件是 JS 文本格式，每一次修改的 diff 清晰可见

---

## 4. 输出格式（精确 Schema）

> 以下定义输出数据文件的精确格式。所有输出必须严格遵循此 schema。

### 4.1 文件级结构

```javascript
window.ER_DATA = window.ER_DATA || {};
window.ER_DATA["slug-matching-filename"] = {
  "domain":      string,     // 领域编号，如 "05"
  "title":       string,     // 领域中文名
  "slug":        string,     // URL slug，kebab-case
  "description": string,     // 领域描述
  "entities":    Entity[],   // 实体列表
  "relations":   Relation[]  // 关系列表
};
```

### 4.2 Entity 结构

```jsonc
{
  "id":          string,    // 实体唯一标识（snake_case，如 "order_item"）
  "name":        string,    // 实体中文名（如 "用户"、"订单"）
  "table":       string,    // 数据库表名（如 "order_items"）
  "description": string,    // 实体说明
  "fields":      Field[]    // 字段列表
}
```

### 4.3 Field 结构

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `name` | string | 是 | 字段名（snake_case） |
| `type` | string | 是 | 数据类型（`UUID`, `varchar(64)`, `integer`, `datetime`, `text`, `boolean`, `json`, `decimal(5,2)`, `enum(...)`） |
| `pk` | bool | 否 | 是否主键 |
| `nn` | bool | 否 | 是否 NOT NULL |
| `uq` | bool | 否 | 是否 UNIQUE |
| `fk` | string | 否 | 外键引用 `"目标实体.字段"`，如 `"venue.id"` |
| `desc` | string | 是 | 字段说明（简短，表格中显示） |
| `comment` | string | 否 | 详细注释（灰色小字，在详情面板 `desc` 下方渲染，解释业务含义） |
| `default` | string | 否 | 插入时无值的默认值 |
| `source` | string | 否 | 追溯标记：该字段对应的业务来源，格式 `"workflow:{node_id}.outputs.{field}"` |
| `consumers` | string[] | 否 | 追溯标记：消费该字段的 API 列表，格式 `["api:{method} {path}", ...]` |

### 4.4 Relation 结构

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `from` | string | 是 | 源端 `"实体.字段"` |
| `to` | string | 是 | 目标端 `"实体.字段"` |
| `type` | string | 是 | 基数：`"1:1"`, `"1:N"`, `"N:1"`, `"M:N"` |
| `desc` | string | 是 | 关系描述 |
| `cross_domain` | string | 否 | 跨域时指定目标域编号，如 `"02"` |

### 4.5 core-er.js 结构

```javascript
window.ER_DATA = window.ER_DATA || {};
window.ER_DATA["core-er"] = {
  "domains": [
    { "domain": "01", "title": "用户系统", "slug": "user-auth", "description": "...", "color": "#2563eb" }
  ],
  "core_relations": [
    { "from": "category.id", "to": "product.category_id", "type": "1:N", "desc": "分类包含多个商品", "domains": ["02", "03"] }
  ]
};
```

### 4.6 loader.js 结构

```javascript
(function() {
  var files = [
    "01-user-auth",
    "02-schedule",
    "03-ticketing",
    "core-er"
  ];
  files.forEach(function(f) {
    document.write('<script src="data/' + f + '.js"><\/script>');
  });
})();
```

---

## 5. 跨域关系设计规则

- **每个实体只在归属域的 JS 文件中定义一次**，其他域通过 `cross_domain` 引用
- 跨域关系在**源域**的 `relations` 数组中标注 `cross_domain` 为目标域编号
- 跨域关系的对应的目标实体在渲染时自动显示为橙色虚线框的 ghost 节点
- `core-er.js` 中的 `core_relations` 是跨域 + 域内关系的全集，用于全景图渲染
- 域内关系连线为蓝色实线（混色），跨域关系为橙色虚线

## 6. 完成检查清单

| 检查项 | 要求 |
|--------|------|
| 实体粒度合理 | 实体由业务逻辑决定，不强行拆分也不强行合并 |
| 字段显示合理 | 核心字段优先在主视图显示，其余折叠为 "+N fields" |
| 字段类型精确 | 使用精确数据类型，如 `varchar(64)` 而非 `string` |
| 关系基数已标注 | 每个 relation 明确了 1:1 / 1:N / N:1 / M:N |
| 跨域关系已处理 | 涉及其他域的实体标注了 `cross_domain` |
| core-er 已同步 | 所有跨域关系已在 `core-er.js` 中汇总 |
| 渲染已验证 | `er-viewer.html?domain=XX` 能正确渲染 |
| 全景图已验证 | `er-viewer.html?domain=all` 能正确显示跨域关系 |
| 与工作流一致 | 实体覆盖了工作流中出现的所有核心业务对象 |
| 与 API 设计一致 | 实体的字段覆盖了 API 请求/响应的核心数据 |
| 字段追溯已标注 | 核心业务字段的 `source` 和 `consumers` 是否已填写（可为空数组，不可缺失）；无标注的字段在复查中标记 ⚠️ untraced |
| 反向验证通过 | 从至少一个 API 响应字段反推 → ER 字段 → 工作流节点 → 原始需求，全链可追溯 |

## 7. 首次搭建（新项目）

按序执行以下步骤。

### 步骤 1：创建目录结构

```bash
mkdir -p {project}/design/03-entity-relationship/data
```

### 步骤 2：复制渲染器

```bash
cp ~/.agents/skills/entity-relationship/templates/er-viewer.html \
   {project}/design/03-entity-relationship/
```

`er-viewer.html` 是纯渲染引擎（力导向/网格布局 + 贝塞尔曲线路由 + 避障通道选择），零项目依赖。**不要修改此文件。**

### 步骤 3：创建数据入口

```bash
cp ~/.agents/skills/entity-relationship/templates/loader.js \
   {project}/design/03-entity-relationship/data/
```

编辑 `data/loader.js`，在 `files` 数组中列出所有域文件名（不含 `.js` 后缀）：

```javascript
var files = [
  "01-user-auth",
  "02-schedule",
  "03-ticketing",
  "core-er"
];
```

### 步骤 4：为每个域创建数据文件

```bash
cp ~/.agents/skills/entity-relationship/templates/example-entity-domain.js \
   {project}/design/03-entity-relationship/data/01-first-domain.js
```

编辑文件：修改 `ER_DATA["key"]` 的 key 值（必须与文件名一致），然后填充 entities 和 relations。

### 步骤 5：创建跨域关系总纲

```bash
cp ~/.agents/skills/entity-relationship/templates/core-er.js \
   {project}/design/03-entity-relationship/data/
```

编辑 `core-er.js`，列出所有域和跨域关系。

## 8. 编辑已有域

1. 找到 `data/XX-slug.js`
2. 编辑 `entities` 数组（增删实体、字段、关系）
3. 编辑 `relations` 数组（增删关系、更新跨域标记）
4. 无需任何构建步骤，浏览器打开 `er-viewer.html` 或 `er-viewer.html?domain=XX` 验证

## 9. CHANGELOG 规范

每次设计变更后，必须在 `data/` 目录下创建或更新 `CHANGELOG.md` 文件，记录本次变更内容，便于审核追溯。

**存放位置：** `design/03-entity-relationship/data/CHANGELOG.md`

**CHANGELOG 格式：**

```markdown
# ER 设计变更说明 v{旧版本} → v{新版本}

> {变更概要说明}
> 日期：{YYYY-MM-DD}

---

## 变更 1：{变更标题}

**类型**：{新增实体|字段调整|关系修改|跨域引用变更|Bug 修复|...}
**来源**：{变更的触发原因——用户反馈、工作流变更、API 回推验证等}

### 变更内容

| 之前 | 之后 |
|------|------|
| {修改前状态} | {修改后状态} |

### 理由
- {为什么做这个变更}

---

## 涉及的实体 / 关系

- `{entity_id}`：{涉及的内容摘要}
- `{relation_id}`：{关系变更摘要}
```

**记录要求：**

| 规则 | 说明 |
|------|------|
| **版本号** | 每次变更递增版本号（v1→v2→v3→...），与设计迭代对应 |
| **每次变更一条记录** | 同一次迭代中的多个变更点分列多个"变更 N"条目 |
| **变更类型明确** | 标注本次变更属于实体/字段/关系/跨域引用等 |
| **来源可追溯** | 说明变更的触发原因——用户反馈、工作流变更、API 回推验证等 |
| **涉及实体标注** | 列出本次变更影响到的实体和关系，便于定位 |

## 10. 渲染器特性

| 特性 | 说明 |
|------|------|
| **双模式合一** | 单域详情的网格布局 + 跨域全景的域容器布局，通过下拉菜单或 `?domain=all`/`?domain=XX` 切换 |
| **自动避障路由** | 实体间连接使用二次贝塞尔曲线，控制点落在行间隙通道中心，自动绕开其他实体卡片 |
| **通道车道分配** | 同一列间隙的多条曲线通过车道计数器错开 10px，避免曲线重叠 |
| **路径碰撞规避** | 后绘制的曲线自动检测并避开先绘曲线的控制点区域 |
| **往返射线箭头** | 箭头沿曲线末端切线方向，方向由控制点→终点决定 |
| **关联关系面板** | 点击实体弹出字段详情和关联关系列表 |
| **ghost 节点** | 跨域引用实体以橙色虚线框 + 🔗 标记显示，点击跳转目标域 |
| **pan/zoom** | 鼠标拖拽平移 + 滚轮缩放 |

## 11. 设计原则

- **JSON 优先**：结构化数据可被 AI 精确 diff 和验证
- **单一渲染器**：所有领域共用 `er-viewer.html`，样式统一，维护成本低
- **不重复定义**：每个 entity 只在归属域定义，关系引用即可
- **零外部依赖**：纯 HTML+CSS+SVG，不依赖任何第三方 JS 库
- **零构建步骤**：数据文件是 `.js` 而非 `.json`，浏览器直接加载
- **版本控制友好**：JS 文本可 diff，SVG 文本可 diff
- **每个域至少包含一个流程图**——流程图是业务设计最直观的表达
- **核心字段优先展示，其余折叠**——实体卡片中核心字段在主视图显示，超出部分折叠为 "+N 个字段，点击查看详情"
- **关系基数必须标注**（1:1 / 1:N / N:1），位于连线中点标签
- **跨域引用必须标注 `cross_domain`**，否则 ghost 节点不会出现
- **实体从业务工作流中提取**——先有工作流设计，才有 ER 设计
- **必须先出计划再执行**——每次调用先输出步骤计划，用户确认后开始
- **与 API 设计背靠背校验**——ER 中的字段应覆盖 API 请求/响应的核心数据

---

## 11. 一致性检查模式——与工作流对照

本模式检查 ER 实体定义与上游业务工作流之间的一致性。这是 ER 设计步骤**唯一需要执行的检查**——确保实体覆盖了工作流中出现的核心业务对象，字段覆盖了业务流程所需的数据。

> **职责边界：** ER→ORM 的一致性检查不在此执行。该检查属于 `api-code-gen` skill 的实现阶段（前置检查 + 后置检查），因为只有在代码实现时才需要对照 ORM 代码——这是实现步骤的责任，不是设计步骤的。

### 输入规格

| 输入 | 来源 | 说明 |
|------|------|------|
| ER 数据文件 | `design/03-entity-relationship/data/*.js` | 当前 ER 定义 |
| 业务工作流数据 | `design/02-business-workflow/data/*.js` | 上游工作流 |
| 域注册表 | `design/domain-registry.js` | 领域 slug 定义 |

### 检查步骤

1. **实体覆盖检查**：工作流中出现的业务对象是否在 ER 中有对应实体
2. **状态一致性检查**：工作流状态机中定义的状态枚举与 ER 实体字段的 enum 定义是否一致
3. **角色覆盖检查**：工作流中定义的角色是否在 ER 中有对应实体或字段

### 输出格式

> 输出格式遵循共享规范：`.claude/skills/_shared/consistency-check-format.md`。
> 本 skill 的 `type` 枚举：`missing_entity`, `missing_field`, `status_mismatch`, `role_not_mapped`。
> 本 skill 的 `source` 枚举：`workflow-to-er`, `er-to-api`。

```json
{
  "summary": {
    "workflows_checked": 0,
    "entities_in_er": 0,
    "total_issues": 0
  },
  "issues": [
    {
      "severity": "high",
      "type": "missing_entity",
      "detail": "...",
      "suggestion": "..."
    }
  ]
}
```
