# B 机新手手把手：环境配置 + 开发 + 测试（零基础版）

> 给谁看：第一次在 B 机上跑这个项目、对"环境配置/开发流程"完全没概念的同学。
> 读完你能独立做到：① 在 B 机把后端 + 前端 + 运营后台都跑起来；② 看懂 dev/test/prod 是怎么回事；③ 改一行代码 → 看到效果 → 提交。
> **照着每一步抄就行，不用先懂原理。** 原理在每节末尾的「💡为什么」里，可跳过。

---

## 0. 先记住 3 句话（整篇的地基）

1. **你这台是 B 机（IP `172.21.160.221`）——只用来写代码、跑前后端。**
2. **所有数据库/缓存/存储（中间件）+ AI 服务，都在 A 机（`172.21.160.212`）上，已经常年开着，你不用管。** 你的程序通过这个 IP 连过去。
3. **你要在 B 机跑 3 样东西**：
   - **Java 后端**（`campus_wall`）→ 用 **IDEA**，端口 8080
   - **小程序前端**（`campus-wall-frontend`）→ 用 **VSCode** + 微信开发者工具
   - **运营后台**（`campus-wall-monitor-ui`）→ 用 **VSCode**，端口 5173

调用关系（记住这张图，出问题就对着它查）：
```
[B机] 小程序/运营后台前端 ──► [B机] Java 后端(8080) ──► [A机] MySQL/Redis/MinIO
                                      └──► [A机] AI 服务(8011)
```

---

## 1. 一次性准备（每台新 B 机只做一次）

### 1.1 装这些软件
| 软件 | 版本 | 干嘛用 |
|---|---|---|
| **JDK** | **17** | 跑 Java 后端 |
| **IntelliJ IDEA** | 任意较新版 | 写/跑 Java 后端 |
| **Node.js** | **18 以上（推荐 20）** | 跑前端、运营后台 |
| **VSCode** | 任意 | 写/跑前端、运营后台 |
| **微信开发者工具** | 最新 | 预览小程序 |
| **Git** | 任意 | 拉代码、提交 |

验证装好了（打开终端逐条敲，能打印版本号就对）：
```bash
java -version      # 要显示 17
node -v            # 要显示 v18 或 v20
git --version
```

### 1.2 ⚠️ 关梯子（最容易踩的坑）
B 机如果开着**梯子 / VPN / 系统代理**，会劫持到 A 机（`172.21.160.x`）的内网连接，导致后端连不上数据库、卡死。两个办法二选一：
- 开发时**直接关掉梯子**；或
- 配置"内网不走代理"（终端执行，或写进 `~/.bashrc`）：
  ```bash
  export NO_PROXY=localhost,127.0.0.1,172.16.0.0/12,192.168.0.0/16
  ```

### 1.3 把代码拉下来
```bash
git clone <workspace 仓库地址> campus-wall
cd campus-wall
git submodule update --init --recursive   # 把 6 个子仓库都拉下来（关键！不做的话子目录是空的）
```
> 这是个"多仓库"项目：根目录是个壳，真正的代码在 `campus_wall/`、`campus-wall-frontend/` 等 6 个子目录里，必须用上面这条命令才能拉全。

---

## 2. 三个环境，1 分钟搞懂

| 环境 | 通俗类比 | 谁用 | 数据 |
|---|---|---|---|
| **dev**（开发） | 你的草稿本 | 你自己 | 假数据，随便造随便删 |
| **test**（测试） | 带妆彩排 | 全队验收 | 干净的测试数据 |
| **prod**（生产） | 正式演出 | 真实用户 | 真实数据，**别碰** |

**你 99% 的时间只用 dev。** 它们在 A 机上是**同一台中间件、不同的库**，已经隔离好了：

