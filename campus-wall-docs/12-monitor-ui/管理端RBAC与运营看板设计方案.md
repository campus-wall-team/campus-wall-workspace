> 本文档由多 agent 设计工作流（调研主流中后台实践 → 三立场出方案 → 评审 → 综合）产出，并已逐条核对 campus_wall / monitor-ui 真实代码。生成于 2026-06-15。

# 校园墙管理端架构设计方案（最终推荐版）

> **交付对象**：校园墙小团队（前后端各一人，中间件集中内网）。
> **立场**：以「代码库原生渐进型」为骨架（fitSmallTeam/fitCodebase 双 9、改动面最小、与现有 `JwtInterceptor`/`Result`/MyBatis-Plus/Flyway 模式完全同构），吸收「务实 MVP 型」（综评最高 8.65，固定 3 角色 + 种子数据 + 明确不做清单）与「主流参照型」（RBAC0 表设计 + 双轨监控边界）的最优点，剔除三份评审 `overEngineeringFlags` 指出的过度工程。
> **两个锁定决策**（运营数据看板 + 完整 RBAC）作为硬约束全部纳入，并对小团队右尺寸。
> **关键技术选型已全部给出单一推荐，不给「看情况」。**

---

## 0. 总览与设计原则

### 0.1 现状基线（已逐条核对真实代码，作为设计前提）

| 事实（代码实证） | 对设计的影响 |
|---|---|
| `@EnableAsync` + `@EnableScheduling` **均已存在**于 `CampusWallBackendApplication`（`@EnableAsync` 注释明确为 `aiIngestExecutor`） | 审计异步落库**无需新加 `@EnableAsync`**，直接复用。三份研究稿中「需加 @EnableAsync」是错的，本方案按代码事实修正。 |
| `pom.xml` **无** `spring-boot-starter-aop`，全项目零 `@Aspect` | 审计 AOP 需新增此 starter，**这是唯一新增后端核心依赖**。 |
| Flyway 已到 **V3.9**（`V3.9__ai_user_memory.sql`） | 新迁移**从 V4.0 起**。三份原稿写 V3.9 的均为版本撞号错误，本方案已修正。 |
| `AuthPathConstants.PROTECTED_PATHS` **已包含 `/api/v1/admin/**`**，`PUBLIC_PATHS` 含 `/api/v1/admin/login` | **落地必踩坑**：新增管理端拦截器前，必须先把 `/api/v1/admin/**` 从 `PROTECTED_PATHS` 移除，否则 C 端 `JwtInterceptor` 会先用管理端 token 解出的 id 去 `user` 表查（张冠李戴）并先抛 401。本方案在 §2.4 给出明确移除步骤。 |
| `SecurityConfig.addInterceptors`：`rateLimitInterceptor` 注册 `/api/**,/ws/**`，`jwtInterceptor` 注册 `PROTECTED_PATHS` | 新增 `AdminAuthInterceptor` 追加在末尾，注册 `/api/v1/admin/**`、排除 `/api/v1/admin/login`。 |
| `AdminModerationController`：`@Value` 注入硬编码账号密码，登录后 `jwtUtil.generateToken(adminUserId)` 签的是 **C 端 `user` 表 userId**，复用同一 JWT 域 | **头号坑**：必须物理隔离 `admin_user` 表 + 独立 token claim。 |
| `JwtUtil.SECRET` 硬编码 Base64、`EXPIRATION` 硬编码 7 天 | 迁环境变量（与 `application-prod` env 约定一致）。 |
| `post_report` 表已建：含 `status`(0待处理/1已处理/2已忽略)，**无处理人/处理备注字段**，无 Controller | 补 `report:handle/ignore` 闭环；处理人/备注需 V4.0 给该表加列。 |
| `feedback` 表已建：**已含 `status`(pending/processing/resolved) + `reply` 列**，仅用户提交无管理接口 | `feedback:reply` **只需补 Controller，零改表**，性价比最高。 |
| `user` 表 **无 `status`/`ban` 字段** | **`user:ban` 不能凭空落地**：需 V4.0 给 `user` 加封禁状态列，且 C 端 `JwtInterceptor` 加被封校验。本方案把封禁拆为带改表的明确子任务（见 §3、§2.4）。 |
| `User` 实体仅 `create_time/update_time`，**无 `last_active`** | DAU 必须走活跃事件源（Redis HLL / `browse_history`），**不能 `select distinct` 扫 user 表**。 |
| `RankRefreshTask` 用 `cron "0 5 0 * * ?"`；`MetricsCollector`/`FileCleanupTask` 用 `RedisLockUtil` 防多实例 | 快照任务复用此模式。**注意**：`RedisLockUtil` 的真正先例在 `MetricsCollector`/`FileCleanupTask`，**不在** `RankRefreshTask`（原稿点错文件），照抄须自己加锁。 |
| 前端 `monitor-ui`：3 页、token 散存 `localStorage('campus_monitor_token')` 于 http.js/router/Login/MainLayout 四处、无 Pinia store（已 `createPinia` 但闲置）、无按钮权限、`config.js` Grafana UID 占位、`Moderation.vue` 满是 `r.aiScore ?? r.ai_score` 兼容垫片 | 收敛 `useUserStore`、固定 `Result.data` camelCase。 |

