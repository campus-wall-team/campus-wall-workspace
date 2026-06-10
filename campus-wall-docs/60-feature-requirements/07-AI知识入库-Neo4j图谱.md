# 07 · AI 知识入库(Neo4j 图谱)

> AI 三篇之二(**存储层**)。本篇解决"用户发帖后,如何把 [`06`](./06-AI视觉模型与图片标注.md) 产出的物品描述 + 帖子元数据写进 Neo4j",为 [`08`](./08-AI智能推荐与问答.md) 的检索推荐建立可查询的知识图谱。

## 一、概述

### 目标
用户发帖(图片 + 文字 + 板块 + 标签)成功后,**异步**把帖子转成知识图谱中的 `Post`/`Item` 节点(带向量),使"捡到 X""出售 Y"的帖子可被后续提问检索到。

### 端到端流程
```
发帖 → PostController /publish → PostPublishService(@Transactional)
   └─ afterCommit:图片 move 到正式路径后
        └─ @Async PostAiIngestService.ingestPostAsync(post)
             └─ GraphRagBackend.ingestPost(...)  → POST graphrag /ingest-post
                  ├─ 对每张图 describe_image(VLM)  ← 06
                  ├─ 融合 + scrub_text 脱敏        ← 06
                  ├─ embed_one(description)        ← 本地 bge-m3·本地优先(同模型云端降级)
                  └─ 写 Neo4j:Post/Item + campus_post_vector 向量
```

### 对应需求原文(摘要)
> 将其他特征和用户a的描述一起存入到 Neo4j 的数据库中……(无文字时)对这个图片进行描述后存入 Neo4j 的数据库中……对于兼职发布类,还有组队类,也是同样的原理。

## 二、现状与可复用资产

| 资产 | 位置 | 复用点 |
|------|------|--------|
| `ensure_schema()` 约束 + 向量索引创建写法 | `graphrag/app/graph_store.py:58-74` | 照此加 `Post`/`Item` 约束与 `campus_post_vector` |
| `index_document` 的 MERGE/删旧重建模式 | `graph_store.py:77-110` | `ingest_post` 仿此 |
| `_delete_doc_tx` 幂等删除 | `graph_store.py:152-165` | `_delete_post_tx` 仿此 |
| `embed_one()`(本地优先+降级) | `llm.py` | Item 向量化(本地 bge-m3;⚠️ 降级须同模型) |
| `describe_image()` / `scrub_text()` | `06` 新增 | 读图 + 脱敏 |
| graphrag HTTP 代理 + `postForMap` | `campus_wall/.../ai/service/rag/GraphRagBackend.java`(现有 `query/index/...`) | 加 `ingestPost` |
| `graphrag.base-url` 配置 | `application-dev.yaml`(默认 `:8001`) | Java 调 graphrag |
| 发帖事务 + `afterCommit` 移图钩子 | `community/service/impl/PostPublishService.java`(`movePostImagesAsync`) | 在移图后挂入库 |
| 图片公开代理 | `admin/.../FileController` `GET /api/v1/files/view`(在 `AuthPathConstants.PUBLIC_PATHS`,免 JWT) | graphrag 取图 |
| objectName→URL | `common/util/MinioUtil.getFileUrl` | 拼图片地址 |
| 启动类 | `CampusWallBackendApplication`(`@EnableScheduling`) | 补 `@EnableAsync` |
| 定时任务范式 | `task/FileCleanupTask`(`@Scheduled`) | 入库失败补偿任务 |

## 三、技术方案(如何实现)

### 3.1 接口决策:新增 `POST /ingest-post`(不复用 `/index`)

`/index` 语义是"文档灌库"(被 data-pipeline 与知识库管理依赖,建 `Document/Chunk`)。帖子有 `intent/category/post_id/images` 强结构,且要建 `Post/Item`。**新增独立端点**,两条入库路径并存、互不影响。

### 3.2 Neo4j 建模

```
(:Post {postId, intent, category, text, status, createdAt})
(:Item {id, description, embedding, category, color, brand, model, features})
(:Intent {name})     (:Category {name})     (:Tag {name})

(Post)-[:DESCRIBES]->(Item)
(Post)-[:HAS_INTENT]->(Intent)
(Post)-[:IN_CATEGORY]->(Category)
(Post)-[:TAGGED]->(Tag)
```

`ensure_schema()` 追加(沿用现有写法):

