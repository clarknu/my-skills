---
name: api-design
version: 2.0.0
description: |
  API 设计技能——遵循"流水线步骤4"方法论，将业务工作流和实体关系图转化为
  完整的 API 设计数据。每个领域输出一个 JS 数据文件（data/XX-slug.js），
  通过 api-viewer.html 提供交互式 HTML 查阅体验。
  v2 升级：输出格式从 Markdown 迁移至 HTML Viewer 模式，与其他设计技能统一。
triggers:
  - API 设计
  - API 端点
  - 接口设计
  - REST API
  - 路由设计
  - 端点设计
  - 控制器设计
  - 请求响应
  - api contract
  - API 契约
  - 接口定义
  - 路由规划
---

# API Design

本技能定义了 API 设计的完整方法论：从输入采集到逐端点详设，再到迭代修正。
输出是项目 `design/04-platform-api/data/` 下的领域 JS 数据文件，通过 `design/04-platform-api/api-viewer.html` 提供交互式查阅。

## 本技能规则

| # | 规则 | 说明 |
|---|------|------|
| 1 | **契约先行** | API 设计文档是前后端和 TDD 的核心合约。合约定稿后实现，实现必须通过测试验证。每个端点穷尽 6 个维度（前置条件→执行步骤→后置效果→状态机→副作用→关联 API） |
| 2 | **与 ER 一致性** | API 的请求参数、响应字段、枚举值必须与 ER 图中的实体定义一致 |
| 3 | **域注册表同步** | 开工前先读取 `design/domain-registry.js`，改领域边界时必须先写注册表（development-standard §5.3） |
| 4 | **决策可追溯** | 每次设计操作前，将原始输入原文追加到 `design/01-raw-input/{domain-slug}.md` |
| 5 | **错误可预期** | 每个端点明确列出 3-6 个典型错误场景（状态码 + error_code + 触发条件） |
| 6 | **CHANGELOG 必写** | 每次变更后在 `design/04-platform-api/CHANGELOG.md` 记录 |
| 7 | **权限点映射** | 每个端点标注对应权限点 id（引用 business-workflow）。**只做映射，不定义新权限点**；缺失时反推 business-workflow 补充。详见 §3.0 |

---

## 1. 设计流程总览

API 设计遵循 **"5 步法"**流水线，每一步有明确的输入、处理和产出。

```
输入源                         处理步骤                         输出
┌────────────┐                ┌──────────────┐              ┌──────────────┐
│ 业务工作流   │ ─────────────→ │ 1. 输入采集与  │              │ 每个领域一个    │
│ data/*.js   │  业务流程+状态   │    需求理解    │              │ JS 数据文件    │
├────────────┤                │              │              │ domains/     │
│ ER 实体关系  │ ─────────────→ │ 2. 实体→路由   │ ───────────→ │ XX-xxx-api.md│
│ data/*.js   │  实体+字段+关系  │    映射识别    │              │              │
├────────────┤                │              │              │              │
│ 原始需求记录  │ ─────────────→ │ 3. 逐端点详设   │              │              │
│ raw-input/  │  业务场景+规则   │   (核心步骤)   │              │              │
├────────────┤                │              │              │              │
│ 现有 API    │ ─────────────→ │ 4. 文档输出    │              │              │
│ 设计文档     │  迭代基线       │              │              │              │
└────────────┘                │ 5. 迭代验证    │              └──────────────┘
                              └──────────────┘
```

**每次被调用时，skill 必须先输出执行计划与用户确认，然后再开始执行。**

---

## 2. 输入规格

| 输入 | 来源路径 | 必需程度 | 说明 |
|------|---------|---------|------|
| **业务工作流数据** | `design/02-business-workflow/data/XX-slug.js` | ★★★ 必选 | 提供业务流程步骤、状态机、业务规则、角色操作——API 端点的业务需求来源 |
| **实体关系数据** | `design/03-entity-relationship/data/XX-slug.js` | ★★★ 必选 | 提供实体、字段、关系——API 请求/响应结构的字段来源 |
| **原始需求讨论记录** | `design/01-raw-input/` | ★★☆ 可选 | 原始业务场景描述、约束条件、设计决策依据 |
| **现有 API 设计数据** | `design/04-platform-api/data/XX-slug.js` | ★★☆ 可选 | 迭代基线，保留已有内容并增量修改 |
| **设计总纲** | `design/04-platform-api/design-master.md` | ★★☆ 可选 | 路由命名规范、权限体系、公共约定（错误码、幂等性等） |
| **API 设计模板** | `design/04-platform-api/api-design-template.md` | ★☆☆ 可选 | 输出文档的标准结构模板 |
| **终端对话** | 用户直接输入 | ★☆☆ 可选 | 用户通过命令行/对话框直接输入需求描述，skill 实时理解并纳入设计 |