### 0.2 设计原则（七条）

1. **增量演进，不引重型框架**：复用既有 `HandlerInterceptor` + 注解反射模式，鉴权用自定义 `@RequirePermission`（见 §1.1 决策）。
2. **管理端与 C 端物理隔离**：独立 `admin_user` 表 + 独立 token claim，C 端 `JwtInterceptor` 链路零回归。
3. **右尺寸 RBAC**：只做 RBAC0 + 菜单/按钮两类权限码 + 一维数据权限（ALL/SCHOOL）。
4. **看板双轨**：业务趋势走 MySQL/快照/HLL + ECharts；系统指标留 Grafana/Prometheus，互不重造。
5. **单一口径**：同一指标只在一处定义，瞬时归 stats、趋势/去重归 SQL/快照、Prometheus 只留系统 + 1 条审核积压告警。
6. **后端是唯一鉴权权威**：前端 `v-permission` 仅 UI 隐藏，每个写接口必须独立 `@RequirePermission` 兜底。
7. **先地基后增量**：每阶段独立可上线，先修两大安全坑，不一上来铺细粒度权限矩阵。

---

## 1. 关键技术选型（单一推荐 + 一句话理由）

### 1.1 鉴权框架（三选一）→ **自定义 `@RequirePermission` 注解 + `AdminAuthInterceptor`**

> **一句话理由**：管理端鉴权诉求（登录 + 权限码校验 + 踢人）用现有拦截器模式 + 一个注解 + 一张 Redis 黑名单即可全覆盖，新增依赖为 0、学习成本为 0，且不引入「C 端自写 JWT 与 Sa-Token 两套 token 域长期共存」的分裂成本。

**取舍说明（诚实）**：研究稿与方案 1/2 倾向 Sa-Token，它客观上「踢人/续签」更省力。但本项目管理端账号是**个位数**，三份评审一致认可自研拦截器对本代码库 `fitCodebase` 最高；Sa-Token 省下的力气恰好是「自研要还的小额利息」，而它要求的代价（替换拦截器注册、引 `StpUtil/StpInterface`、与 C 端 JWT 共存）对一个目前零安全框架的项目更重。**Spring Security 直接排除**（FilterChain/AuthenticationManager 概念与现有 `WebMvcConfigurer` 拦截器模式冲突，CSRF/OAuth2 对内网管理端无用）。

| 维度 | **自定义 JWT + 注解（选）** | Sa-Token | Spring Security |
|---|---|---|---|
| 与现有代码契合 | 极高（拦截器+RequestContext 全套已在） | 中 | 低 |
| 新增依赖 | 0 | 1 + 共存复杂度 | 1 + 配置心智 |
| 踢人下线 | Redis 黑名单（账号个位数，成本极低） | 开箱 | session 管理 |

### 1.2 前端权限路由 → **静态路由 + 权限码过滤**（不做后端动态菜单树）

> **一句话理由**：管理页面可数（看板/审核/举报/反馈/认证/用户/管理员/角色/审计），后端只吐权限码字符串集合，前端用它过滤静态 `routes.meta.perms` 生成菜单即可；后端 `sys_menu` 表 + 可视化菜单管理是三份评审一致点名的过度工程。

### 1.3 看板时序方案 → **预聚合每日快照表 `stat_daily` 为主 + SQL 直查/瞬时为辅**

> **一句话理由**：业务表索引齐全（`idx_create_time`/`idx_browse_time`/`idx_create_time_ml`/`idx_ai_chat_session_time`）且数据量小，趋势直查 `GROUP BY DATE` 足够；唯独「跨多表每日总览 + DAU 去重」固化进 `stat_daily`，使历史不受 Prometheus 15 天 retention 限制；**明确不引 TimescaleDB/ClickHouse/Metabase**。

### 1.4 DAU 方案 → **Redis HyperLogLog 打点 + 每日快照固化**

> **一句话理由**：`User` 表无 `last_active`，在 C 端 `JwtInterceptor` 拿到 userId 后顺手 `PFADD dau:{yyyyMMdd} {userId}`（近零成本、误差 0.81% 对运营足够），凌晨固化进 `stat_daily.dau`；**绝不 `select distinct` 扫用户表**，也不为 DAU 单建明文活跃事件大表。

---

## 2. 鉴权与 RBAC

### 2.1 模型层次：RBAC0 + 菜单/按钮两类权限码 + 一维数据权限

- 做 **RBAC0**（管理员-角色-权限 多对多）。**不做** RBAC1 角色继承、**不做** RBAC2 互斥/基数约束、**不做** dept 部门树。
- 权限分两类：`menu`（页面/路由）+ `button`（操作点）。
- 数据权限只做一维：`data_scope ∈ {ALL, SCHOOL}`，挂在 `admin_role` 上，落地复用 `RequestContext.universityId` 拼 `where university_id = ?`。**不做通用 data_scope 引擎**。
- **固定 3 角色**，用 Flyway 种子数据初始化（吸收方案 2）：`superadmin`（全权）/ `moderator`（审核+举报+反馈+认证+封禁）/ `viewer`（看板+只读列表）。角色-权限绑定**持久化在 `admin_role_permission` 表**（保留方案 1/3 的 DB 存储，便于 `@RequirePermission` 反查与日后加角色），但**初期不做可视化配权限 UI**——这一取舍平衡了「方案 2 评审建议纯代码常量映射」与「成长性」：表已建好，逻辑靠种子数据，UI 推迟到真出现分权诉求。

