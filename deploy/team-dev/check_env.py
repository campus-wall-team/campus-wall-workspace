#!/usr/bin/env python3
"""按环境做【深度】连通性自检——不只查端口，而是真连到该环境的【具体】库/Redis DB/Neo4j 实例。

用法（在 A机 或能拿到凭据的机器上跑；普通成员 B机 只查端口用 check-connection.sh 即可）：
    python3 deploy/team-dev/check_env.py dev_b      # 检查 dev_b 这套环境
    python3 deploy/team-dev/check_env.py test       # 检查 test
共享凭据(MySQL root / Redis / prod Neo4j 密码)从 campus-wall-ops/.env 读，或同名环境变量覆盖。
"""
import os
import re
import socket
import sys
import urllib.request

SERVER = os.getenv("CAMPUS_SERVER", "172.21.160.212")
# bge-m3/Ollama 只绑 A机 localhost（未对 LAN 暴露）；AI 服务也跑在 A机 用 localhost 访问它。
# 故本检查走 localhost（脚本约定在 A机/管理员机跑）。要让别的机器用 bge-m3 需设 OLLAMA_HOST=0.0.0.0。
OLLAMA = os.getenv("OLLAMA_URL", "http://localhost:11434")
CHAT = os.getenv("CHAT_HOST", "172.21.160.101:8003")

# 绕过梯子/VPN 代理（urllib 不识别 no_proxy 的 CIDR，会误走代理致 502）
_NOPROXY = urllib.request.build_opener(urllib.request.ProxyHandler({}))

# 各环境 → 它【专属】的资源（库名 / Redis DB 号 / Neo4j 实例端口+密码 / MinIO bucket）
ENVS = {
    "dev_a": dict(mysql_db="campus_wall_dev_a", redis_db=1, neo4j_port=7691, neo4j_pw="devpass123",  bucket="campus-dev-a"),
    "dev_b": dict(mysql_db="campus_wall_dev_b", redis_db=2, neo4j_port=7691, neo4j_pw="devpass123",  bucket="campus-dev-b"),
    "test":  dict(mysql_db="campus_wall_test",  redis_db=15, neo4j_port=7689, neo4j_pw="testpass123", bucket="campus-test"),
    "prod":  dict(mysql_db="campus_wall",       redis_db=0, neo4j_port=7688, neo4j_pw=None,           bucket="campus-wall"),
}

GREEN, RED, RESET = "\033[32m", "\033[31m", "\033[0m"
bad = 0


def ok(msg):
    print(f"  {GREEN}✓{RESET} {msg}")


def fail(msg):
    global bad
    bad += 1
    print(f"  {RED}✗{RESET} {msg}")


def _ops_env(name, default=""):
    """从 campus-wall-ops/.env 读一个变量（环境变量优先）。"""
    if os.getenv(name):
        return os.getenv(name)
    here = os.path.dirname(os.path.abspath(__file__))
    envf = os.path.join(here, "..", "..", "campus-wall-ops", ".env")
    try:
        for line in open(envf):
            m = re.match(rf"{name}=(.*)", line.strip())
            if m:
                return m.group(1).strip().strip('"').strip("'")
    except OSError:
        pass
    return default


def check_mysql(cfg):
    pw = _ops_env("MYSQL_ROOT_PASSWORD")
    try:
        import pymysql
        c = pymysql.connect(host=SERVER, port=3306, user="root", password=pw,
                            database=cfg["mysql_db"], connect_timeout=4)
        with c.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
        c.close()
        ok(f"MySQL 库 {cfg['mysql_db']} 可连（SELECT 1 通过）")
    except Exception as e:
        fail(f"MySQL 库 {cfg['mysql_db']} 连接失败: {str(e)[:70]}")


def check_redis(cfg):
    pw = _ops_env("REDIS_PASSWORD")
    try:
        import redis
        r = redis.Redis(host=SERVER, port=6379, password=pw or None,
                        db=cfg["redis_db"], socket_timeout=4)
        r.ping()
        key = f"__conncheck__:{cfg['redis_db']}"
        r.setex(key, 10, "ok")
        assert r.get(key) == b"ok"
        ok(f"Redis DB {cfg['redis_db']} 可连（ping + set/get 通过）")
    except Exception as e:
        fail(f"Redis DB {cfg['redis_db']} 连接失败: {str(e)[:70]}")


def check_neo4j(cfg):
    pw = cfg["neo4j_pw"] or _ops_env("NEO4J_PASSWORD")
    uri = f"bolt://{SERVER}:{cfg['neo4j_port']}"
    try:
        from neo4j import GraphDatabase
        d = GraphDatabase.driver(uri, auth=("neo4j", pw))
        with d.session() as s:
            s.run("RETURN 1").single()
            idx = s.run("SHOW INDEXES YIELD name WHERE name='campus_post_vector' RETURN count(*) AS n").single()["n"]
        d.close()
        note = "（含帖子向量索引）" if idx else "（⚠ 缺 campus_post_vector 索引，首次用 ensure_schema 建）"
        ok(f"Neo4j 实例 :{cfg['neo4j_port']} 可连 {note}")
    except Exception as e:
        fail(f"Neo4j 实例 :{cfg['neo4j_port']} 连接失败: {str(e)[:70]}")


def check_port(host, port, label):
    try:
        with socket.create_connection((host, int(port)), timeout=4):
            ok(f"{label} 端口 {host}:{port} 可达")
    except Exception:
        fail(f"{label} 端口 {host}:{port} 不可达")


def check_http(url, label, needle=None):
    try:
        with _NOPROXY.open(url, timeout=6) as r:
            body = r.read(400).decode("utf-8", "ignore")
        if needle and needle not in body:
            fail(f"{label} 响应异常: {body[:60]}")
        else:
            ok(f"{label} 可达")
    except Exception as e:
        fail(f"{label} 不可达: {str(e)[:50]}")


def main():
    env = sys.argv[1] if len(sys.argv) > 1 else "dev_a"
    if env not in ENVS:
        print(f"未知环境 {env}，可选: {', '.join(ENVS)}")
        return 2
    cfg = ENVS[env]
    print(f"==== 深度连通性自检 · 环境 [{env}] · 服务器 {SERVER} ====\n")
    print("有状态中间件（该环境专属）:")
    check_mysql(cfg)
    check_redis(cfg)
    check_neo4j(cfg)
    check_port(SERVER, 9000, f"MinIO（bucket {cfg['bucket']} 由 Java 启动自动建）")
    print("\n无状态服务（全环境共享）:")
    check_port(SERVER, 8011, "AI 服务 campus-wall-ai")
    check_http(f"http://{SERVER}:8011/health", "AI 服务 /health", needle="ok")
    check_http(f"{OLLAMA}/api/tags", "bge-m3 / Ollama（A机本地, AI 服务用）")
    check_http(f"http://{CHAT}/v1/models", "Qwen3.6-35B（.101）")
    print()
    if bad == 0:
        print(f"{GREEN}✅ 环境 [{env}] 全部连通，可以开发。{RESET}")
        return 0
    print(f"{RED}⚠ 有 {bad} 项不通，按上面提示排查（端口/密码/容器是否在跑/梯子劫持内网）。{RESET}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
