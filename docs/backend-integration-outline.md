# 情侣空间 App 后端接入说明

## 这份说明解决什么问题

- 下一轮真正接 API 时，先从哪里开始
- 哪些类直接替换，哪些类继续保留
- 当前 fake 同步已经验证到哪一步

## 当前已经验证过的链路

- 本地真实数据读写：`MemoryStore` / `WishStore` / `AnniversaryStore`
- 本地关系作用域：`RelationshipStore` + `AppContentScope`
- 账号与同步骨架：`AccountSessionStore` + `AppSyncService`
- 演示远端链路：`FakeSyncRemoteProvider` 的 push / pull / apply
- 真实远端骨架：`RealSyncRemoteProvider` 已接进 provider 配置链路，当前定义在 `CoupleSpace/App/AccountSyncPrototype.swift`
  - `pullContent` 已具备真实请求、状态码校验、响应解码与 `RemoteSyncSnapshotPayload -> SyncContentPayload` 映射
  - 仍缺真实可用的 base URL、token/header，以及 `pushContent` / `fetchRemoteSummary` 的联网实现

## 建议的真实接入顺序

1. 先接真实账号会话，把登录结果落到 `AccountSessionStore.adoptAuthenticatedSession(profile:)`
2. 再接 relationship / invite / shared space，让 `RelationshipStore` 从本地演示态切到真实关系结果
3. 再补 `RealSyncRemoteProvider` 的真实请求实现，替换当前默认的 `FakeSyncRemoteProvider`
4. 最后把内容 push / pull 接到真实 API，继续复用 `AppSyncService` 做上下文与 payload 编排

## 未来真实实现的替换点

- `RealSyncRemoteProvider`
  - 当前定义在 `CoupleSpace/App/AccountSyncPrototype.swift`；真正接 API 时优先补 `pushContent` / `pullContent` / `fetchRemoteSummary`
  - 请求组织入口也在这里：先补 endpoint 路径、请求体与响应解析，再接 `URLSession`
- `AppSyncProviderConfiguration.current`
  - 当前统一决定工程注入的是 demo fake provider 还是真实远端骨架；以后接真 API 时，优先从这里切 provider
- `AccountSessionStore.prepareDemoSession(...)`
  - 只保留演示态；真实登录完成后由 `adoptAuthenticatedSession(profile:)` 承接服务端返回
- `AuthenticatedAccountPayload`
  - 未来真实登录成功后，先把服务端返回收敛成这个轻量 payload，再交给 `AccountSessionStore.adoptAuthenticatedPayload(...)`
- `RemoteSyncSnapshotPayload`
  - 未来真实同步接口返回后，先把远端内容整理成这个轻量 payload，再映射成 `SyncContentPayload` 继续走当前 apply 链路
- `AppSyncService`
  - 继续保留；负责拼 `AppSyncRequestContext`、整理 `SyncContentPayload`、驱动同步状态
- `MemoryStore` / `WishStore` / `AnniversaryStore`
  - 继续保留；负责本地缓存、seed fallback、pull 后本地落地
- `RelationshipStore`
  - 继续保留；未来改成“本地缓存 + 真实关系结果入口”，不要直接删掉

## 接真实后端时优先动哪些文件

- `CoupleSpace/App/AccountSyncPrototype.swift`
  - 接真实账号会话、维护 provider 配置与注入入口
- `CoupleSpace/App/AccountSyncPrototype.swift`
  - 补 `RealSyncRemoteProvider` 的真实 push / pull / summary 请求实现
- `CoupleSpace/App/AppRootView.swift`
  - 保持注入点不变，通过 `AppSyncProviderConfiguration` 切换 provider
- `CoupleSpace/App/AccountSyncPrototype.swift`
  - 当前集中管理 `AppSyncProviderConfiguration` 与 demo / future real provider 的选择入口
- `CoupleSpace/App/RelationshipStore.swift`
  - 把邀请、绑定、空间状态从本地演示逻辑切到真实关系结果

## 当前仍然是假实现的部分

- 演示账号不是正式登录
- fake remote 不是 HTTP / 云数据库
- push / pull / apply 没有冲突解决、版本比较和自动同步
- 真实登录返回目前还只是 `AuthenticatedAccountPayload` 占位，不包含真实网络请求
- `RealSyncRemoteProvider` 当前还没有可用的 base URL、真实 token/header，以及 `pushContent` / `fetchRemoteSummary` 的线上实现

## 当前不要乱动的地方

- 不要重写 `AppSyncService` 的聚合职责
- 不要把三个本地 store 改成远端优先读取
- 不要提前做完整 repository / sync engine 重构