> 文档读取、终端对话、分块输入均为支持的输入方式。分块输入时每块到达后处理并迭代补充。

---

## 3. 设计过程（5 步法）

### 步骤 1：输入采集与需求理解

**输入：** 工作流数据、ER 数据、原始需求
**处理：**

1. **读取域注册表 `design/domain-registry.js`**（development-standard skill §5.3），获取当前领域 slug 列表。路径中的 `{domain-slug}` 参数以此为准

2. 读取业务工作流数据，理解：
   - 业务中有哪些角色（用户/管理员/成员/客服）
   - 业务流程的执行步骤和顺序
   - 状态机转换（哪些状态、什么条件触发）
   - 业务规则的约束条件
   - 异常流程和边界情况

3. 读取 ER 实体关系数据，理解：
   - 业务领域涉及哪些实体
   - 实体之间的关联关系
   - 每个实体的核心字段和类型
   - 跨域关系的引用链

4. 阅读原始需求记录（如有），补充：
   - 业务场景描述和用户故事
   - 设计决策的历史背景
   - 非功能性需求（频率、延迟、并发）

5. **存档原始输入：**
   将本次读取/接收到的所有输入来源信息追加到 `design/01-raw-input/{domain-slug}.md`：
   - 工作流数据来源 + 关键流程摘要
   - ER 数据来源 + 关键实体列表
   - 原始需求记录 + 关键场景
   - 终端输入的对话原文
   - 每条记录标注 `YYYY-MM-DD HH:mm` 时间戳

### 步骤 2：实体到路由的映射识别

**处理：** 将业务需求转化为 API 端点列表。

| 映射规则 | 说明 | 示例 |
|---------|------|------|
| **实体 CRUD** | 每个核心实体产生一组 CRUD 端点 | `Article` → `GET /articles`, `GET /articles/{id}`, `PUT /articles/{id}` |
| **状态机操作** | 每个状态转换对应一个动作端点 | `publish` 操作 → `POST /articles/{id}/publish` |
| **关系操作** | 实体间关系产生关联端点 | `Article` ↔ `Category` → `GET /articles/{id}/category` |
| **个人视图** | 涉及"当前用户"的用 `/me` | 个人档案 → `GET /fighters/me`, `PUT /fighters/me` |
| **文件上传** | 文件作为父实体的子资源 | 头像 → `POST /fighters/me/avatar/presigned-url` |
| **公开查询** | 公开数据使用公开 GET | 赛事列表 → `GET /competitions` |
| **管理视图** | 运营管理使用 `Staff*` 权限 | 全局订单 → `GET /orders` [StaffOrderManage] |

**产出：** 一个路由-端点映射表（方法、路径、权限、功能摘要）

其中「权限」列引用 business-workflow 中定义的权限点 id（如 `ArticlePublish`）。如果某个端点找不到对应权限点，标记为待补充并反推 business-workflow。

### 步骤 3：逐端点详设（核心步骤）

这是最关键的步骤。对步骤 2 识别出的每个端点，按照 `api-design-template.md` 的要求逐项填充。

#### 3.0 权限点映射（先于 3.1~3.7）

> **⚠️ API 设计不定义新权限点。** 权限点的唯一定义源是 business-workflow。API 设计阶段只做一件事：把已有的权限点与 API 端点对应起来。如果发现权限点缺失，反推 business-workflow 补充——不在 API 设计文档中自行新增。

在详设每个端点之前，先确定其权限控制关系：

1. **读取权限点清单：** 从 `design/02-business-workflow/data/{domain-slug}.js` 的 `permissions` 数组中读取该领域的权限点列表
2. **逐端点匹配：** 对步骤 2 识别出的每个端点，找到控制它的权限点 id
   - CRUD 端点通常 4 个操作各对应一个权限点（如 `ArticleView` / `ArticleCreate` / `ArticleEdit` / `ArticleDelete`）
   - 状态机操作端点对应触发该状态转换的权限点
   - 公开端点（无权限控制）标注为 `public`
3. **缺失处理：** 如果某个端点找不到对应权限点：
   - 先反推 business-workflow：该领域是否漏了功能点？
   - 如果确认是 business-workflow 遗漏 → 先回去补充权限点，再继续 API 详设
   - 如果权限归属存在歧义 → 提示用户仲裁（如"文章编辑是否应与删除共用 ArticleEdit？还是拆为 ArticleDelete？"）

