# 啾旅后端（NestJS + TypeORM + MySQL）

给 `chirp_trip` 这个 Flutter App 用的后端，第一版只做**评论**和**点赞**，其余数据还在 App 的 mock 里。

App 那边接口失败会自动退回本地 mock，所以**后端没开也不影响演示**——只是评论不会存库、换台机器就看不到。

---

## 一、装 MySQL

这台机器目前**没有** MySQL 也没有 Docker，先装一个（二选一）：

**A. 官方安装包（推荐，带图形界面）**

1. 下载 [MySQL Installer for Windows](https://dev.mysql.com/downloads/installer/)，选 `mysql-installer-community-*.msi`
2. 安装类型选 **Developer Default** 或 **Server only**
3. 中途会让你设 root 密码，**记住它**，后面要填进 `.env`
4. 最后一步勾上 `Start the MySQL Server at System Startup`

**B. scoop（命令行，机器上已经有 scoop）**

```bash
scoop install mysql --no-update-scoop
```

`--no-update-scoop` 是为了跳过 scoop 自更新：自更新要从 GitHub 克隆 main bucket，网络一断它会先把旧 bucket 删了、再报「找不到 mysql」。如果已经遇到这种情况，先浅克隆补回来再装：

```bash
git clone --depth 1 https://github.com/ScoopInstaller/Main ~/scoop/buckets/main
```

scoop 装完会**自动初始化**数据目录（root 空密码），不要再手动跑 `mysqld --initialize-insecure`。

启动有两种：

- **注册成服务、开机自启**（要在**管理员**终端里跑，`--defaults-file` 不能省，否则服务找不到 scoop 的数据目录）：
  ```bash
  mysqld --install MySQL --defaults-file="%USERPROFILE%\scoop\apps\mysql\current\my.ini"
  net start MySQL
  ```
- **临时起一下**（不用管理员，关掉窗口就停）：
  ```bash
  mysqld --console
  ```

root 密码是空的，`.env` 里 `DB_PASSWORD` 留空即可。

**验证装好了**（能进命令行就算成功，`exit` 退出）：

```bash
mysql -u root -p
```

---

## 二、建库

```bash
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS chirp_trip DEFAULT CHARSET utf8mb4;"
```

表不用自己建：`DB_SYNC=true` 时 TypeORM 会按实体自动建 `comments` 和 `likes`。

---

## 三、配置并启动

```bash
cd server
cp .env.example .env
```

打开 `.env` 把 `DB_PASSWORD` 改成你的 root 密码，然后：

```bash
npm install
npm run dev
```

看到这行就算起来了：

```
chirp_trip server → http://localhost:3000/api
```

`npm run dev` 是热重载模式，改完代码自动重启。正式跑用 `npm run build && npm run prod`。

---

## 四、让手机连上

手机上的 `localhost` 指的是手机自己，所以要用**电脑在局域网里的 IP**。

查 IP（Windows）：

```bash
ipconfig
```

找当前联网的那个适配器（「以太网」或「无线局域网适配器 WLAN」）下面的 `IPv4 地址`，形如 `192.168.1.129`。这个地址是路由器 DHCP 分的，**可能会变**，连不上先查它。

然后有两种方式告诉 App：

**A. 跑的时候传参（不用改代码）**

```bash
flutter run --dart-define=API_BASE=http://192.168.1.129:3000/api
```

**B. 改默认值**

编辑 `lib/data/api.dart` 里的 `defaultValue`。打包 apk / ipa 时走的就是这个默认值。

几个前提：
- 手机和电脑连**同一个 Wi-Fi**
- Windows 防火墙第一次可能弹窗，要点「允许访问」；没弹的话手动放行 3000 端口：
  ```bash
  netsh advfirewall firewall add rule name="chirp_trip 3000" dir=in action=allow protocol=TCP localport=3000
  ```
- 在手机浏览器里打开 `http://192.168.1.129:3000/api/comments?postId=p1`，能看到 `[]` 就通了

---

## 五、接口

所有接口都在 `/api` 下面。当前用户固定是 `me`（还没做登录）。

### 评论

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/comments?postId=p1` | 某条帖子的评论，新的在前 |
| GET | `/api/comments/count?postId=p1` | 评论数 |
| POST | `/api/comments` | 发评论 |
| DELETE | `/api/comments/:id?userId=me` | 删一条（只能删自己的，否则 403） |
| DELETE | `/api/comments?userId=me` | 清空我发过的所有评论 |

POST 的 body：

```json
{
  "postId": "p1",
  "userId": "me",
  "userName": "小啾",
  "userAvatar": "https://i.pravatar.cc/150?img=5",
  "content": "这条评论会写进数据库"
}
```

### 点赞

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/likes?targetType=post&targetId=p1&userId=me` | 返回 `{count, liked}` |
| POST | `/api/likes/toggle` | 点过就取消、没点过就点上，返回最新的 `{count, liked}` |

`targetType` 只能是 `post` 或 `comment`。同一个人对同一个目标只会有一条记录（联合唯一索引）。

### 用 curl 试一下

```bash
curl "http://localhost:3000/api/comments?postId=p1"
```

```bash
curl -X POST http://localhost:3000/api/comments -H "Content-Type: application/json" -d "{\"postId\":\"p1\",\"userId\":\"me\",\"userName\":\"小啾\",\"content\":\"来自 curl\"}"
```

---

## 六、代码结构

```
server/
├── src/
│   ├── main.ts              入口：全局前缀 /api、开 CORS、监听 0.0.0.0
│   ├── app.module.ts        读 .env + 连 MySQL
│   ├── comments/            评论：实体 / DTO / service / controller
│   └── likes/               点赞：同上
├── .env.example             配置模板，复制成 .env 再改
└── package.json
```

每个模块四件套：

- `*.entity.ts` — 表结构，TypeORM 按它建表
- `dto.ts` — 请求体的形状和校验规则（`class-validator`）
- `*.service.ts` — 数据库操作
- `*.controller.ts` — 路由

---

## 七、常见问题

**`ER_ACCESS_DENIED_ERROR`** — `.env` 里的 `DB_USER` / `DB_PASSWORD` 和 MySQL 对不上。

**`ECONNREFUSED 127.0.0.1:3306`** — MySQL 没启动：装了服务就 `net start MySQL`，否则 `mysqld --console`。

**`Unknown database 'chirp_trip'`** — 第二步的建库命令没跑。

**手机上评论发出去了但重进就没了** — App 没连上后端，走的是本地兜底。按第四步检查 IP、Wi-Fi 和防火墙，先用手机浏览器访问一下接口确认。

**表结构改了但数据库没变** — 确认 `.env` 里 `DB_SYNC=true`，然后重启服务。