### 2.2 表结构（Flyway `V4.0__rbac_audit_stat.sql`，从 V3.9 递增）

```sql
-- ============ RBAC ============
-- 1. 管理员账号（与 C 端 user 表物理隔离）
CREATE TABLE IF NOT EXISTS admin_user (
    id            bigint auto_increment primary key comment '管理员ID',
    username      varchar(50)  not null comment '登录账号',
    password      varchar(100) not null comment 'BCrypt 哈希（复用 spring-security-crypto）',
    nickname      varchar(50)  null comment '显示名',
    status        tinyint default 1 not null comment '1启用 0停用',
    university_id bigint null comment '所属高校（data_scope=SCHOOL 时生效）',
    last_login_at datetime null,
    last_login_ip varchar(64) null,
    create_time   datetime default CURRENT_TIMESTAMP null,
    update_time   datetime default CURRENT_TIMESTAMP null on update CURRENT_TIMESTAMP,
    constraint uk_admin_username unique (username)
) charset = utf8mb4 comment '管理员账号表';

-- 2. 角色
CREATE TABLE IF NOT EXISTS admin_role (
    id          bigint auto_increment primary key,
    role_code   varchar(50) not null comment 'superadmin/moderator/viewer',
    role_name   varchar(50) not null,
    data_scope  varchar(20) default 'ALL' not null comment 'ALL 全部 | SCHOOL 仅本校',
    status      tinyint default 1 not null,
    create_time datetime default CURRENT_TIMESTAMP null,
    constraint uk_role_code unique (role_code)
) charset = utf8mb4 comment '角色表';

-- 3. 权限（menu 类型即菜单，不单建 sys_menu 表）
CREATE TABLE IF NOT EXISTS admin_permission (
    id          bigint auto_increment primary key,
    perm_code   varchar(64) not null comment '权限码 module:action',
    perm_name   varchar(64) not null,
    perm_type   varchar(10) not null comment 'menu | button',
    parent_code varchar(64) null comment 'menu 前端归组用，可空',
    sort        int default 0,
    constraint uk_perm_code unique (perm_code)
) charset = utf8mb4 comment '权限表(含菜单)';

-- 4. 管理员-角色
CREATE TABLE IF NOT EXISTS admin_user_role (
    admin_user_id bigint not null,
    role_id       bigint not null,
    primary key (admin_user_id, role_id)
) charset = utf8mb4 comment '管理员角色关联';

-- 5. 角色-权限
CREATE TABLE IF NOT EXISTS admin_role_permission (
    role_id bigint not null,
    perm_id bigint not null,
    primary key (role_id, perm_id)
) charset = utf8mb4 comment '角色权限关联';

-- ============ 审计 ============
CREATE TABLE IF NOT EXISTS admin_oper_log (
    id            bigint auto_increment primary key,
    admin_user_id bigint       null comment '操作人ID',
    operator_name varchar(50)  null comment '操作人名（冗余免 join）',
    module        varchar(50)  null comment '模块/注解 title',
    action        varchar(50)  null comment '动作/权限码',
    target_type   varchar(50)  null comment 'post/comment/user/report/config...',
    target_id     varchar(64)  null comment '只记关键ID，不记全 body',
    req_method    varchar(10)  null,
    req_uri       varchar(255) null,
    client_ip     varchar(64)  null,
    status        tinyint default 1 not null comment '1成功 0失败',
    error_msg     varchar(500) null,
    cost_ms       bigint null,
    create_time   datetime default CURRENT_TIMESTAMP null,
    INDEX idx_oper_admin (admin_user_id),
    INDEX idx_oper_time (create_time)
) charset = utf8mb4 comment '管理端操作审计日志';

-- ============ 看板快照 ============
CREATE TABLE IF NOT EXISTS stat_daily (
    stat_date          date primary key comment '统计日期',
    new_users          int default 0,
    total_users        int default 0,
    new_posts          int default 0,
    new_comments       int default 0,
    new_ai_chats       int default 0,
    dau                int default 0 comment '来自 HLL PFCOUNT 固化',
    moderation_pending int default 0,
    moderation_flagged int default 0,
    create_time        datetime default CURRENT_TIMESTAMP null
) charset = utf8mb4 comment '每日运营指标快照';

-- ============ 顺带补齐已建表的缺口（落地必需） ============
-- post_report 加处理人/备注（原表只有 status）
ALTER TABLE post_report
    ADD COLUMN handler_id   bigint       null comment '处理管理员ID',
    ADD COLUMN handle_remark varchar(255) null comment '处理备注',
    ADD COLUMN handle_time  datetime     null comment '处理时间';
-- user 加封禁状态（user:ban 落地前提，原表无此字段）
ALTER TABLE user
    ADD COLUMN status   tinyint  default 1 not null comment '1正常 0封禁',
    ADD COLUMN ban_until datetime null comment '封禁到期时间(null=永久或未封)';
```

