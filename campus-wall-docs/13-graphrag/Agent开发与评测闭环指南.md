# Agent 开发与「数据驱动优化闭环」入门指南

> 面向：已会 LangChain / LangGraph 基本用法、想搞懂「评测驱动优化」整套打法的同学。
> 全程用本项目（校园墙 AI 学长 agent）的真实代码和真实数据举例，不讲空话。

---

## 0. 一句话先建立直觉

**「数据驱动优化闭环」= 先有一把尺子（金标集 + 指标），量出现状（基线），改一处（prompt / 检索 / 模型），再量一次，用数字证明是变好还是变坏。**

没有这把尺子，你改 prompt 全靠「感觉好像顺了」——这叫**盲改**，是新手和工程师最大的区别。

---

## 1. 真实例子：我们刚把「意图准确率」从 95% 提到 100%

这就是一次完整的闭环，五步：

```
①金标集        ②量基线         ③改一处          ④再量           ⑤固化/回归
intent.jsonl → BEFORE 95.0% → 收紧 planner → AFTER 100.0% → 写回 baseline
(80条带标签)   (76/80)        prompt         (80/80)         以后跌5%自动报警
```

具体数据（对线上 Qwen3.6-35B 实测，每次约 90 秒跑完 80 条）：

| 阶段 | 总准确率 | knowledge_qa 召回 | 说明 |
|------|---------|------------------|------|
| BEFORE | 95.0% (76/80) | 80% (16/20) | 一批「怎么补办校园卡 / 怎么申请缓考 / 学生证丢了怎么补办」这类流程问被误判成 `mixed` |
| AFTER  | **100.0% (80/80)** | **100% (20/20)** | 全修好，**零回归**（其它正确条目一个没改坏） |

**改了什么？** 只改了 planner 的一段系统提示词：把「问流程/怎么办理」（有官方标准答案 → 只查知识库）和「明确要经验/攻略/建议」（→ 才同时查知识库+经验帖）**拆开**。一行 prompt 的事，但因为有金标集，我们能**证明**它确实有效、且没把别的搞坏。

> 这就是为什么要先有评测：同样改一段 prompt，有尺子的人能说「95%→100%，修好 3 个零回归」，没尺子的人只能说「我觉得改好了」。

---

## 2. 金标集（golden set / 评测集）是什么

### 定义
**金标集 = 一批「输入 + 人工标注的正确答案」的样本集合**，用来当「标准答案」去考你的系统。"金标"=golden label=被认定为正确的参考答案。

### 一条金标长什么样
本项目 `campus-wall-ai/evals/datasets/intent.jsonl`，每行一条（JSONL = 一行一个 JSON）：

```json
{"question": "怎么补办校园卡",        "expected_intent": "knowledge_qa"}
{"question": "考研有什么经验或者攻略吗", "expected_intent": "mixed"}
{"question": "帮我发个二手帖出闲置iPad", "expected_intent": "create_post"}
```
- `question` = **输入**（喂给 agent 的）
- `expected_intent` = **人工标注的正确答案（label）**

找帖的金标 `post_search.jsonl` 复杂一点，因为答案是「应该召回哪些帖子」：
```json
{"query": "丢了蓝色书包", "expected_post_ids": [1234], "must_not_ids": [5678]}
```
- `expected_post_ids` = 应该命中的帖子（真实库里的 ID，见第 4 节）
- `must_not_ids` = **绝对不该命中**的帖子（反例，专门测「会不会瞎答」）

### 为什么必须有它
- **可量化**：把「好不好」变成一个能比大小的数字（准确率、召回率…）。
- **可回归**：改完能立刻知道有没有把原来对的搞坏（回归 = regression）。
- **可沟通/可写简历**：「意图准确率 95%→100%」比「我优化了一下」有说服力 100 倍。

### 金标集 vs 训练集（别搞混）
- **训练集**：喂给模型「学」的（微调时用）。
- **金标集 / 测试集**：模型**没见过**、专门用来「考」的。我们不微调 35B，只用它**评测+对比 prompt**，所以这里主要是「评测集」。

---

## 3. 金标集一般需要多少条

没有唯一答案，按**用途**和**统计可信度**定。经验值：

