/**
 * RESTful HTTP 协议定义
 * 
 * 所有 api-design 项目内置默认协议，从 skill 模板自动复制
 */
window.API_DATA = window.API_DATA || {};
window.API_DATA["protocol-rest"] = {
  id: "rest",
  name: "RESTful HTTP",
  description: "标准 RESTful API，基于 HTTP 方法 + URL 路径寻址，JSON 请求/响应体",
  version: "1.0",
  builtin: true,

  transports: [
    {
      type: "http",
      addressing: {
        schema:   "method + path",
        method:   { type: "enum", values: ["GET", "POST", "PUT", "PATCH", "DELETE"], desc: "HTTP 方法" },
        path:     { type: "string", pattern: "/api/v1/{resource}/{id?}", desc: "URL 路径模板，花括号为路径参数" },
        query:    { type: "object", optional: true, desc: "查询参数" }
      },
      security: {
        auth:     "JWT Bearer (Authorization header)",
        cors:     "由 security-policy.js 定义"
      }
    }
  ],

  envelope: {
    format: "http",
    request: {
      headers:  { type: "object", desc: "HTTP Headers（Content-Type, Authorization, Idempotency-Key 等）" },
      pathParams: { type: "object", optional: true, desc: "路径参数" },
      queryParams:{ type: "object", optional: true, desc: "查询参数" },
      body:     { type: "json", optional: true, desc: "请求体（JSON）" }
    },
    response: {
      status:   { type: "int", desc: "HTTP 状态码" },
      headers:  { type: "object", desc: "响应头" },
      body:     { type: "json", optional: true, desc: "响应体（JSON）" }
    }
  },

  rpc: {
    model: "request-response",
    correlation: "implicit（HTTP 连接天然绑定请求-响应）",
    timeout: { default: "30s", adjustable: true },
    streaming: false
  },

  errors: {
    location: "http.status + response body",
    successValues: [200, 201, 204],
    standardCodes: {
      400: "Bad Request — 请求参数错误",
      401: "Unauthorized — 未认证",
      403: "Forbidden — 无权限",
      404: "Not Found — 资源不存在",
      409: "Conflict — 资源冲突（如幂等键重复）",
      422: "Unprocessable Entity — 业务校验失败",
      429: "Too Many Requests — 触发频控",
      500: "Internal Server Error"
    }
  },

  idempotency: {
    mechanism: "Idempotency-Key header",
    header: "Idempotency-Key",
    applicableMethods: ["POST", "PUT", "PATCH"]
  }
};