```python
s.run("CREATE CONSTRAINT post_id IF NOT EXISTS FOR (p:Post) REQUIRE p.postId IS UNIQUE")
s.run("CREATE CONSTRAINT item_id IF NOT EXISTS FOR (i:Item) REQUIRE i.id IS UNIQUE")
s.run(
    f"CREATE VECTOR INDEX {settings.POST_VECTOR_INDEX_NAME} IF NOT EXISTS "
    "FOR (i:Item) ON (i.embedding) "
    "OPTIONS {indexConfig: {`vector.dimensions`: $dim, "
    "`vector.similarity_function`: 'cosine'}}",
    dim=settings.EMBED_DIM,
)
```

> 复用现有 `EMBED_DIM=1024`(bge-m3);`POST_VECTOR_INDEX_NAME` 默认 `campus_post_vector`(新增配置,见 `06` 配置表的同批新增)。**注意现有 Chunk 索引 `campus_chunk_vector` 是 `FOR (c:Chunk)`,不能复用,Item 必须用独立索引。**

### 3.3 `ingest_post()` 实现(`graph_store.py` 新增)

```python
from urllib.parse import quote
from . import sanitize

def _image_url(self, img: dict) -> str:
    """优先用传入 url,否则用 object_name 经 Java 公开端点拼。"""
    if img.get("url"):
        return img["url"]
    on = img.get("object_name")
    return f"{settings.BACKEND_BASE_URL}/api/v1/files/view?objectName={quote(on)}" if on else ""

def ingest_post(self, post_id, intent, category, text, images, tags) -> dict:
    # 1. 逐图读图(06),聚合属性与描述
    descs, attrs = [], {}
    for img in images:
        url = self._image_url(img)
        d = llm.describe_image(url, text, intent) if url else {}
        if d:
            if d.get("description"): descs.append(d["description"])
            for k in ("category", "color", "brand", "model"):
                if d.get(k) and not attrs.get(k): attrs[k] = d[k]
            if d.get("features"): attrs.setdefault("features", []).extend(d["features"])

    # 2. 融合 + 脱敏(联系方式等 PII 不入图谱)
    fused = sanitize.scrub_text(" ".join([text] + descs).strip())
    emb = llm.embed_one(fused) if fused else None
    item_id = f"post:{post_id}:item"
    created = datetime.now(timezone.utc).isoformat()

    # 3. 写图谱(幂等:重发帖先删旧 Item)
    with self._driver.session() as s:
        self._delete_post_tx(s, post_id)
        s.run(
            "MERGE (p:Post {postId:$pid}) "
            "SET p.intent=$intent, p.category=$category, p.text=$text, "
            "    p.status=1, p.createdAt=$created",
            pid=post_id, intent=intent, category=category, text=fused, created=created,
        )
        s.run(
            "MATCH (p:Post {postId:$pid}) "
            "CREATE (i:Item {id:$iid, description:$desc, category:$cat, "
            "                color:$color, brand:$brand, model:$model, features:$feat}) "
            "SET i.embedding=$emb "
            "MERGE (p)-[:DESCRIBES]->(i)",
            pid=post_id, iid=item_id, desc=fused, cat=category,
            color=attrs.get("color",""), brand=attrs.get("brand",""),
            model=attrs.get("model",""), feat=attrs.get("features",[]), emb=emb,
        )
        s.run("MATCH (p:Post {postId:$pid}) MERGE (n:Intent {name:$intent}) "
              "MERGE (p)-[:HAS_INTENT]->(n)", pid=post_id, intent=intent)
        if category:
            s.run("MATCH (p:Post {postId:$pid}) MERGE (c:Category {name:$cat}) "
                  "MERGE (p)-[:IN_CATEGORY]->(c)", pid=post_id, cat=category)
        for tg in tags or []:
            s.run("MATCH (p:Post {postId:$pid}) MERGE (t:Tag {name:$tg}) "
                  "MERGE (p)-[:TAGGED]->(t)", pid=post_id, tg=tg)
    return {"post_id": post_id, "item_id": item_id,
            "description": fused, "indexed": emb is not None}
```

`_delete_post_tx` 仿 `_delete_doc_tx`:删除该 Post 的 `Item` 并解除关系(便于重发帖/编辑后重灌)。

### 3.4 Pydantic 模型 + 端点(`main.py` 新增)