| 环境 | MySQL 库 | Redis DB | MinIO 桶 |
|---|---|---|---|
| **dev（你 B 机=.221）** | `campus_wall_dev_a` | 1 | `campus-dev-a` |
| dev（同事 C 机=.223） | `campus_wall_dev_b` | 2 | `campus-dev-b` |
| test（全队共享） | `campus_wall_test` | 15 | `campus-test` |
| prod（真实用户） | `campus_wall` | 0 | `campus-wall` |

> 💡为什么不每人一台中间件：A 机内存大（121G），一套中间件才占几个 G，三套环境放一起绰绰有余；你 B 机内存小，就别在上面起中间件了，连 A 机即可。

---

## 3. 配置 dev 环境（3 个服务各放一个配置文件）

**核心思想**：代码里只有"占位"和"连哪个库"的非密码配置（已入库）；**真实的账号密码放在一个不进 git 的本地文件里**。你要做的就是把这个本地文件放到对的位置。

### 3.1 Java 后端 → `campus_wall/application-local.yaml`

这个文件**装着连 A 机中间件的真实账号密码**，是后端能跑起来的关键。

**怎么拿到它**（二选一）：
- **方式 A（最简单）**：管理员已经准备好你这台 B 机（.221）的版本，直接拷过去：
  ```bash
  cd campus-wall
  cp deploy/team-dev/application-local.221.yaml  campus_wall/application-local.yaml
  ```
- **方式 B**：自己复制模板再填密码（密码向管理员要）：
  ```bash
  cd campus_wall
  cp application-local.yaml.example application-local.yaml
  # 然后用编辑器把里面的 <向管理员索取-xxx密码> 换成真实密码
  ```

放好后确认它在 `campus_wall/` 目录下（和 `pom.xml`、`mvnw` 同级）。里面已指向你的 dev 切片 `campus_wall_dev_a`。

> 💡生效机制：`application.yaml` 里配了 `spring.profiles.group.dev=local`，所以用 **dev** 启动时，这个 `application-local.yaml` 会被自动加载，覆盖默认配置。它已被 `.gitignore` 忽略，**不会**提交到 GitHub。
> ⚠️ 后端**必须在 `campus_wall/` 目录下启动**，否则读不到这个文件。

### 3.2 小程序前端 → `campus-wall-frontend/.env.local`

```bash
cd campus-wall-frontend
cp .env.example .env.local
```
打开 `.env.local`，确认两行都是**你 B 机自己的 IP**（不能用 localhost，否则手机/微信开发者工具连不上）：
```
VITE_API_BASE_URL=http://172.21.160.221:8080
VITE_WS_BASE_URL=ws://172.21.160.221:8080
```

### 3.3 运营后台 → 不用配！

`campus-wall-monitor-ui` 不需要任何配置文件——它内置了把 `/api` 转发到 `localhost:8080`（你 B 机本地的 Java 后端）。直接跑即可。

---

## 4. 用 IDEA 启动 Java 后端（手把手）

1. 打开 IDEA → **File → Open** → 选 **`campus_wall`** 这个文件夹（注意是子目录 `campus_wall`，不是最外层 `campus-wall`）。
2. IDEA 会识别出这是 Maven 项目，**右下角会自动下载依赖**，等它转完（第一次几分钟）。
3. 确认 `campus_wall/application-local.yaml` 已经放好（见 3.1）。
4. 左侧展开 `src/main/java/com/jyu/campus/`，找到 **`CampusWallBackendApplication.java`**，右键 → **Run 'CampusWallBackendApplication'**。
   - 默认就是 **dev** 环境，会自动加载你的 `application-local.yaml`。
5. **第一次启动会慢一点**：因为你的 `campus_wall_dev_a` 是空库，Flyway 会自动建好全部数据表 + 灌入基础数据（看日志在刷 `Migrating schema ... V3.0 / V3.1 ...`）。
6. 看到日志出现 **`Started CampusWallBackendApplication ... on port 8080`** 就成功了。