每个端点的权限点标注格式：在端点路由表行中增加权限列，值如 `ArticleEdit` 或 `public`。

#### 3.1 业务逻辑说明

必须覆盖以下 6 个维度：

| 维度 | 填写要求 | 信息从哪里来 |
|------|---------|------------|
| **前置条件** | 调用前业务状态和数据必须满足的条件 | 工作流中的约束规则、状态机的前置状态 |
| **执行步骤** | API 内部的关键业务处理步骤（用 ①→②→③ 编号） | 工作流中的处理步骤、业务规则 |
| **后置效果** | 调用成功后数据如何变化 | 状态机的目标状态、工作流中的产出 |
| **状态机影响** | 涉及哪些字段的状态转换 | 工作流中的状态定义 |
| **副作用** | 触发哪些次要操作（通知、日志、WebSocket 推送） | 需求描述中的隐性要求、工作流中的分支 |
| **关联 API** | 该 API 在上下游链路中的其他接口 | 流程顺序、实体关系 |

#### 3.2 请求参数定义

| 参数类型 | 填写要求 | 信息从哪里来 |
|---------|---------|------------|
| **Path Parameters** | `{param_name}` 在路径中标注，表格定义类型/必填/含义/约束/示例 | ER 中对应实体 ID 字段的类型和约束 |
| **Query Parameters** | GET 端点的过滤/分页/搜索参数 | 工作流中的查询场景、列表需求 |
| **Request Body** | POST/PUT/PATCH 的请求体字段 | ER 中对应实体的字段列表、约束条件 |

每个参数的约束必须明确：长度限制、取值范围、格式要求、必填条件。

#### 3.3 响应格式定义

| 内容 | 填写要求 |
|------|---------|
| **JSON 示例** | 完整的成功响应 JSON，包含 `code/message/data/request_id` |
| **字段说明表** | 对 `data` 下的每个字段说明类型和含义 |
| **不同场景** | 不同业务状态下的响应差异（如已登录 vs 未登录、有票 vs 无票） |
| **分页格式** | 列表查询遵循设计总纲的分页格式 |

#### 3.4 错误场景

每个端点列出 **3-6 个最可能的错误场景**：

| 列 | 填写要求 |
|----|---------|
| HTTP 状态码 | 400/401/403/404/409/429/500 |
| error_code | 优先使用设计总纲 §4.1.2 通用错误码，本域特有码用 43xxx/45xxx |
| 触发条件 | 具体什么情况下触发该错误 |
| 说明 | 用户友好的错误说明 |

#### 3.5 幂等性标注

| 方法 | 默认幂等性 | 说明 |
|------|-----------|------|
| GET/PUT/DELETE | 天然幂等 | 标注 "是" |
| POST | 视语义 | 创建类不幂等，支付/退款等关键操作标注强制使用 Idempotency-Key |
| PATCH | 视语义 | 使用版本号/If-Match 可达成幂等 |

#### 3.6 缓存策略（仅 GET）

| 数据类型 | 默认策略 | 说明 |
|---------|---------|------|
| 公开数据 | HTTP 缓存 + TTL | 标注缓存方式、TTL、失效条件 |
| 用户私有数据 | 不缓存 | Cache-Control: no-store |
| 配置类数据 | Redis 缓存 | 标注缓存键规则和失效条件 |

#### 3.7 频率限制

仅当该端点的频控与设计总纲默认值不同时标注。

### 步骤 4：文档输出

**输出格式：** 每个领域一个 JS 数据文件，放在 `design/04-platform-api/data/XX-slug.js`。

数据文件挂载到全局命名空间 `window.API_DATA[slug]`，由 `api-viewer.html` 加载渲染为交互式 HTML 页面。

**基础设施（不随领域变更）：**

| 文件 | 职责 |
|------|------|
| `design/04-platform-api/api-viewer.html` | HTML 查看器——工具栏+左侧导航+右侧端点卡片 |
| `design/04-platform-api/data/loader.js` | 数据加载器——加载所有领域 JS 数据文件 + 工作流权限字典 |

**查看方式：** 浏览器直接双击打开 `api-viewer.html`（file:// 协议即可，无需 HTTP 服务器）。

**归档约定：** 当原始 MD 设计文档的内容已被完整迁移到 JS 数据文件后，将 MD 文件移入 `design/04-platform-api/_archived/` 目录。

---