```python
class PostImage(BaseModel):
    object_name: Optional[str] = None
    url: Optional[str] = None

class IngestPostRequest(BaseModel):
    post_id: int
    intent: str = "daily"          # lost_found | second_hand | part_time | team_up | daily
    category: Optional[str] = None
    text: str = ""
    images: List[PostImage] = []
    tags: List[str] = []

class IngestPostResponse(BaseModel):
    post_id: int
    item_id: str
    description: str
    indexed: bool

@app.post("/ingest-post", response_model=IngestPostResponse)
def ingest_post(req: IngestPostRequest):
    store.ensure_schema()
    res = store.ingest_post(
        req.post_id, req.intent, req.category, req.text,
        [img.model_dump() for img in req.images], req.tags,
    )
    return res
```

### 3.5 触发时机(Java 侧:`afterCommit` + `@Async`)

项目无 MQ,但已有异步先例。落点关键:**必须在图片 move 到 `posts/{postId}/` 正式路径之后**入库(VLM 取图要用正式 objectName)。

```java
// PostPublishService.publishPost 现有钩子(已确认,约 line 118-121):
TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
    @Override
    public void afterCommit() {
        movePostImagesAsync(finalPostId, originalImages);   // 现有:move 到正式路径 + 回写 imagesJson
    }
});
```

**接入点**:在 `movePostImagesAsync`(约 line 173)内部 move 完成、`updateById` 回写 `imagesJson` **之后**,追加一行 `postAiIngestService.ingestPostAsync(post, finalObjs)`(此时 objectName 已是正式路径)。**不要**直接在 `afterCommit` 里、move 之前调用,否则可能取到临时/失效 objectName。

`PostAiIngestService`(新建,`@Async("aiIngestExecutor")`):

```java
@Async("aiIngestExecutor")
public void ingestPostAsync(Post post, List<String> imageObjectNames) {
    String intent = resolveIntent(post);                  // 见 3.6
    String text   = EmojiUtil.decode(post.getContent());  // 复用现有
    List<String> tags = splitTags(post.getAiTags());
    // 只传 object_name,graphrag 侧拼 /files/view URL;contact 不传(隐私)
    for (int attempt = 1; attempt <= 3; attempt++) {
        try {
            ragBackend.ingestPost(post.getId(), intent, post.getCategory(),
                                  text, imageObjectNames, tags);
            return;
        } catch (Exception e) {
            log.warn("ingestPost 第{}次失败 postId={}", attempt, post.getId(), e);
            sleepBackoff(attempt);
        }
    }
    ingestRetryService.markFailed(post.getId());           // 落补偿,见 3.7
}
```

`AsyncConfig`(新建)定义 `aiIngestExecutor`(core 2 / max 4 / queue 100);`CampusWallBackendApplication` 加 `@EnableAsync`。

`GraphRagBackend.ingestPost`(复用现有 `postForMap`):

```java
public Map<String,Object> ingestPost(Long postId, String intent, String category,
                                     String text, List<String> imageObjectNames, List<String> tags) {
    Map<String,Object> body = new HashMap<>();
    body.put("post_id", postId);
    body.put("intent", intent);
    body.put("category", category);
    body.put("text", text);
    body.put("images", imageObjectNames.stream()
            .map(on -> Map.of("object_name", on)).collect(Collectors.toList()));
    body.put("tags", tags);
    return postForMap("/ingest-post", body);   // 现有私有方法
}
```

### 3.6 intent 解析(语义意图 ≠ 板块)

意图比板块更细(板块无"失物招领",但 AI 场景有"捡到")。`resolveIntent(post)` 优先级:

1. `PostDTO.intent`(可选,前端发帖时按板块/选项带上)——最准;
2. 否则按 `category` 映射:二手交易→`second_hand`、兼职发布→`part_time`、组队→`team_up`;
3. 否则按内容关键词:含"捡到/拾到/寻物/失物/丢了"→`lost_found`;
4. 兜底 `daily`。

> 失物招领可由"推荐板块 + `#失物招领`/`#寻物` 标签"或关键词识别,5 板块设计无需改动。建议给 `PostDTO` 增可选 `intent` 字段(见 `01` 4.3 延伸),前端在失物/寻物场景显式带上。

### 3.7 失败补偿

`ingestPostAsync` 三次重试仍失败 → 写一张轻量 `ai_ingest_failed(post_id, reason, create_time)` 表(或复用日志表);新建 `PostIngestRetryTask`(`@Scheduled`,仿 `FileCleanupTask`)定时重灌。保证最终一致。

## 四、配置变更

| 变量 | 默认 | 位置 | 说明 |
|------|------|------|------|
| `POST_VECTOR_INDEX_NAME` | `campus_post_vector` | graphrag `config.py` | Item 向量索引名 |
| `BACKEND_BASE_URL` | `http://host.docker.internal:8080` | graphrag `config.py` | graphrag 取图时拼 `/files/view` 的 Java 后端地址 |

