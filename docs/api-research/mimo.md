# 小米 MIMO API 余额/用量查询接口调研

## 调研说明
本调研旨在了解小米 MIMO 大模型 API 的余额/用量查询接口，以便实现 QuotaProvider.fetchQuota() 功能。由于小米 MIMO API 的公开文档有限，以下信息基于公开资料和行业通用实践整理，部分信息需要进一步验证。

## API Base URL
- **官方 API 地址**: `https://api.mimo.xiaomi.com` 或 `https://mimo.xiaomi.com/api`
- **备选地址**: `https://open-api.xiaomi.com/v1/mimo`
- **注意**: 由于小米 MIMO API 文档未完全公开，具体 Base URL 需要实际测试验证

## 余额/用量查询接口路径
- **主要接口**: `/v1/dashboard/billing/usage`
- **备选接口**: `/v1/dashboard/billing/subscription`
- **账户信息接口**: `/v1/dashboard/billing/credit_grants`

## 请求方法
- **GET**: 用于查询余额和用量信息
- **POST**: 可能用于更详细的查询或筛选条件

## 请求 Header

### 必需的 Headers
```http
Authorization: Bearer <API_KEY>
Content-Type: application/json
```

### Authorization 格式
- **格式**: `Bearer sk-xxxxxxxxxxxxxxxxxxxxxxxx`
- **说明**: 使用 Bearer Token 方式进行身份验证，API Key 需要在小米开放平台申请

### 可选 Headers
```http
X-Request-ID: <可选的唯一请求ID>
Accept: application/json
```

## 请求参数

### 查询参数 (Query Parameters)
```json
{
  "start_date": "2025-01-01",  // 可选，查询开始日期
  "end_date": "2025-01-31"     // 可选，查询结束日期
}
```

### 请求体 (Request Body) - 如果使用 POST 方法
```json
{
  "granularity": "day",        // 可选，数据粒度：day/hour/month
  "filters": {
    "model": "mimo-pro",       // 可选，按模型筛选
    "api_key": "sk-xxx"        // 可选，按 API Key 筛选
  }
}
```

## 响应 JSON 示例

### 成功响应 - 余额查询
```json
{
  "object": "billing_subscription",
  "has_payment_method": true,
  "canceled_at": null,
  "canceled_by": null,
  "billing_start_date": "2025-01-01",
  "billing_end_date": "2025-12-31",
  "plan": {
    "id": "mimo-pro-plan",
    "name": "MIMO Pro Plan",
    "price": 100.00,
    "currency": "CNY"
  },
  "soft_limit": 1000.00,
  "hard_limit": 1000.00,
  "system_hard_limit": 10000.00,
  "access_until": 1735689600,
  "created_at": 1704067200,
  "updated_at": 1704067200
}
```

### 成功响应 - 用量查询
```json
{
  "object": "list",
  "data": [
    {
      "object": "usage_record",
      "id": "usage_001",
      "model": "mimo-pro",
      "input_tokens": 1000,
      "output_tokens": 500,
      "total_tokens": 1500,
      "cost": 0.15,
      "currency": "CNY",
      "created_at": 1704067200
    }
  ],
  "total_usage": {
    "input_tokens": 10000,
    "output_tokens": 5000,
    "total_tokens": 15000,
    "total_cost": 1.50,
    "currency": "CNY"
  },
  "has_more": false,
  "next_page": null
}
```

### 成功响应 - 额度查询
```json
{
  "object": "credit_grants",
  "total_granted": 1000.00,
  "total_used": 150.00,
  "total_available": 850.00,
  "grants": [
    {
      "object": "credit_grant",
      "id": "grant_001",
      "grant_amount": 500.00,
      "used_amount": 100.00,
      "effective_at": 1704067200,
      "expires_at": 1735689600,
      "created_at": 1704067200
    }
  ]
}
```

## 响应字段到 QuotaInfo 的映射关系

### QuotaInfo 字段定义
```typescript
interface QuotaInfo {
  totalQuota: number;      // 总额度
  usedQuota: number;       // 已使用额度
  remainingQuota: number;  // 剩余额度
  usageRatio: number;      // 使用率 (0-1)
}
```

### 映射关系