**想显式选环境**（可选）：右上角运行配置 → **Edit Configurations** → 在 **Active profiles** 填 `dev`。

> 💡命令行等价启动（不用 IDEA 时）：
> ```bash
> cd campus_wall
> ./mvnw spring-boot:run                # 开发热跑（默认 dev）
> # 或先打包再跑：
> ./mvnw clean package -DskipTests
> java -jar target/campus-wall-0.0.1-SNAPSHOT.jar --spring.profiles.active=dev
> ```

---

## 5. 用 VSCode 启动前端 + 运营后台（手把手）

### 5.1 小程序前端（campus-wall-frontend）

1. VSCode → **File → Open Folder** → 选 `campus-wall-frontend`。
2. 打开终端（菜单 Terminal → New Terminal，或 `` Ctrl+` ``），装依赖：
   ```bash
   npm install
   ```
3. 确认 `.env.local` 已配好（见 3.2）。
4. 编译小程序：
   ```bash
   npm run dev:mp-weixin
   ```
   它会在 `dist/dev/mp-weixin/` 持续输出小程序代码（保持这个终端开着）。
5. 打开**微信开发者工具** → 导入项目 → 目录选 **`campus-wall-frontend/dist/dev/mp-weixin`**：
   - **AppID**：没有团队 AppID 就点弹窗里的「**测试号**」直接进；团队正式 AppID 写在 `campus-wall-frontend/src/manifest.json` 的 `mp-weixin.appid`。
   - ⚠️ **必做**：导入后点右上角「**详情 → 本地设置**」，勾选「**不校验合法域名、web-view、TLS 版本以及 HTTPS 证书**」。否则小程序会拦截连本机 http 后端（`172.21.160.221:8080` 非 https）的请求，**帖子列表全加载不出来**。
6. 改代码后会自动重新编译，微信开发者工具里点刷新即可看到效果。

> 想在**浏览器**里快速看（不用微信工具）：`npm run dev:h5`，然后打开终端提示的地址。

### 5.2 运营后台（campus-wall-monitor-ui）

1. VSCode → 再 **Open Folder** → 选 `campus-wall-monitor-ui`（建议开新窗口）。
2. 终端装依赖并启动：
   ```bash
   npm install
   npm run dev
   ```
3. 打开浏览器访问终端提示的地址（默认 **http://localhost:5173**）。
4. 它会把后台请求转发到你 B 机本地的 Java 后端（`localhost:8080`），所以**第 4 节的后端要先跑着**。
5. 登录账号默认 **`admin` / `admin123`**（见后端配置 `admin.username/password`）。

---

## 6. 验证整条链路通了

1. **后端**：IDEA 日志有 `Started ... on port 8080`。
2. **运营后台**：浏览器开 `localhost:5173`，能进登录页、用 admin/admin123 登进去、看到看板有数据（说明后台→后端→A机数据库 全通）。
3. **小程序**：微信开发者工具里能看到圈子/帖子列表加载出来。

任一环节失败 → 跳到第 9 节排查表。

---

## 7. 怎么切到 test 环境（什么时候用 / 怎么做）

**什么时候**：你功能在 dev 做好了，要在"全队共享的干净环境"里验收，或要跑评测时。平时不用。

**Java 后端切 test**（test 不走 `application-local.yaml`，密码用环境变量给；密码和 dev 是同一个）：
- **命令行**：
  ```bash
  cd campus_wall
  SPRING_PROFILES_ACTIVE=test \
  MYSQL_PASSWORD='<中间件密码>' REDIS_PASSWORD='<中间件密码>' MINIO_SECRET_KEY='<中间件密码>' \
  java -jar target/campus-wall-0.0.1-SNAPSHOT.jar
  ```
  > `<中间件密码>` 就是 `application-local.yaml` 里那个密码，3 个环境通用。
- **IDEA**：复制一份运行配置改名"后端·test"，**Active profiles** 填 `test`，**Environment variables** 里加上面那 3 个密码变量。

切 test 后，后端连的就是 `campus_wall_test` / Redis DB 15 / `campus-test` 桶，和你的 dev 数据完全隔开。

> ⚠️ **prod 慎切**：`SPRING_PROFILES_ACTIVE=prod` 就是直连生产真实数据，全队共享，没把握别碰。

---

## 8. 日常开发循环（一天怎么过）

```
① git pull 拉最新       → 看同事昨天合了啥
② 开功能分支           → git checkout -b feat/我的功能
③ 改代码 + 本地跑起来手测（IDEA 跑后端、VSCode 跑前端，连 dev）
④ 自测                 → 后端 ./mvnw test
⑤ 小步提交 → 推送 → 开 PR → 同事 review → 合并
```

**提交注意（多仓库，容易搞错顺序）**：改了哪个子仓（如 `campus_wall`），要**先在子仓提交推送，再回根仓库前进指针**：
```bash
# 0) 先确认子仓在 main 分支（刚 clone/拉子模块后子仓常处于 detached HEAD，
#    不切回 main 直接 commit，push 会落空、提交搁浅在游离 HEAD 上）
cd campus_wall
git checkout main && git pull
# 1) 在子仓内提交
git add -A && git commit -m "feat(post): 加了个过滤"
git push
# 2) 回根仓库，记录"用了子仓的哪个版本"
cd ..
git add campus_wall && git commit -m "chore(submodule): 前进 campus_wall 指针"
git push
```
> ⚠️ 子仓在 `main` 分支、根仓库在 `master`。别跑 `git submodule sync`。

---

## 9. 卡住了看这里（常见报错排查）

| 现象 | 原因 | 解决 |
|---|---|---|
| 后端启动卡在"连接数据库"/超时 | **梯子劫持内网** | 关梯子，或配 `NO_PROXY`（见 1.2） |
| 后端报 `Communications link failure` / 连不上 172.21.160.212 | A 机不通 / 梯子 | 先 `ping 172.21.160.212`，再查梯子 |
| 后端报找不到 `application-local.yaml` 的配置 / 用了 prod 库 | 没在 `campus_wall/` 目录启动，或文件没放对 | 确认文件在 `campus_wall/` 根目录，且从该目录启动 |
| 启动报端口 8080 被占用 | 上一个后端没关 | 关掉旧进程，或换端口 `--server.port=8081` |
| 小程序/真机请求失败，但浏览器能通 | `.env.local` 写了 `localhost` | 改成你 B 机 IP `172.21.160.221`（见 3.2） |
| 小程序请求全红 / 报「不在 request 合法域名列表中」 | 没勾「不校验合法域名」（后端是 http 非 https） | 微信开发者工具 详情→本地设置→勾选不校验合法域名（见 5.1） |
| 运营后台页面空白 / 接口 404 | 后端没起，或没跑在 8080 | 先把第 4 节后端跑起来 |
| `npm install` 报错 | Node 版本太低 | 升到 Node 18+（推荐 20） |
| 子目录是空的 | 没拉子模块 | `git submodule update --init --recursive` |

---

## 附：B 机三件套速查

```bash
# —— Java 后端（IDEA 或命令行，dev）——
cd campus_wall && ./mvnw spring-boot:run          # 连 A机 dev_a 库

# —— 小程序前端（VSCode 终端）——
cd campus-wall-frontend && npm run dev:mp-weixin  # → 微信开发者工具导入 dist/dev/mp-weixin

# —— 运营后台（VSCode 终端）——
cd campus-wall-monitor-ui && npm run dev          # → 浏览器 localhost:5173，admin/admin123

# —— 自测 ——
cd campus_wall && ./mvnw test
```

> 配套阅读（想深入再看）：《全栈开发流程与三环境切换》《团队开发流程指南》。本文档是它们的"纯新手 B 机操作版"。