#### 4.1 数据文件完整结构（以域 01 为例）

```js
window.API_DATA = window.API_DATA || {};
window.API_DATA["01-user-identity-permission"] = {
  // ═══ 元信息 ═══
  "domain": "01",
  "title": "用户系统、身份认证与权限",
  "slug": "user-identity-permission",
  "description": "平台所有用户的身份认证、JWT 鉴权、实名认证、角色管理和权限控制。",
  "last_updated": "2026-06-19",
  "workflow_ref": "../../02-business-workflow/data/01-user-identity-permission.js",
  "er_ref": "../../03-entity-relationship/data/01-user-identity-permission.js",

  // ═══ 权限名备用查找表 ═══
  // 从 business-workflow 复制本域权限点的 name。
  // api-viewer.html 优先从 WF_DATA 获取完整名称+描述；
  // 当 WF 数据未加载时（如 file:// 打开跨目录受限），用此表兜底。
  "_permission_lookup": {
    "StaffReview": "审核运营人员",
    "UserListView": "查看用户列表",
    "RoleManage": "角色管理"
  },

  // ═══ 领域概述（可选） ═══
  // 遵循 workflow-viewer 的 block 格式：type + 对应字段
  "overview_blocks": [
    {"type":"table","headers":["子域","核心实体","说明"],"rows":[
      ["用户系统","User / Identity / Session","业务用户 ↔ 身份认证 ↔ 会话管理 三层结构"],
      ["身份认证","AuthProvider / AuthSession","外部认证码 → JWT 签发 → refresh → 会话撤销"]
    ]},
    {"type":"note","level":"info","text":"本域额外说明"}
  ],

  // ═══ 关键设计决策（可选） ═══
  "design_decisions": [
    {"title":"RBAC 权限模型","detail":"用户 ↔ 角色（多对多），角色 ↔ 权限（多对多）。不直接给用户分配权限。"}
  ],

  // ═══ 端点分组 ═══
  "sections": [
    {
      "id": "external-auth-session",       // kebab-case，用于目录锚点
      "title": "外部认证会话",            // 显示在左侧目录和内容区标题
      "blocks": [
        {"type":"p","text":"各端统一入口。客户端调用外部认证服务获取临时凭证。"}
      ],
      "endpoints": [
        // ──── 端点 1：完整详设示例 ────
        {
          "method": "POST",
          "path": "/auth/{client_type}/external/session",
          "permission": "public",
          "summary": "外部认证换取 JWT",
          "scenario": "客户端启动时或 Refresh Token 过期后，用户通过外部认证提供商登录平台",

          "business_logic": {
            "preconditions": ["客户端调用外部认证 SDK 获取临时凭证"],
            "steps": [
              "服务端接收凭证，调用外部认证服务的验证接口",
              "以 provider + external_id + client_type 查询认证身份记录",
              "若未找到（新用户）：创建 AuthIdentity → 创建 User",
              "生成 JWT（含 token_version、client_group claim）和 Refresh Token"
            ],
            "post_effects": ["新用户：创建 User（status = pending_registration），签发 JWT"],
            "state_machine": "新用户 → pending_registration；已有用户 → 状态不变",
            "side_effects": ["记录用户登录日志","更新用户最后活跃时间"],
            "related_apis": ["POST /auth/token/refresh — 下游续期","GET /auth/me — 当前用户信息"]
          },

          "path_params": [
            ["{client_type}","string","是","客户端类型","枚举：customer / staff","customer"]
          ],
          "query_params": [],
          "body_params": [
            ["credential","string","是","外部认证返回的临时凭证","长度 1-512 字符","abc123..."],
            ["provider","string","否","认证提供商标识","如 google / github / phone","google"]
          ],

          "responses": [
            {
              "description": "HTTP 200 — 已存在用户或新用户",
              "json": "{\n  \"state\": \"authenticated\",\n  \"token\": \"eyJ...\",\n  \"expires_in\": 7200\n}",
              "fields": [
                ["state","string","登录状态：authenticated / registration_required"],
                ["token","string","JWT Access Token，有效期 7200 秒"],
                ["user.login_user_id","string","登录用户唯一标识"]
              ]
            }
          ],

          "errors": [
            ["400","INVALID_PARAMETER (40001)","client_type 不在枚举范围","参数校验失败"],
            ["502","DEPENDENCY_ERROR (45001)","外部认证服务调用失败","认证服务暂不可用"],
            ["429","RATE_LIMITED (44001)","同一 IP 频繁调用","认证接口限制 10 req/min"]
          ],

          "idempotency": {"is_idempotent":false,"method":"天然不幂等（每次签发不同 token）","retry":"网络超时可直接重试"},
          "caching": {"method":"不缓存","ttl":"—","note":"实时数据"},
          "rate_limit": {"limit":"10 req/min per IP","dimension":"per-IP","note":"认证频控"}
        },

        // ──── 端点 2：最简端点示例 ────
        {
          "method": "GET",
          "path": "/auth/me",
          "permission": "login_required",
          "summary": "当前用户信息",
          "scenario": "小程序启动时查询当前用户的身份、权限和业务档案摘要",
          "idempotency": {"is_idempotent":true},
          "caching": {"method":"不缓存","note":"私有数据"}
        }
      ]
    }
  ],

  // ═══ 附录：权限点清单 ═══
  "permissions": [
    {"id":"StaffReview","name":"审核运营人员","desc":"审核新运营人员提交的实名认证信息","category":"staff_management"}
  ],

  // ═══ 附录：角色定义 ═══
  "roles": [
    {"id":"SystemAdmin","name":"系统管理员","desc":"系统级管理","client_group":"Staff","permission_ids":["StaffReview","RoleManage"]}
  ],

  // ═══ 附录：枚举值表 ═══
  "enums": [
    {"name":"UserStatus","description":"LoginableUser 用户状态枚举","values":[
      ["pendingregistration","待注册","Staff 首次登录后自动创建的初始状态"],
      ["pending_review","待审核","用户已提交身份认证信息，等待管理员审核"],
      ["active","已激活","正常使用状态"],
      ["suspended","已停用","管理员封禁，可恢复"]
    ]}
  ]
};
```