**初始化（`V4.1__rbac_init.sql`）**：insert 3 角色 + 全量权限码 + 一个超管账号（密码哈希由部署时用环境变量生成的 BCrypt 串填入，**不硬编码明文**）；`admin_role_permission` 按 §2.3 映射插入。

> 表数量：6 张 RBAC/审计/快照 + 2 处 ALTER（不新增表）。`sys_config`（可配置参数）见 §3，列入二期。

### 2.3 权限码规范：统一 `module:action`，前后端共用一套

| 模块 | 权限码 |
|---|---|
| 运营看板 | `stat:view`(menu) |
| 内容审核 | `moderation:queue`(menu) `moderation:scan` `moderation:approve` `moderation:reject` |
| 举报处理 | `report:list`(menu) `report:handle` `report:ignore` |
| 反馈处理 | `feedback:list`(menu) `feedback:reply` |
| 学生认证 | `verification:list`(menu) `verification:review` |
| 用户管理 | `user:list`(menu) `user:ban` `user:unban` |
| 管理员管理 | `admin:list`(menu) `admin:create` `admin:update` `admin:reset-pwd` `admin:kick` |
| 角色管理 | `role:list`(menu) `role:assign` |
| 审计日志 | `audit:view`(menu) |
| 系统配置（二期） | `sys:config`(menu) |

**角色映射**：`viewer` = 所有 `*:list`/`*:view`/`*:queue`；`moderator` = viewer + `moderation:*`/`report:*`/`feedback:*`/`verification:review`/`user:ban`/`user:unban`；`superadmin` = 全部。导出/导入统一 `:export`/`:import`（按需再加）。

> 读接口只挂查看码；写接口逐个挂动作码。**不在 `AuthPathConstants` 路径列表堆细粒度规则**——路径列表只适合「登录与否」粗粒度，approve/reject 不同权限必须落方法级注解。

### 2.4 鉴权机制（落地清单，全部增量，不动 C 端链路）

1. **先移坑（必做第一步）**：把 `/api/v1/admin/**` 从 `AuthPathConstants.PROTECTED_PATHS` **移除**，保留 `/api/v1/admin/login` 在 `PUBLIC_PATHS`。否则 C 端 `JwtInterceptor` 与新拦截器对 admin 请求双重拦截、张冠李戴。
2. **`@RequirePermission` 注解**（`admin.security` 包）：
   ```java
   @Target(ElementType.METHOD) @Retention(RetentionPolicy.RUNTIME)
   public @interface RequirePermission {
       String[] value();              // 权限码，默认 OR（任一满足）
       Logical logical() default Logical.OR;
   }
   ```
3. **`AdminAuthInterceptor`**（`HandlerInterceptor`），注册 `/api/v1/admin/**`、排除 `/api/v1/admin/login`，在 `SecurityConfig.addInterceptors` 末尾追加（顺序：`RateLimit(/api/**,/ws/**)` → C 端 `JwtInterceptor(剩余 PROTECTED_PATHS)` → `AdminAuthInterceptor(/api/v1/admin/**)`，三者 path 不再重叠）：
   - 解析管理端 token（独立 claim `type=admin` + `adminUserId`）；
   - 校验 Redis 黑名单 `admin:blacklist:{adminUserId}`（踢人下线）；
   - 把 `adminUserId`/`adminName`/`dataScope`/`universityId` 塞进 `RequestContext`（新增 `adminUserId`/`dataScope` 槽）；
   - 反射读目标方法 `@RequirePermission`，与该管理员权限码集合（Redis 缓存）求交，不满足抛 `BusinessException(403)`。
4. **管理端 token 独立签发**：`JwtUtil` 新增 `generateAdminToken/parseAdminToken`（claim `type=admin`），或新建 `AdminJwtUtil`。`SECRET`/`EXPIRATION` 迁环境变量 `${JWT_SECRET}`。**迁移影响提醒**：换 SECRET 会使 C 端已签发 token 集体失效，应在低峰发布或保留旧 SECRET 灰度（已知风险，发布时交代）。
5. **权限码缓存**：登录后查 `admin_role_permission` 得 `Set<String>`，写 Redis `admin:perms:{adminUserId}`（TTL 30min）；角色/权限变更主动 `del`。
6. **踢人下线**：`admin:kick` 写黑名单，TTL = token 剩余有效期。
7. **数据权限**：列表 Service 读 `data_scope`，`SCHOOL` 时用 `RequestContext.universityId` 追加 `where`。仅此一处逻辑。
8. **用户封禁兜底**：`user:ban` 写 `user.status=0`/`ban_until` 后，**C 端 `JwtInterceptor` 须加被封校验**（被封则拒绝），否则封禁不生效——这是 `user:ban` 真正落地的必备配套。

> **安全红线**：前端 `v-permission` 仅 UI 隐藏；每个写接口必须独立 `@RequirePermission`，否则隐藏按钮可被直接调接口绕过。

### 2.5 审计日志（注解 + AOP，极简）