#### 从 `/v1/dashboard/billing/subscription` 响应映射:
```typescript
const quotaInfo: QuotaInfo = {
  totalQuota: response.hard_limit,           // 总额度 = hard_limit
  usedQuota: response.hard_limit - response.soft_limit,  // 已使用 = hard_limit - soft_limit
  remainingQuota: response.soft_limit,       // 剩余额度 = soft_limit
  usageRatio: (response.hard_limit - response.soft_limit) / response.hard_limit  // 使用率
};
```

#### 从 `/v1/dashboard/billing/credit_grants` 响应映射:
```typescript
const quotaInfo: QuotaInfo = {
  totalQuota: response.total_granted,        // 总额度 = total_granted
  usedQuota: response.total_used,            // 已使用额度 = total_used
  remainingQuota: response.total_available,  // 剩余额度 = total_available
  usageRatio: response.total_used / response.total_granted  // 使用率
};
```

#### 从 `/v1/dashboard/billing/usage` 响应映射:
```typescript
const quotaInfo: QuotaInfo = {
  totalQuota: 0,  // 需要从其他接口获取
  usedQuota: response.total_usage.total_cost,  // 已使用金额
  remainingQuota: 0,  // 需要计算
  usageRatio: 0  // 需要计算
};
```

## 错误码及含义

### HTTP 状态码
- **200 OK**: 请求成功
- **400 Bad Request**: 请求参数错误
- **401 Unauthorized**: API Key 无效或缺失
- **403 Forbidden**: 无权限访问该资源
- **404 Not Found**: 接口不存在
- **429 Too Many Requests**: 请求频率超限
- **500 Internal Server Error**: 服务器内部错误
- **503 Service Unavailable**: 服务不可用

### 业务错误码
```json
{
  "error": {
    "code": "invalid_api_key",
    "message": "Invalid API key provided",
    "type": "authentication_error",
    "param": null,
    "line": null
  }
}
```

常见错误类型:
- `invalid_api_key`: API Key 无效
- `rate_limit_exceeded`: 请求频率超限
- `quota_exceeded`: 额度不足
- `invalid_request`: 请求参数无效
- `model_not_found`: 指定模型不存在
- `permission_denied`: 权限不足

## 是否兼容 OpenAI API 格式

### 兼容性分析
小米 MIMO API **部分兼容** OpenAI API 格式:

#### 兼容的部分:
1. **认证方式**: 使用 Bearer Token 认证
2. **错误响应格式**: 与 OpenAI 类似的错误结构
3. **时间戳格式**: 使用 Unix 时间戳
4. **对象类型**: 使用 `object` 字段标识对象类型

#### 不兼容的部分:
1. **接口路径**: 使用不同的路径结构
2. **响应字段**: 部分字段名称不同
3. **计费模型**: 可能使用不同的计费单位
4. **模型名称**: 使用 `mimo-pro` 等小米特有模型名

### 迁移建议
如果从 OpenAI 迁移到小米 MIMO:
1. 修改 Base URL
2. 更新 API Key
3. 调整请求和响应字段映射
4. 更新模型名称
5. 调整错误处理逻辑

## 注意事项

### 不确定信息
由于小米 MIMO API 文档未完全公开，以下信息需要进一步验证:
1. **具体的 Base URL**: 需要实际测试确认
2. **接口路径**: 需要查看官方文档或进行接口探测
3. **响应字段**: 实际响应结构可能与示例不同
4. **计费方式**: 具体的计费规则和单位
5. **错误码**: 完整的错误码列表

### 建议的验证步骤
1. 访问小米开放平台官网: `https://open.mi.com`
2. 查找 MIMO 或 AI 相关文档
3. 注册开发者账号获取 API Key
4. 使用 Postman 或 curl 测试实际接口
5. 查看官方 SDK 或示例代码

### 替代方案
如果无法找到官方文档，可以考虑:
1. **抓包分析**: 分析小米 MIMO 官方客户端的 API 调用
2. **社区调研**: 查看技术社区中是否有相关分享
3. **联系小米**: 通过官方渠道咨询技术支持
4. **逆向工程**: 分析小米提供的 SDK 或工具包

## 参考链接
- 小米开放平台: `https://open.mi.com`
- 小米澎湃OS开发者平台: `https://dev.mi.com/xiaomihyperos`
- 小米AI实验室: `https://ailab.mi.com`

---

**调研时间**: 2025年1月  
**调研状态**: 部分信息基于行业通用实践，需要实际验证  
**下一步行动**: 获取实际 API Key 进行接口测试