| 用途 | 规模（每类 / 总量） | 说明 |
|------|------|------|
| 冒烟自测（跑通流程） | 每类 3~5 条 | 我们最早的占位集就是这量级，只验证管道能跑 |
| **日常迭代对比**（最常用） | **每类 10~20 条 / 总 50~100** | 改 prompt 时 A/B 用，能看出明显涨跌。本项目意图集现在 **80 条（每类 20）** |
| 验收 / 上线门禁 | 每类 30~50 条 / 总 150~300 | 数字够稳，可当 CI 红线 |
| 出报告 / 论文级 | 每类 100+ / 总 500~1000+ | 置信区间窄，能下「显著提升」结论 |

### 关键直觉：样本越少，数字越「飘」
- 22 条时测出 95.5%，80 条时测出 95.0%——**不是退步，是样本变多后更准了**。
- n=22 的 95% 置信区间约 ±9%（即真实值可能在 86%~100%）；n=80 缩到约 ±5%；n=300 才到 ±2% 左右。
- **所以**：拿小样本测出的单个数字别太当真，要么多跑几次取平均（应对 temperature 抖动），要么把集子扩大。

### 比「多」更重要的是「标得准」+「覆盖边界」
- 50 条**标注精准、覆盖各种坑**的，胜过 500 条随手标的。
- 一定要放**负样本/对抗样本**：如「校长私人手机号是多少」（应答"暂无"而不是编造）、「无关帖不该命中」。系统**不犯错**和**会答对**一样重要。
- 我们这次（后来扩到 80 条）特意补了「怎么办理 X」这类**边界样本**，正好暴露并修掉了 prompt 的弱点——这叫**针对性扩集**。

---

## 4. 「真实库 postId」是什么

### 先看数据模型
校园墙的帖子存在**两个地方**：
1. **MySQL `posts` 表**（Java 后端的权威数据）——每条帖子有主键 `id`（自增整数），就是 **postId**。
2. **Neo4j**（AI 服务的知识图谱+向量库）——每条帖子入库为一个 `Post {postId: ...}` 节点 + 一个 `Item`（含 bge-m3 向量）节点。`postId` 和 MySQL 的 `id` 是同一个数。

> 所以 **postId = 某条具体帖子的唯一编号**，比如「#1234 二手 iPad Air 5」里的 1234。

### 为什么找帖金标要填「真实 postId」
找帖评测要算「检索召回的帖子里，有没有命中**应该命中**的那条」。要比对，就得知道「正确答案是哪条帖子」——也就是它的 **postId**。

`post_search.jsonl` 里 `expected_post_ids` 现已填好真实锚定帖 `postId`（90001 起，跑在独立 test Neo4j 实例 7689 上），所以找帖指标已经能算了。当初让它生效做了两步：
1. 在 test 库里造一批锚定帖（`eval_anchor`，如「丢了蓝色书包」一条，记下它的 id）；
2. 把这个真实 id 填进金标的 `expected_post_ids`。

现在的基线（test 实例实测）：hit/recall@k = 1.0、judge_f1 ≈ 0.93、must_not_shown = 0。

### 怎么拿到真实 postId
- 查 MySQL：`SELECT id, category, content FROM posts WHERE ... LIMIT 20;`
- 或查 Neo4j：`MATCH (p:Post) RETURN p.postId, p.text LIMIT 20;`
- 或用 `GraphStore.ingest_post(...)` 主动灌一条锚定帖，返回里就有 id。

> 这也是为什么**意图准确率先做、找帖准确率随后也已跑通**（在填好锚定 postId 之后）：意图判定只调一次 35B、不碰库（不需要 postId）；找帖要连真实库、要真实 postId 当答案，所以等独立 test 实例与锚定帖就位后才补上。

---

## 5. 数据驱动优化闭环（完整版）

```
        ┌─────────────────────────────────────────────────┐
        │                                                 │
        ▼                                                 │
 ① 建金标集 ──▶ ② 量基线 ──▶ ③ 提一个假设并改一处 ──▶ ④ 复测对比 ──┘
 (输入+正确答案)  (baseline)   (prompt/检索/模型，一次只改一个)  (涨? 跌? 回归?)
                                                          │
                                          涨且无回归 ──▶ ⑤ 固化为新基线
                                          跌或有回归 ──▶ 回滚，换假设
```

要点：
- **一次只改一个变量**（prompt 或检索或模型），否则涨跌归因不清。
- **复测要控制随机性**：LLM 有 temperature，同输入多次输出可能不同。我们这次关掉缓存、跑了 **3 次** AFTER 都是 100% 才敢说「稳定」。
- **基线（baseline）= 防回归红线**：`evals/baseline.json` 存住当前指标；以后谁改 prompt，跑一遍 `python -m evals.run`，跌超 5% 退出码非 0、自动报警。这就是「闭环」里**防止越改越烂**的那道闸。
- 本项目跑法：`APP_ENV=test python -m evals.run --only intent`（`APP_ENV=test` 让 config.py 自动加载 `.env.test` 切到 test 环境；意图项只需 35B，~90 秒，不连 Neo4j）。