---

#### 4.2 字段速查表

**顶层字段：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `domain` | string | 是 | 领域编号，如 `"01"` |
| `title` | string | 是 | 领域标题，显示在页面 H1 |
| `slug` | string | 是 | 领域 slug，与 domain-registry.js 一致 |
| `description` | string | 是 | 领域一句话描述 |
| `last_updated` | string | 是 | 最后更新日期 `YYYY-MM-DD` |
| `workflow_ref` | string | 是 | 工作流数据文件相对路径（从 api-viewer.html 算起） |
| `er_ref` | string | 是 | ER 数据文件相对路径 |
| `_permission_lookup` | object | 推荐 | `{"权限ID":"权限名称"}` 备用查找表 |
| `overview_blocks` | array | 否 | 领域概述 blocks |
| `design_decisions` | array | 否 | 关键设计决策 |
| `sections` | array | 是 | 端点分组 |
| `permissions` | array | 推荐 | 权限点清单（附录） |
| `roles` | array | 否 | 角色定义（附录） |
| `enums` | array | 推荐 | 枚举值表（附录） |

**端点字段：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `method` | string | 是 | `GET` / `POST` / `PUT` / `DELETE` / `PATCH` / `WSS` |
| `path` | string | 是 | 完整路由路径，path 参数用 `{param}` |
| `permission` | string | 是 | `"public"` / `"login_required"` / 权限点 id |
| `summary` | string | 是 | 一句话功能摘要 |
| `scenario` | string | 推荐 | 使用场景描述 |
| `business_logic` | object | 推荐 | 6 维度业务逻辑（见下文） |
| `path_params` | array | 按需 | Path 参数表，每项 6 元素 |
| `query_params` | array | 按需 | Query 参数表，每项 7 元素 |
| `body_params` | array | 按需 | Body 参数表，每项 6 元素 |
| `responses` | array | 推荐 | 响应示例，每项 `{description, json, fields}` |
| `errors` | array | 推荐 | 错误场景，每项 `[HTTP码, error_code, 触发条件, 说明]` |
| `idempotency` | object | 是 | `{is_idempotent, method, retry}` |
| `caching` | object | 按需 | `{method, ttl, key, invalidation, note}` |
| `rate_limit` | object | 按需 | `{limit, dimension, exceeded, note}` |
| `consumes` | array | 否 | 追溯标记：本端点消费的输入数据来源，格式 `[{source:"workflow:{node_id}.inputs.{field}", param:"query.{param}|body.{field}"}]` |
| `produces` | array | 否 | 追溯标记：本端点产出的数据去向，格式 `[{field:"data.{path}", consumer:"page:{page-id}→{next-page-id}.query.{param}"}]` |

> `consumes` 和 `produces` 为可选追溯字段（见 development-standard §2.6）。初始设计时可为空，§8.9 和复查阶段必须检查：无 consumes/produces 的端点标记 ⚠️ untraced；produces 字段无前端 consumer 标记为 ⚠️ dead_endpoint。