- 新增 `spring-boot-starter-aop`（首个 AOP，唯一新增核心依赖）；异步落库**复用已有的 `@EnableAsync`**（无需新加）。
- `@OperationLog(module="内容审核", action="驳回", targetType="post")` + `@Aspect @Around` 切面（`admin.audit` 包）。
- **只标注写操作**（approve/reject/report 处理/封号/反馈回复/管理员 CRUD/角色分配/改配置），读接口（queue/list/stats）**一律不记**，防爆量。
- 采集：操作人（`RequestContext.adminUserId`）、module/action、`targetType+targetId`（**只记关键 ID 不记全 body**，零脱敏负担）、IP、status、错误摘要、耗时。`@Async` 落库，不上 MQ。

---

## 3. 管理端模块清单（必做 / 二期 / 明确不做 + 理由）

| 模块 | 取舍 | 说明 / 理由 |
|---|---|---|
| 管理员登录（独立账号体系 + 踢人） | **必做** | 修掉硬编码账号 + C 端 token 复用两个坑 |
| RBAC（角色/权限/账号/审计） | **必做** | 锁定决策，§2 |
| 内容审核（队列/扫描/通过/驳回） | **必做** | 已有 `AdminModerationController`，补 `@RequirePermission` + `@OperationLog` |
| 学生认证审核 | **必做** | 已有 `AdminStudentVerificationController`，补权限码 + 审计 |
| 举报处理（`report:handle/ignore`） | **必做** | 表已建无 Controller，V4.0 加处理人列后补闭环 |
| 反馈处理（`feedback:reply`） | **必做** | 表已含 status/reply 列，**仅补 Controller，零改表**，性价比最高 |
| 用户管理（列表 / 封禁 / 解封） | **必做** | V4.0 给 `user` 加 status 列 + C 端被封校验后落地；审核违规刚需 |
| 操作审计日志查看页 | **必做** | §2.5 配套只读查询 |
| 运营数据看板 | **必做** | 锁定决策，§4 |
| 系统参数配置 `sys_config` | **二期** | 推广 `hot_rank_config` 先例，把 `AI_VIOLATION_THRESHOLD=60`/敏感词开关/限流参数挪入，运营可改不重启；一期保留硬编码 |
| 角色-权限可视化分配 UI | **二期** | 表已支撑，初期靠种子数据 + DB 直配 |
| 数据字典 `sys_dict` 独立表 | **不做** | 举报原因/反馈类型量小，前端写死或塞 `sys_config` 即可 |
| 可视化菜单管理（`sys_menu`+UI） | **不做** | 静态路由足够，改菜单发版，过度工程 |
| 代码生成器 | **不做** | 业务表已稳定，一次性写模板比维护生成器划算 |
| 分布式定时任务管理（xxl-job） | **不做** | 现有 `@Scheduled`（MetricsCollector/FileCleanup/RankRefresh）+ Redis 锁已够；需手动触发加 1~2 个 admin 接口即可 |
| 次日/7 日留存 | **二期** | 先做最简单点，不做完整 cohort 矩阵 |
| 多页签 tabsView / 主题定制器 / i18n / 行级数据权限引擎 / SaaS 多租户 / 工作流 | **不做** | 小团队纯负债；管理员全中文（Element Plus 已装 zhCn），页面少切换不频繁 |

---

## 4. 运营数据看板

### 4.1 指标体系（AARRR 分区，控制在 5~10 核心 KPI，剔除 vanity metrics）

| 分区 | 指标 | 形态 | 数据源 |
|---|---|---|---|
| 规模 | 总用户/总帖/总评论/总 AI 问答 | KPI 卡 + 环比箭头 | 实时 `count`（复用 stats） |
| 增长 | 日新增用户 / 日新增帖 | 折线 30/90 天 | `stat_daily` |
| 活跃 | DAU / WAU / MAU | KPI 卡 + 折线 | Redis HLL → `stat_daily` |
| 内容 | 日发帖/评论趋势、热帖 Top10、板块/校区分布 | 折线 + 横向条形 + 饼 | SQL `GROUP BY` |
| 审核 | 待审积压趋势、今日违规数、命中类型分布（`hit_words` vs AI） | 折线 + 饼 | `stat_daily` + `moderation_log` |
| AI 用量 | 日 AI 问答量、活跃问答用户数 | 折线 | `ai_chat_record GROUP BY DATE` |

留存（二期）先做最简「次日/7 日」单点。**运营看板只看不告警**（告警归 Prometheus/Alertmanager）。

### 4.2 接口契约（新增 `StatController`，前缀 `/api/v1/admin/stat`，全部 `@RequirePermission("stat:view")`）

> 返回统一 `Result<T>`，`data` 固定 **camelCase**；聚合一律服务端做，绝不把明细丢前端算；今日数据 Redis 缓存 TTL 1~5min（沿用 `post:list` 5min 先例），历史快照本就不变可长缓存。
> **接口精简**（采纳方案 3 评审 overEngineering 建议）：合并单/多指标趋势为一个 `metrics` 数组接口，控制总数。

