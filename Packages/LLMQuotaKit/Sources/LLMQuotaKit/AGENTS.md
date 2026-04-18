# LLMQuotaKit 共享框架

**作用**: 提供可复用的 LLM API 配额查询功能，供主应用、Widget 和测试共享使用

## 结构
```
LLMQuotaKit/
├── Providers/    # 各个 LLM 提供商实现
├── Models/       # 共享数据模型
├── Storage/      # 密钥存储（Keychain + App Group）
└── Networking/   # 共享 HTTP 网络客户端
```

## 在哪里找

| 任务 | 位置 | 说明 |
|------|------|------|
| 添加新提供商 | `Providers/` | 实现 `QuotaProvider` 协议 |
| 修改配额模型 | `Models/QuotaInfo.swift` | 修改配额数据结构和错误类型 |
| 修改密钥存储 | `Storage/KeychainStorage.swift` | 修改密钥存取逻辑 |
| 修改网络请求 | `Networking/NetworkClient.swift` | 修改超时、错误处理 |

## 约定

- 所有提供商必须是 `Sendable`（并发安全）
- `validateKey()` 返回 `true` 仅表示密钥格式验证通过，不代表配额充足
- `401/403` → 无效密钥，`429` → 频率限制但密钥有效
- 所有网络请求默认 15 秒超时

## 反模式

- ❌ 不要让提供商持有状态，必须是纯结构体实现
- ❌ 不要在 `fetchQuota` 中抛出不明确的错误，必须归类到 `QuotaError`
- ❌ 不要修改共享 `NetworkClient` 的默认超时，特殊需求需要说明