---

## 6. Agent 开发的一般流程

一个 LLM agent 从想法到上线，典型生命周期（括号里是本项目对应物）：

```
1. 定义任务与边界   —— agent 要解决什么、有哪些工具、不做什么
   (校园墙: 找帖/知识问答/AI发帖; 只读工具 search_posts/knowledge_qa)

2. 设计编排骨架     —— 用 LangGraph 把"节点"连成图：理解→规划→执行工具→检查→合成
   (contextualize→vision→plan→execute→gate→synthesize, 见 app/agent/graph.py)

3. 写工具与提示词   —— 每个节点的 system prompt + 工具函数
   (app/agent/prompts.py + tools.py)

4. 接地与防幻觉     —— 让它"只依据检索证据说话"，不编
   (RelevanceJudge 判定闸 + Synthesizer 严格接地规则)

5. ★建评测闭环★    —— 金标集 + 指标 + 基线（本指南主角）
   (evals/)

6. 可观测性        —— 埋点看每步耗时/调用次数/命中率，定位瓶颈
   (app/metrics.py + /metrics, Prometheus+Grafana)

7. 健壮性          —— 超时、降级、缓存、限流（别让一个慢调用拖垮整条链）
   (全局 wall-clock 预算、Redis 缓存、单槽防雪崩)

8. 迭代优化        —— 回到第 5 步：量→改→再量，持续提指标
   (这次的 95%→100% 就是一次第 8 步)

9. 上线与监控      —— 部署，线上看指标，发现新问题再回流成金标
```

**新手最容易跳过的是 5、6、7**——只顾着第 2~4 步把功能"做出来"，但没有 5 就不知道好不好、没有 6 就不知道慢在哪、没有 7 一上量就崩。**会做这三步，是从"能写 demo"到"能做产品"的分水岭。**

> 顺序不是死的：实践中常是「先搭骨架跑通 → 立刻补一个最小金标集 → 边迭代边扩集」。先有把粗尺子，比追求完美金标更重要。

---

## 7. 简历怎么写（诚实版，重要）

你问「是不是可以写『通过优化 prompt 提高意图准确率』」——**可以，但要等真做完且数字站得住，并写清方法和量化**。

### ✅ 现在（这次迭代后）你可以诚实地写
- 「为校园墙 AI agent **搭建了意图分类评测体系**（金标集 + 准确率/混淆矩阵指标 + 基线回归），并通过**优化 planner 提示词**将路由意图准确率从 **95% 提升至 100%**（80 条标注集，对线上 35B 实测、3 次复跑稳定）。」
- 「设计**数据驱动的 prompt 优化闭环**：金标集量化基线 → 假设驱动改一处 → A/B 复测 → 基线防回归，定位并修复了『流程类问题被误判为混合意图』的缺陷。」

为什么这样写站得住：**有金标集、有 before/after 数字、有方法论、有复现命令**——面试官追问你答得上来。

### ❌ 别这么写（会被追问到穿帮）
- 「将意图准确率提升到 99%」——不说基线、不说样本量、不说怎么测，等于没说，且经不起追问。
- 「优化模型提升准确率」——你没碰模型，碰的是 prompt 和评测。用词要准。
- 把 80 条小样本的 100% 吹成「生产级 99%+ 准确率」——n=80 的 100% 置信区间仍有 ±几个点，**扩到几百条再下大结论**。

### 一句话原则
**简历可写 = 你能在面试白板上复现的**。这次的闭环你完全能复现，所以放心写——但写**方法+量化**，别写光秃秃的结论。

---

## 8. 你的下一步学习路径

你现在会 LangChain/LangGraph 基本用法，往「能做产品的 agent 工程师」走，建议按这个顺序补：

