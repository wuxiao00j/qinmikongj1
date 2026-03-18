# Couple Space Backend

当前后端已经从本地 JSON 文件版升级为 PostgreSQL 最小骨架，现阶段仍只支撑：

- `POST /auth/login`
- `POST /auth/demo-login`
- `POST /spaces`
- `POST /spaces/join`
- `GET /spaces/{spaceId}`
- `GET /spaces/{spaceId}/snapshot`
- `PUT /spaces/{spaceId}/snapshot`

这轮重点是补齐“创建共享空间 + 邀请码加入”的最小双人连接闭环，并继续沿用 `space_snapshots` 存整份空间快照。

## 1. 本地启动 PostgreSQL

仓库里提供了一个最小 `docker-compose`：

```bash
docker compose -f backend/docker-compose.yml up -d
```

默认会启动一个本地 PostgreSQL：

- host: `127.0.0.1`
- port: `5433`
- database: `couplespace`
- user: `couplespace`
- password: `couplespace`

默认 `DATABASE_URL`：

```bash
postgresql+psycopg://couplespace:couplespace@127.0.0.1:5433/couplespace
```

如果你本机已经有自己的 PostgreSQL，也可以直接覆盖环境变量：

```bash
export DATABASE_URL='postgresql+psycopg://user:password@127.0.0.1:5432/dbname'
```

## 2. 创建本地虚拟环境

推荐直接在仓库根目录创建一个独立 `.venv`：

```bash
uv venv .venv
```

如果你不用 `uv`，也可以：

```bash
python3 -m venv .venv
```

## 3. 安装依赖

```bash
uv pip install --python .venv/bin/python -r backend/requirements.txt
```

新增依赖：

- `SQLAlchemy`
- `psycopg[binary]`

如果你更习惯 `pip`，也可以：

```bash
.venv/bin/python -m pip install -r backend/requirements.txt
```

## 4. 启动后端

```bash
.venv/bin/python -m uvicorn backend.main:app --host 127.0.0.1 --port 8787 --reload
```

默认启动时会做两件事：

- 自动建表（`create_all`）
- 从 [seed.json](./data/seed.json) 幂等写入测试账号、测试空间、成员关系和测试 snapshot

如果你不想每次启动都补 seed，可以关闭：

```bash
export SEED_ON_STARTUP=false
```

## 5. 正式登录

```bash
curl -X POST http://127.0.0.1:8787/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"alex@demo.local","password":"couplespace"}'
```

当前 seed 默认写入的正式登录测试凭据：

- `alex@demo.local` / `couplespace`
- `jamie@demo.local` / `couplespace`
- `riley@demo.local` / `couplespace`
- `morgan@demo.local` / `couplespace`
- `taylor@demo.local` / `couplespace`
- `avery@demo.local` / `couplespace`

额外保留 `demo-login` 作为开发过渡接口；未绑定测试账号也仍可继续验证 create/join 闭环：

- `acct-real-riley`
- `acct-real-morgan`
- `acct-real-taylor`
- `acct-real-avery`

## 6. Demo 登录（过渡接口）

```bash
curl -X POST http://127.0.0.1:8787/auth/demo-login \
  -H 'Content-Type: application/json' \
  -d '{"accountId":"acct-real-alex"}'
```

## 7. 创建共享空间

```bash
curl -X POST http://127.0.0.1:8787/spaces \
  -H 'Authorization: Bearer demo-token-riley' \
  -H 'X-CoupleSpace-Account-ID: acct-real-riley' \
  -H 'X-CoupleSpace-Session-Account-ID: acct-real-riley' \
  -H 'Content-Type: application/json' \
  -d '{"title":"Riley 和 Morgan 的共享空间"}'
```

## 8. 邀请码加入

把上一步返回的 `inviteCode` 填进来：

```bash
curl -X POST http://127.0.0.1:8787/spaces/join \
  -H 'Authorization: Bearer demo-token-morgan' \
  -H 'X-CoupleSpace-Account-ID: acct-real-morgan' \
  -H 'X-CoupleSpace-Session-Account-ID: acct-real-morgan' \
  -H 'Content-Type: application/json' \
  -d '{"inviteCode":"REPLACE_ME"}'
```

## 9. 拉取空间快照

```bash
curl http://127.0.0.1:8787/spaces/space-demo-couple/snapshot?accountId=acct-real-alex\&currentUserId=user-alex\&partnerUserId=user-jamie \
  -H 'Authorization: Bearer demo-token-alex' \
  -H 'X-CoupleSpace-Account-ID: acct-real-alex' \
  -H 'X-CoupleSpace-Session-Account-ID: acct-real-alex'
```

对于新创建并加入成功的空间，也可以直接把 `spaceId` 换成新空间继续 pull。

## 10. 读取当前共享空间状态

适合给 iOS 在进入“我的”/“空间设置”或回到前台时刷新关系状态：

```bash
curl http://127.0.0.1:8787/spaces/REPLACE_SPACE_ID \
  -H 'Authorization: Bearer demo-token-riley' \
  -H 'X-CoupleSpace-Account-ID: acct-real-riley' \
  -H 'X-CoupleSpace-Session-Account-ID: acct-real-riley'
```

会返回当前空间最小状态，包括：

- `spaceId`
- `title`
- `inviteCode`
- `isActivated`
- `relationStatus`
- `currentAccount`
- `partner`

## 11. 写入空间快照

兼容当前 iOS push 的 `StoredRemotePayload` 结构，也兼容直接上传远端 snapshot 结构。

```bash
curl -X PUT http://127.0.0.1:8787/spaces/space-demo-couple/snapshot \
  -H 'Authorization: Bearer demo-token-alex' \
  -H 'X-CoupleSpace-Account-ID: acct-real-alex' \
  -H 'X-CoupleSpace-Session-Account-ID: acct-real-alex' \
  -H 'Content-Type: application/json' \
  --data @backend/data/push-sample.json
```

## 12. 当前数据层状态

已经落库的核心表：

- `accounts`
- `spaces`
- `space_members`
- `space_snapshots`

当前仍保留 [seed.json](./data/seed.json)，但它现在只作为数据库初始化来源，不再是运行时唯一存储。