**参数表格式约定：**

| 参数类型 | 每项数组结构 |
|---------|------------|
| path_params | `[参数名, 类型, 必填, 业务含义, 约束/校验, 示例]` |
| query_params | `[参数名, 类型, 必填, 业务含义, 约束/校验, 默认值, 示例]` |
| body_params | `[字段名, 类型, 必填, 业务含义, 约束/校验, 示例]` |

**枚举表格式：** `{"name":"枚举名","description":"说明（可选）","values":[["值","名称","说明"],...]}`

---

#### 4.3 写数据文件时的检查清单

| # | 检查项 | 标准 |
|---|--------|------|
| 1 | `permission` 标注 | 每个端点标注 `"public"` / `"login_required"` / 权限点 id |
| 2 | `idempotency` | 每个端点必须有 `is_idempotent` |
| 3 | `_permission_lookup` | 覆盖本域所有权限点的名称映射 |
| 4 | `enums` | 覆盖本域所有业务枚举（状态、类型等） |
| 5 | 新增领域 | 同步更新 `data/loader.js` 的 `files` 数组 |
| 6 | 归档 | 确认 MD 已入 JS 后，移入 `_archived/` |
| 7 | 跨域端点 | 按业务归属决定放在哪个域 JS，不在两处重复 |
| 8 | 路径参数命名 | 全文件统一使用 `snake_case`（如 `{competition_id}` 而非 `{competitionId}`） |

---

#### 4.4 跨域端点归属规则

某些端点跨越多个领域（如文件上传端点同时涉及文件存储域和父资源域），按以下优先级决定归属：

| 优先级 | 归属规则 | 示例 |
|--------|---------|------|
| 1 | 端点主要服务于哪个领域的业务流程 | 报名补充材料 → 域 02（赛程），而非域 07（文件） |
| 2 | 权限点属于哪个领域 | 使用 `StaffResultManage` 的端点 → 域 02 |
| 3 | 文件上传端点归属父域 | `POST /articles/{id}/cover/presigned-url` → 域 02（内容），而非域 07（文件） |
| 4 | 域 07（文件存储）仅保留资产管理核心 | `GET /assets`、`PATCH /assets/{id}/status`、健康检查 |

> **禁止重复：** 同一个端点不能在多个域的 JS 中重复定义。

### 步骤 5：迭代验证

1. **存档修正输入：** 按步骤 1 的存档规则（追加到 `design/01-raw-input/{domain-slug}.md`，标注时间戳），将用户的修正意见原文存档。

2. **域注册表同步：** 如果发现需要调整领域边界（新增/合并/拆分/重命名领域），**必须按 development-standard skill §5.3 的规则操作：先更新 `design/domain-registry.js`**，再更新 API 文档中的对应领域路径和引用

3. 定位到对应端点，增量更新内容
4. 重新输出完整文档（或 diff 通知用户改了什么）
5. 回到步骤 3 继续细化

**迭代能力要点：**
- 用户可针对特定端点提出修改
- 用户可要求新增端点
- 用户可要求调整参数或响应格式
- skill 应保持上下文，不丢失之前的设计决策

---

## 4. 设计原则

| 原则 | 说明 |
|------|------|
| **领域独立** | 每个领域一个文档，职责边界清晰 |
| **业务驱动** | 端点从业务流程推导，不是凭空设计 |
| **参数完整** | 每个参数必须有类型、约束、示例 |
| **错误可预期** | 每个端点明确列出典型错误场景 |
| **幂等明确** | 调用方需要知道能否安全重试 |
| **缓存显式** | 每个 GET 端点标注缓存策略 |
| **附录完备** | 每个文档末尾有完整的枚举/状态表 |
| **一致性** | 遵循设计总纲的路由命名、错误码、频控规范 |
| **可迭代** | 支持通过终端对话增量修改和补充 |

---

## 5. 输入-输出检查清单

每次设计完成后，对照以下清单检查：

| 检查项 | 判定标准 |
|--------|---------|
| 工作流已读取 | 是否读取了该领域的工作流数据？是否理解了全部流程？ |
| ER 已读取 | 是否读取了该领域的 ER 数据？实体和字段是否与 API 参数对应？ |
| 权限点已映射 | 是否读取了 business-workflow 的 `permissions` 数组？每个端点是否已标注权限点 id？ |
| 路由表完整 | 总纲中的该域端点是否全部分卷中覆盖？ |
| 参数已定义 | 每个端点的 Path/Query/Body 参数表是否完整？ |
| 响应已定义 | 每个端点是否有 JSON 示例和字段说明？ |
| 错误已列出 | 每个端点是否有 3-6 个错误场景？ |
| 幂等已标注 | 每个端点是否标注了幂等性？ |
| 枚举已附录 | 文档末尾是否有完整的枚举/状态值表？ |