1. **评测**（你正在学）：把金标集扩到每类 30+；学会 precision/recall/F1、混淆矩阵、置信区间的直觉。
2. **可观测性**：跑起来本项目的 `/metrics` + Grafana，看真实的 LLM 调用次数/耗时直方图，理解「单槽排队」这种真实瓶颈。
3. **RAG 评测**：锚定 postId 已填好，`post_search` 的 hit_rate/recall 和 `judge_f1` 已跑通（test 实例 hit/recall=1.0、judge_f1≈0.93），跟着读一遍体会「检索质量」怎么量。
4. **健壮性工程**：读本项目的全局 timeout（`app/agent/nodes.py` 的 `over_budget`）和缓存（`app/cache.py`），理解生产 agent 怎么防雪崩。
5. **进阶**：LLM-as-judge（用小模型当裁判自动评 groundedness，本项目 `evals/run.py` 已有）、对抗式评测、A/B 上线。

---

## 9. 进阶答疑（环境隔离 / 数据同步 / 微调 / 代码位置）

### 9.1 要不要专门的测试数据库？开发/测试/生产三套环境？

**要，你的直觉对。** 标准是三套环境，互不污染：

| 环境 | 用途 | 数据 |
|---|---|---|
| **dev** 开发 | 本地随便改/造数据 | 假数据，可随时清 |
| **test/staging** 测试 | 跑评测、自动化测试、上线前验证 | 专门、干净、可复现的金标数据 |
| **prod** 生产 | 真实用户 | 真实数据，**绝不能混入测试数据** |

**本项目怎么做的（已落地）**：Neo4j 是**社区版只能单库**，所以给每套环境**各起一个独立 Neo4j 容器**——已纳入 `campus-wall-ops/docker-compose.yml`（服务 `neo4j-dev` / `neo4j-test`，`restart: unless-stopped`），三实例分端口：**prod 7688 / test 7689 / dev 7691**：
```yaml
# campus-wall-ops/docker-compose.yml 摘录
neo4j-test:
  image: neo4j:5.26
  container_name: campus-neo4j-test
  ports: ["7690:7474", "7689:7687"]   # HTTP / Bolt
  environment:
    NEO4J_AUTH: neo4j/${NEO4J_TEST_PASSWORD:-testpass123}
  volumes: [campus-neo4j-test-data:/data]
  restart: unless-stopped
```
- 配置用三套 env 模板隔离：`.env.dev.example` / `.env.test.example` / `.env.prod.example`（隔离点=不同 Neo4j 实例/库 + 不同 Redis DB 号(0/1·2/15) + 不同 MySQL schema(campus_wall / campus_wall_dev_* / campus_wall_test)）。
- 代码加了 `NEO4J_DATABASE` 旋钮：社区版留空（单库），将来上 Enterprise/Aura 可按环境分库。
- **评测只跑在 test 实例**：`APP_ENV=test python -m evals.run`（团队约定的「一个变量切环境」入口——config.py 据 `APP_ENV` 自动加载 `.env.test`，`.vscode/launch.json` 的「评测 · test」配置即用 `APP_ENV=test`）——锚定帖只进 test，永远不会被真实用户搜到。

> 反面教材（本项目真实发生过）：评测锚定帖一度被直接插进了**共享 dev Neo4j**——也就是线上 AI 服务正在查询的库。后果：真实用户搜索时可能搜到这些造的测试帖。**这正是为什么要环境隔离。** 现已清理并迁到独立 test 实例。

### 9.2 只往 Neo4j 插数据、没插 MySQL，会数据不同步吗？

**会，而且这是个很重要的点。** 校园墙的帖子是**双写**的：

```
用户发帖 → /api/v1/posts/publish (Java)
            ├─ 写 MySQL posts 表（权威数据：id/作者/状态/可见性）
            └─ 触发 PostAiIngestService → 调 AI /ingest-post → 写 Neo4j（Post/Item + bge-m3 向量，供检索）
```
- **MySQL 是权威源**（谁发的、删没删、可不可见）；**Neo4j 是检索副本**（向量语义搜索）。
- 我（评测时）只调了 `ingest_post` 写 Neo4j、**没写 MySQL** → 产生了「Neo4j 有、MySQL 没有」的**孤儿数据**。

**真实影响（有意思的一点）**：agent 找帖时，`search_posts` 拿到 Neo4j 候选后，会走 **`post_hydrator` 回调 Java** 按 MySQL 做可见性过滤（`app/agent/hydrator.py`）。**MySQL 里没有的帖子会被 Java 判为「不存在」直接丢弃**——所以这些只在 Neo4j 的孤儿帖，**在真实 agent 路径里根本不会展示给用户**。
- 这也解释了：我的评测能查到锚定帖（因为 `eval_post_search` 直接调 `match_posts`+`judge`，**绕过了 hydrator**），但真实 agent 不会。
- **正确做法**：测试数据要么走完整发帖流程（双写一致），要么用**独立 test 环境**整套自洽（test 的评测绕过 hydrator，只需 test Neo4j 一致即可）——本项目选了后者。