> VLM 相关变量见 [`06` 第四节](./06-AI视觉模型与图片标注.md#四配置变更)。

## 五、改动清单

### graphrag(`campus-wall-graphrag`)
| 文件 | 改动 |
|------|------|
| `app/config.py` | 加 `POST_VECTOR_INDEX_NAME`、`BACKEND_BASE_URL` |
| `app/graph_store.py` | `ensure_schema` 加 Post/Item 约束 + `campus_post_vector`;新增 `ingest_post`、`_delete_post_tx`、`_image_url` |
| `app/main.py` | 加 `PostImage`/`IngestPostRequest`/`IngestPostResponse` + `POST /ingest-post` |

### Java(`campus_wall`)
| 文件 | 改动 |
|------|------|
| `CampusWallBackendApplication.java` | 加 `@EnableAsync` |
| `config/AsyncConfig.java`(新建) | `aiIngestExecutor` 线程池 |
| `ai/service/rag/IRagBackend.java` + `GraphRagBackend.java` | 加 `ingestPost`(复用 `postForMap`) |
| `community/service/impl/PostAiIngestService.java`(新建) | `@Async` 入库 + intent 解析 + 重试 |
| `community/service/impl/PostPublishService.java` | `afterCommit` 移图后调 `ingestPostAsync` |
| `community/dto/PostDTO.java` | (可选)加 `intent` 字段 |
| `task/PostIngestRetryTask.java`(新建,可选) | 失败补偿重灌 |

## 六、实现步骤

1. graphrag:`config` 加变量 → `graph_store` 加 schema/`ingest_post` → `main` 加端点;`curl` 测 `/ingest-post`。
2. Java:`@EnableAsync` + `AsyncConfig` + `GraphRagBackend.ingestPost` + `PostAiIngestService`。
3. 在 `PostPublishService` 移图后挂入库调用。
4. 联调:发一条带图二手帖 → 确认 Neo4j 出现 `Post`/`Item` 节点 + 向量;关闭 VLM 时仅文字入库不报错。
5. (可选)补偿任务与失败表。

## 七、验收标准

- [ ] 发带图帖后,Neo4j 中出现对应 `(:Post {postId})-[:DESCRIBES]->(:Item)`,`Item.embedding` 长度=1024。
- [ ] 有图有文:`Item.description` 比用户原文更丰富(含图片识别的额外特征)。
- [ ] 有图无文:`Item.description` 为 VLM 纯图描述。
- [ ] `Post` 带正确 `intent`/`category`,并连到 `Intent`/`Category`/`Tag` 节点。
- [ ] 入库为异步,**不阻塞**发帖响应;graphrag 不可用时发帖仍成功,失败进补偿。
- [ ] `Item.description` 不含明文手机号/微信号(脱敏生效)。
- [ ] 重复对同一帖入库(编辑/重试)不产生重复 `Item`(幂等)。

## 八、风险与待确认项

1. **取图地址连通**:graphrag 容器经 `BACKEND_BASE_URL`(`host.docker.internal:8080`)访问 `/files/view`;需联调确认容器→宿主机 8080 可达(docker-compose `extra_hosts` 已配)。
2. **图片 move 时序**:AI 入库必须在图片 move 完成、`imagesJson` 为正式路径后触发;若现有 `movePostImagesAsync` 自身异步,需把入库串在其完成回调,避免取到临时/失效 objectName。
3. **联系方式不入图谱**:`contact` 字段**不传** graphrag;graphrag 再用 `scrub_text` 兜底。用户联系走帖子详情页站内私信(见 `08`)。
4. **匿名帖**:`Post` 节点只存 `postId`,不落 `user_id` 明文;"找作者"由 Java 侧用 postId 反查。
5. **编辑/删除同步**:帖子被删除/隐藏时需同步删除/标记 `Post` 节点(可在删帖逻辑加 `deletePost` 调用,或补偿任务对账),否则会推荐到已删帖。
6. **Embedding 本地优先 + 降级硬约束**:`embed_one` 已是本地优先(失败自动降级,见 graphrag `llm.py` 的 `_with_fallback`),但 **embedding 降级目标必须是同一个 bge-m3(1024 维)** —— 入库与查询向量须同模型,否则 Neo4j 向量空间不兼容、检索失效。故 `EMBED_FALLBACK_ENABLED` 默认关闭(详见 [`09`](./09-本地大模型部署与降级.md))。