## 6. CHANGELOG 规范

每次 API 设计变更后，必须在 `design/04-platform-api/` 下创建或更新 `CHANGELOG.md` 文件，记录本次变更内容，便于审核追溯。

**存放位置：** `design/04-platform-api/CHANGELOG.md`（单文件，所有 API 领域共用）。旧版本 CHANGELOG 归档至 `_archived/`。

**CHANGELOG 格式：**

```markdown
# API 设计变更说明 v{旧版本} → v{新版本}

> {变更概要说明}
> 日期：{YYYY-MM-DD}

---

## 变更 1：{变更标题}

**涉及领域**：{XX-slug}
**类型**：{新增端点|参数调整|响应修改|权限变更|...}
**来源**：{变更的触发原因——用户反馈、业务逻辑变更、ER 变更等}

### 变更内容

| 之前 | 之后 |
|------|------|
| {修改前状态} | {修改后状态} |

### 理由
- {为什么做这个变更}

---

## 涉及的端点

- `{METHOD} /path/to/endpoint`：{变更摘要}
```

**记录要求：**

| 规则 | 说明 |
|------|------|
| **版本号** | 每次变更递增版本号（v1→v2→v3→...），与设计迭代对应 |
| **每次变更一条记录** | 同一次迭代中的多个变更点分列多个"变更 N"条目 |
| **涉及领域标注** | 每个变更标注影响的领域编号，便于按域筛选 |
| **来源可追溯** | 说明变更的触发原因——用户反馈、业务逻辑变更、ER 变更等 |
| **涉及端点标注** | 列出本次变更影响的 API 端点（方法 + 路径） |

---

## 7. 公共约定

以下约定适用于所有领域 API。详情见 `design/04-platform-api/data/_conventions.js`（在 api-viewer.html 中自动渲染为「📐 公共约定」附录）。

### 7.1 通用响应格式

成功响应：`{ code: 0, message: "ok", data: {...}, request_id: "..." }`。
错误响应：`{ code: 4xxxx, message: "...", error_code: "INVALID_PARAMETER", detail: {...}, request_id: "..." }`。
分页响应：`{ list: [...], total: 120, page: 1, page_size: 20, total_pages: 6 }`。

### 7.2 业务错误码分配

| 错误码范围 | 类别 |
|-----------|------|
| `0` | 成功 |
| `40001`–`40999` | 客户端参数错误 |
| `41001`–`41999` | 鉴权与权限 |
| `42001`–`42999` | 资源状态 |
| `43001`–`43999` | 业务规则 |
| `44001`–`44999` | 频率限制 |
| `45001`–`45999` | 外部依赖 |
| `50001`–`50999` | 服务器内部错误 |

常用 error_code：`INVALID_PARAMETER`(40001)、`UNAUTHORIZED`(41001)、`TOKEN_EXPIRED`(41002)、`FORBIDDEN`(41011)、`NOT_FOUND`(42001)、`CONFLICT`(42011)、`DUPLICATE_REQUEST`(42012)、`RATE_LIMITED`(44001)、`DEPENDENCY_ERROR`(45001)、`INTERNAL_ERROR`(50001)。

### 7.3 幂等性

| HTTP 方法 | 天然幂等性 |
|-----------|-----------|
| GET | ✅ 是 |
| PUT | ✅ 是 |
| DELETE | ✅ 是 |
| PATCH | ⚠️ 视语义（使用 If-Match / 版本号可达成） |
| POST | ❌ 否（关键操作通过 Idempotency-Key 头部支持） |

Idempotency-Key 适用条件：支付发起（强制）、订单创建（推荐）、退款申请（推荐）。缓存：成功 24h，失败 5min。

### 7.4 缓存策略

| 数据类型 | 缓存策略 | TTL |
|---------|---------|-----|
| 公开资源配置 | HTTP 缓存 | 5 分钟 |
| 用户档案（公开视图） | HTTP 缓存 | 2 分钟 |
| 订单/门票/个人数据 | 不缓存 | — |
| 系统配置 | Redis 缓存 | 10 分钟 |
| 赛事封面/场馆图片 URL | CDN + HTTP 缓存 | 1 小时 |