### 9.3 金标集对每个模型都一样吗？换模型要重新优化吗？

- **金标集本身与模型无关**：它是「标准答案」，不随模型变。**换模型，金标集照用，不重做。**
- **但「测出的分数」和「最优 prompt」是模型相关的**：同一份金标，35B 测 100%，换 7B 可能 85%；为 35B 调好的 prompt 换模型后可能要重调。
- 所以：**金标集 = 固定的尺子；换模型 = 拿同一把尺子重新量**，立刻知道新模型好了还是坏了。这正是金标集在「换模型/降本」决策里的最大价值。

### 9.4 训练集是用来微调的吗？我的 agent 要微调吗？

- **训练集 = 喂模型「学」的数据（微调用），模型见过；金标集 = 考模型的，模型没见过。** 两者完全不同。
- **你的 agent 不需要微调，也强烈建议别碰。** 你是在**用** 35B（prompt + RAG 调用），不是**训练**它。能提升效果的杠杆是 **prompt 工程 + 检索质量 + 评测闭环**——零成本、几分钟一轮（95%→100% 就是例子）。
- 微调要几千条标注、GPU、防过拟合、改一版几小时～几天，对校园项目性价比极低。**只有 prompt 怎么调都达不到、且有大量领域数据、且要压成本/延迟时才考虑**——你远没到。
- 一句话：**99% 的 agent 开发不需要微调，靠 prompt+RAG+评测就够。**

### 9.5 我的「接地与防幻觉」「可观测性」在哪段代码？

**接地与防幻觉**（你项目最硬核的部分）：

| 机制 | 位置 | 作用 |
|---|---|---|
| 相关性判定闸 | `app/agent/relevance.py` | LLM 只挑真正相关的帖(宁缺毋滥)，把无关帖挡外面 |
| fruitful 闸门 | `app/agent/nodes.py` `gate()` | 检索 0 命中不准拿空证据编答案，触发重规划 |
| 严格接地提示词 | `app/agent/prompts.py` `SYNTHESIZER_SYS` | "只依据检索证据，没有的绝不编造" |
| 找不到就说找不到 | `app/agent/tools.py` `search_posts` | 判定后为空 → 明确"未找到" |
| 知识问答接地 | `app/graphrag/qa.py` `ANSWER_SYS` | 资料不足就说"暂无相关校园信息" |

量化它好不好：评测里的 `judge_f1`、`must_not_shown=0`、`knowledge_qa.refusal_rate` 就是在测「防幻觉到底防得怎么样」。

**可观测性**：

| | 位置 |
|---|---|
| 指标定义 | `app/metrics.py`（LLM 调用数/耗时/单槽排队、整轮耗时、replan、超时、缓存命中、工具命中） |
| 暴露端点 | `app/main.py` `GET /metrics`（Prometheus 文本格式） |
| 埋点位置 | `llm.py`(role 标签)、`nodes.py`(replan/timeout)、`tools.py`、`service.py`(整轮) |
| 看板 | ops Prometheus 抓 `:8011/metrics` → Grafana |

---

## 附：本项目评测相关文件速查

| 文件 | 作用 |
|------|------|
| `campus-wall-ai/evals/datasets/intent.jsonl` | 意图金标集（80 条，每类 20） |
| `campus-wall-ai/evals/datasets/post_search.jsonl` | 找帖金标（已填锚定 postId 90001 起，test 实例） |
| `campus-wall-ai/evals/datasets/knowledge_qa.jsonl` | 知识问答金标（含对抗样本） |
| `campus-wall-ai/evals/metrics.py` | 指标纯函数（accuracy/recall/precision/f1/混淆矩阵） |
| `campus-wall-ai/evals/run.py` | 评测运行器（`python -m evals.run [--only intent]`） |
| `campus-wall-ai/evals/baseline.json` | 基线（防回归红线） |
| `campus-wall-ai/app/agent/prompts.py` | 各节点系统提示词（这次优化的就是 `PLANNER_SYS`） |
| `campus-wall-ai/app/agent/graph.py` | LangGraph 节点编排骨架 |

跑一次意图评测：
```bash
cd campus-wall-ai
APP_ENV=test python -m evals.run --only intent     # APP_ENV=test 切到 test 环境；需能连内网 35B(.101:8003)，约 90 秒
```