| Method & Path | Query | 返回 `data` | 说明 |
|---|---|---|---|
| `GET /api/v1/admin/stat/overview` | — | `{ totalUsers, totalPosts, totalComments, totalAiChats, todayNewUsers, todayNewPosts, moderationPending, userGrowthRate }` | 顶部 KPI 卡（瞬时 + 今日新增 + 环比） |
| `GET /api/v1/admin/stat/trend` | `metrics=newUsers,newPosts,newComments,aiChats,moderationPending` `&days=30` | `{ dates:["2026-06-01",...], series:[{ name, values:[...] }] }` | 多指标趋势（合并单/多） |
| `GET /api/v1/admin/stat/active` | `days=30` | `{ dates:[...], dau:[...], wau:[...], mau:[...] }` | 活跃趋势 |
| `GET /api/v1/admin/stat/distribution` | `dim=board\|campus\|hitType` | `[{ name, value }, ...]` | 分布饼图 |
| `GET /api/v1/admin/stat/top-posts` | `limit=10` | `[{ postId, title, viewCount, likeCount }, ...]` | 热帖 Top |

### 4.3 前端图表组织

- `src/components/BaseChart.vue` 封装 `vue-echarts`（新增前端依赖 `echarts` + `vue-echarts`），开 `autoresize`，依赖组件自身卸载清理防内存泄漏；各图表只传 `option`。
- KPI 卡复用现 `Overview.vue` 的 `stat-card` 样式。
- `Overview.vue` 演进为**三段式**：KPI 卡行（自建）+ 业务趋势/分布（自建 ECharts）+ 基础设施监控（Grafana iframe）。
- `onMounted` 拉一次 + 可选 30~60s 轮询（对齐 Grafana `refresh:30s`），**不上 WebSocket**。

### 4.4 与 Grafana 分工（双轨边界铁律）

| 看板 | 受众 | 数据源 | 承载 |
|---|---|---|---|
| **运营业务**（增长/DAU/内容/审核/AI 趋势） | 运营/产品 | MySQL `stat_daily` + SQL + Redis HLL | 自建 ECharts |
| **系统/JVM/主机/中间件存活** | 运维/开发 | Prometheus `campus_*` Gauge | Grafana 三块看板(business/host/jvm) iframe |

边界铁律：CPU/内存/JVM/HTTP 5xx 留 Grafana，**绝不用 ECharts 重造**；业务长期趋势**绝不压 Prometheus**（retention 仅 15 天 + Gauge 瞬时抽样，做月/季同比失真）。**单一口径**：瞬时总览归 stats、趋势/去重归 SQL/快照、Prometheus 只留系统指标 + `ModerationBacklog>50` 一条业务告警；三处 `is_deleted` 等过滤条件必须一致，口径在一处定义。

---

## 5. 监控集成

- **`MetricsCollector` 现有 6 Gauge + 1 Counter 不动**，继续服务 Grafana + 那 1 条 `ModerationBacklog` 业务告警；运营看板与之双轨并行。
- **修掉已埋坑**：`campus-wall-monitor-ui/src/config.js` 里 Grafana UID 仍是占位符 `campus-overview`，实际 provisioning UID 是 `campus-business`/`host-system`/`jvm-*`。打通后替换，否则 Overview iframe 全白；确认 `GF_AUTH_ANONYMOUS_ENABLED` + `GF_SECURITY_ALLOW_EMBEDDING` 已开、经 nginx `/grafana` 同源反代。
  > 注记（实现阶段更新）：config.js 的 Grafana UID 已替换为真实值 `campus-business` / `host-system` / `jvm-app`（整页 kiosk 内嵌），本节所述「占位 `campus-overview` 待替换」仅为设计时状态。
- **告警 vs 看板职责分离**：系统类告警（`ServiceDown`/`Host*`/`JvmHeap`/`Http5xx`）+ `ModerationBacklog>50` 留 Prometheus/Alertmanager → alert-adapter 转企微/钉钉；运营趋势**不配机器告警**（噪音大、阈值难定，靠人看周报）。
- 可选（非必做）：管理端登录失败暴增 / 审计写失败可接入现有告警链。

---

## 6. 前后端文件落点

### 6.1 后端（`com.jyu.campus.admin` 下增量，贴合现有领域分包）