Redis 缓存键：`cache:{domain}:{resource}:{id}:{view}`（单条）/ `cache:{domain}:{resource}:list:{query_hash}`（列表）。

### 7.5 频率限制

| 层级 | 维度 | 默认限额 |
|------|------|---------|
| G1 全局 | per-IP | 1000 req/min |
| G2 认证 | per-IP | 10 req/min |
| G3 写操作 | per-user | 60 req/min |
| G4 敏感操作 | per-user | 5 req/min |
| G5 公开查询 | per-IP | 300 req/min |

超出返回 HTTP 429 + RATE_LIMITED + Retry-After 头部。

### 7.6 分页规范

参数：`page`(int32, 默认1, ≥1)、`page_size`(int32, 默认20, 1-100)、`sort`(string, 格式 field:dir)。

### 7.7 日期时间格式

ISO 8601：`yyyy-MM-ddTHH:mm:ss`。带时区附加 UTC 偏移。纯日期用 `yyyy-MM-dd`。服务端 UTC 存储，响应时按用户偏好时区转换。

### 7.8 金额格式

统一以「分」为单位（int32/int64）。`136000` = ¥1,360.00。前端展示自行 `/100`。

### 7.9 枚举值命名

代码层 PascalCase（`OrderStatus.PendingPayment`），API 层 snake_case（`"pending_payment"`）。

---

## 一致性检查模式

本模式检查 API 设计文档是否完整覆盖了上游业务工作流中的操作需求。

### 触发场景

| 场景 | 说明 |
|------|------|
| **工作流变更后** | 新增/修改业务步骤后，检查 API 设计是否同步更新了对应端点 |
| **API 设计变更后** | 新增/修改端点后，检查是否覆盖了所有工作流操作 |
| **常规复查** | review skill 在工作流→API 维度中委托调用 |

### 输入规格

| 输入 | 来源 |
|------|------|
| 业务工作流数据 | `design/02-business-workflow/data/*.js`（提取 action 节点和状态转换） |
| API 设计数据 | `design/04-platform-api/data/{slug}.js`（提取端点清单） |

### 检查步骤

1. **端点覆盖检查**：工作流数据中的每个 action 节点，对照 API 设计文档中的端点列表，标记缺少对应端点的 action
2. **状态转换覆盖检查**：工作流状态机中定义的每个状态转换，对照 API 设计文档中涉及状态变更的端点，标记缺少对应操作的状态转换
3. **subprocess 覆盖检查**：工作流中引用的 subprocess 是否有对应的 API 端点组
4. **权限点覆盖检查**：business-workflow 中定义的每个权限点，对照 API 设计文档中标注了该权限的端点，标记工作流有定义但无 API 端点引用的权限点（可能是冗余权限点或 API 设计遗漏）

### 输出格式

> 输出格式遵循共享规范：`.claude/skills/_shared/consistency-check-format.md`。
> 本 skill 的 `type` 枚举：`missing_endpoint`, `missing_state_transition`, `missing_subprocess`, `permission_unused`, `dead_endpoint`, `untraced`, `simulated_impl`。
> 本 skill 的 `source`：`workflow-to-api`。

```json
{
  "summary": {
    "domain": "domain-slug",
    "total_actions_in_workflow": 0,
    "matched_endpoints": 0,
    "total_issues": 0
  },
  "issues": [
    {
      "severity": "high",
      "type": "missing_endpoint",
      "detail": "工作流定义"提交审核"操作，但 API 设计文档中无对应端点",
      "suggestion": "添加 POST /api/v1/reviews"
    }
  ]
}
```

### D9.3 可用性检查（追加步骤）

> 在标准 4 步覆盖检查之后追加，检查端点是否"真的能用"而非仅存在。

5. **模拟实现检测**：grep 端点对应的 Controller 代码中是否包含 `Simulate*` / `Stub*` / `Mock*` 方法调用。发现 → 标记 issue type=`simulated_impl`
6. **数据流断裂检测**：对每个端点的 `produces[].field`，检查是否被至少一个前端页面组件的 `api_ref` / `sends` 引用。无 consumer → 标记 issue type=`dead_endpoint`
7. **追溯完整检测**：检查端点是否有 `consumes` 和 `produces` 标注。缺失 → 标记 issue type=`untraced`

### 使用方式

1. **作为独立检查**：对 Claude 说"使用 api-design 检查 {domain-slug} 的工作流与 API 一致性"
2. **被 review 调用**：review skill 在工作流→API 维度中自动委托本技能执行