```
com.jyu.campus.admin/
├── security/
│   ├── RequirePermission.java          # @interface 权限注解
│   ├── AdminAuthInterceptor.java       # 管理端鉴权 + 权限校验 + 黑名单
│   └── AdminJwtUtil.java               # 管理端 token 签发/解析（claim type=admin）
├── audit/
│   ├── OperationLog.java               # @interface 审计注解
│   ├── OperationLogAspect.java         # @Around 切面（首个 AOP）
│   ├── entity/AdminOperLog.java  mapper/AdminOperLogMapper.java
│   ├── service/ (IAuditLogService + impl，@Async 落库)
│   └── controller/AuditLogController.java   # audit:view 只读查询
├── rbac/
│   ├── entity/    AdminUser / AdminRole / AdminPermission / AdminUserRole / AdminRolePermission
│   ├── mapper/    (继承 BaseMapper)
│   ├── service/   IAdminUserService / IAdminRoleService / IAdminAuthService (+impl)
│   └── controller/ AdminAuthController(登录/getUserInfo/踢人) / AdminUserController / AdminRoleController
├── stat/
│   ├── entity/StatDaily.java  mapper/StatDailyMapper.java(聚合 SQL)
│   ├── service/ IStatService (+impl，趋势/分布/DAU + 短 TTL 缓存)
│   └── controller/StatController.java
├── report/   (AdminReportController + IReportService，补 post_report 闭环)
├── user/     (AdminUserMgmtController，封禁/解封，调 social UserService)
└── controller/  AdminModerationController(改：去硬编码登录、加 @RequirePermission + @OperationLog)
                 AdminFeedbackController(新：feedback:reply 管理接口，零改表)
                 AdminStudentVerificationController(改：加权限码 + 审计)

com.jyu.campus.task/
└── StatSnapshotTask.java   # @Scheduled(cron "0 5 0 * * ?")，自行用 RedisLockUtil 加锁（参 MetricsCollector/FileCleanupTask，非 RankRefreshTask）

com.jyu.campus.common/
├── context/RequestContext.java   # 改：新增 adminUserId / dataScope 槽
├── util/JwtUtil.java             # 改：SECRET/EXPIRATION 迁 ${JWT_SECRET}
├── constant/AuthPathConstants.java  # 改：从 PROTECTED_PATHS 移除 /api/v1/admin/**
└── security/interceptor/JwtInterceptor.java  # 改：加被封用户校验（user.status=0 拒绝）

src/main/resources/db/migration/
├── V4.0__rbac_audit_stat.sql   # 6 表 + post_report/user 两处 ALTER
└── V4.1__rbac_init.sql         # 3 角色 + 全量权限码 + 超管账号(哈希取环境变量)

config/SecurityConfig.java   # 改：addInterceptors 末尾追加 AdminAuthInterceptor
pom.xml                      # 改：加 spring-boot-starter-aop（唯一新增核心依赖）
```

### 6.2 前端（`campus-wall-monitor-ui/src` 下增量，贴合现有结构）

```
src/
├── stores/user.js          # 新：useUserStore {token,userInfo,roles,permissions} + login/fetchUserInfo/logout/hasPerm；TOKEN_KEY 沿用 'campus_monitor_token'，来源唯一化
├── directives/permission.js# 新：v-permission 指令 + hasPerm(code) 工具
├── composables/useTable.js # 新：轻量 CRUD hook（loading/分页/查询/reload，吸收 Moderation 的 normalizePage）
├── components/BaseChart.vue# 新：vue-echarts 封装（autoresize）
├── router/index.js         # 改：routes 加 meta.perms；beforeEach token 后加权限交集→/403；通配改显式 403/404，不再 silent redirect /overview
├── layout/MainLayout.vue   # 改：菜单由权限码过滤静态路由生成（不再硬编码）；顶栏显示管理员名/角色/退出
├── api/http.js             # 改：token 来源收敛到 useUserStore；401 跳登录
├── config.js               # 改：Grafana 占位 UID 待打通后替换
└── views/
    ├── Login.vue           # 改：登录后 fetchUserInfo 拿 roles/permissions
    ├── Overview.vue        # 改：三段式（KPI 卡 + 自建 ECharts + Grafana iframe）
    ├── Moderation.vue      # 改：按钮挂 v-permission；用 useTable；消灭 camelCase/snake_case 兼容垫片
    ├── dashboard/          # 新：运营看板（趋势/分布/DAU 图表页）
    ├── Report.vue Feedback.vue Verification.vue UserMgmt.vue   # 新
    ├── system/ AdminUser.vue Role.vue AuditLog.vue            # 新（RBAC + 审计）
    └── error/403.vue 404.vue                                   # 新（显式无权/未找到）
```

> **同步更新 `.claude/CLAUDE.md`**：把「新增管理页面=在 MainLayout 手加菜单」改为「在路由 `meta.perms` 加权限码，菜单自动生成」；新增「管理端鉴权=`@RequirePermission` 注解」与「后端 `Result.data` 固定 camelCase」两条约定。

---

## 7. 分阶段实施路线

| 阶段 | 内容 | 产出物 |
|---|---|---|
| **P0 安全地基** | `V4.0/V4.1` 建表 + 两处 ALTER；`AuthPathConstants` 移除 admin 路径；`AdminJwtUtil`（独立 claim）；`JwtUtil` SECRET 迁 `${JWT_SECRET}`；`AdminAuthController.login` 替换硬编码账号 | 两大安全坑消除，管理端独立账号体系上线 |
| **P1 RBAC 鉴权** | `@RequirePermission` + `AdminAuthInterceptor`（注册末尾）+ 权限码 Redis 缓存 + 踢人黑名单；现有审核/认证接口逐个标注；前端 `useUserStore` + `v-permission` + 路由权限过滤 + 菜单自动生成 + 403 页；登录态收敛 | 完整 RBAC 闭环（3 角色按权限码进出页面/按钮，后端方法级鉴权生效） |
| **P2 审计 + 管理闭环** | 加 `spring-boot-starter-aop`；`@OperationLog` + 切面 + `admin_oper_log` 异步落库；补 `report:handle/ignore`、`feedback:reply`（零改表）、`user:ban/unban`（含 C 端被封校验）+ 审计查看页 | 写操作全审计；举报/反馈/用户管理闭环 |
| **P3 运营看板** | `stat_daily` + `StatSnapshotTask`（00:05 自加 Redis 锁）；DAU HLL 打点；`StatService`/`StatController`（精简 5 接口）+ 短 TTL 缓存；前端 `BaseChart` + dashboard 页；`Overview` 三段式；打通 Grafana 真实 UID | 运营看板上线，业务/系统双轨监控 |
| **P4 二期收尾** | `sys_config` 参数化（迁 AI 阈值/敏感词/限流）+ CRUD；角色权限可视化分配 UI；次日/7 日留存单点；技术债清理（字段契约统一、兼容垫片彻底消除） | 运营可配置化 |

每阶段独立可上线，P0~P3 即覆盖两个锁定决策的全部核心。

---

## 8. 小团队避坑清单

**必修的现存坑：**
1. **管理员复用 C 端 user 表/JWT 域** → 独立 `admin_user` + token claim `type=admin`（P0）。
2. **JWT SECRET 硬编码** → 迁 `${JWT_SECRET}`；发布时注意 C 端旧 token 集体失效，低峰发布或保留旧 SECRET 灰度（P0）。
3. **`/api/v1/admin/**` 仍在 `PROTECTED_PATHS`** → 加管理端拦截器前**必须先移除**，否则双重拦截 + 401 误判（P0/P1，落地必踩）。
4. **细粒度权限堆 `AuthPathConstants` 路径** → 落方法级 `@RequirePermission`，否则 approve/reject 漏判。
5. **`user:ban` 凭空落地** → `user` 表无 status 字段，须 V4.0 加列 + C 端 `JwtInterceptor` 加被封校验，二者缺一封禁不生效（P2）。
6. **审计记全 body / 读接口** → 只记写操作 + 关键 ID，异步落库（复用已有 `@EnableAsync`），不上 MQ。
7. **业务趋势压 Prometheus / 从 user 表算活跃** → 走 `stat_daily` + Redis HLL（user 无 last_active）。
8. **同一指标三处口径打架** → 瞬时归 stats、趋势/去重归 SQL/快照、Prometheus 只留系统 + 1 条审核积压，口径单一来源。
9. **前端 token 四处散读 / `Moderation.vue` 字段兼容垫片** → 收敛 `useUserStore`，后端 `Result.data` 固定 camelCase。
10. **`v-permission` 当鉴权** → 后端每个写接口独立 `@RequirePermission` 兜底。
11. **快照任务复用错文件** → `RedisLockUtil` 先例在 `MetricsCollector`/`FileCleanupTask`，**非 `RankRefreshTask`**（其 00:05 cron 无锁），`StatSnapshotTask` 须自己加锁。
12. **Grafana 占位 UID** → P3 替换真实 UID（`campus-business`/`host-system`/`jvm-*`），否则 Overview iframe 全白。（注记：实现阶段已替换为真实值 `campus-business`/`host-system`/`jvm-app` 整页 kiosk，「占位待替换」仅为设计时状态。）
13. **vue-echarts 内存泄漏** → 统一 `BaseChart.vue` 封装 + `autoresize`，不各页手写 init/resize。

**明确不做（过度工程，统一范围护栏）：**
RBAC1 角色继承 / RBAC2 互斥约束 / dept 部门树 / 5 种 data_scope / 通用 data_scope 引擎 / 可视化菜单管理（sys_menu） / 代码生成器 / 字典独立表 / xxl-job 调度中心 / Metabase / Superset / TimescaleDB / ClickHouse / 多页签 tabsView / 主题定制器 / i18n / SaaS 多租户 / 工作流 / WebSocket 实时推送 / 运营趋势机器告警 / 双 token + 401 静默刷新（管理端账号个位数，续期诚实走「到期跳登录」，若后端日后出 refresh 接口再上并务必带「刷新中标志 + 挂起队列」防并发刷新互相失效）。

> **起步红线**：先 3 角色（superadmin/moderator/viewer）+ 种子数据，先替换硬编码 admin 与「登录即管理员」TODO，**不一上来做细粒度权限矩阵**——权限码可逐步加，表结构已支撑成长。

---

**核心文件绝对路径**
- 后端鉴权链：`/home/nvidia/Desktop/campus-wall/campus_wall/src/main/java/com/jyu/campus/config/SecurityConfig.java`、`.../common/security/interceptor/JwtInterceptor.java`、`.../common/context/RequestContext.java`、`.../common/util/JwtUtil.java`、`.../common/constant/AuthPathConstants.java`
- 现有管理端：`.../admin/controller/AdminModerationController.java`、`.../admin/controller/AdminStudentVerificationController.java`
- 定时/锁先例：`.../task/MetricsCollector.java`、`.../task/FileCleanupTask.java`、`.../task/RankRefreshTask.java`、`.../common/util/redis/RedisLockUtil.java`
- Flyway（现 V3.9，新增从 V4.0）：`/home/nvidia/Desktop/campus-wall/campus_wall/src/main/resources/db/migration/`
- 表 DDL 参考：`.../db/migration/V3.0__baseline.sql`（`user`/`post`/`feedback`/`post_report` 定义）
- 前端：`/home/nvidia/Desktop/campus-wall/campus-wall-monitor-ui/src/router/index.js`、`.../src/api/http.js`、`.../src/layout/MainLayout.vue`、`.../src/config.js`、`.../src/views/Overview.vue`、`.../src/views/Moderation.vue`
