from os import getenv
from pathlib import Path
from socket import gethostname
from datetime import timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from urllib.parse import urlparse

import pymysql
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.responses import HTMLResponse

app = FastAPI(title=getenv("APP_NAME", "k3s-security-checkins"))
INDEX_HTML = Path(__file__).with_name("index.html").read_text(encoding="utf-8")
UTC = timezone.utc

try:
    KST = ZoneInfo("Asia/Seoul")
except ZoneInfoNotFoundError:
    KST = timezone(timedelta(hours=9), name="KST")


class SignupRequest(BaseModel):
    name: str


def get_database_url() -> str | None:
    return getenv("DATABASE_URL")


def mysql_connection() -> pymysql.connections.Connection:
    database_url = get_database_url()
    if not database_url:
        raise HTTPException(status_code=503, detail="DATABASE_URL is not configured")

    parsed = urlparse(database_url)
    if parsed.scheme != "mysql":
        raise HTTPException(status_code=500, detail="Only mysql:// DATABASE_URL is supported")

    try:
        return pymysql.connect(
            host=parsed.hostname,
            port=parsed.port or 3306,
            user=parsed.username,
            password=parsed.password,
            database=(parsed.path or "/").lstrip("/"),
            charset="utf8mb4",
            cursorclass=pymysql.cursors.DictCursor,
            connect_timeout=5,
            init_command="SET time_zone = '+00:00'",
        )
    except pymysql.MySQLError as exc:
        raise HTTPException(status_code=503, detail=f"Database connection failed: {exc}") from exc


def ensure_checkins_table() -> None:
    with mysql_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS checkins (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(100) NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
        connection.commit()


def check_database_ready() -> dict[str, str | int]:
    database_url = get_database_url()
    if not database_url:
        raise HTTPException(status_code=503, detail="DATABASE_URL is not configured")

    with mysql_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1 AS result")
            row = cursor.fetchone()

    return {
        "status": "ready",
        "database_url_present": "true",
        "result": row["result"],
    }


def instance_identity() -> dict[str, str]:
    pod_name = getenv("POD_NAME") or getenv("HOSTNAME") or gethostname()
    node_name = getenv("NODE_NAME", "unknown")

    return {
        "pod_name": pod_name,
        "node_name": node_name,
    }


def format_created_at(created_at) -> str:
    if created_at.tzinfo is None:
        created_at = created_at.replace(tzinfo=UTC)
    return created_at.astimezone(KST).strftime("%Y-%m-%d %H:%M:%S KST")


@app.get("/", response_class=HTMLResponse)
def root() -> str:
    return INDEX_HTML


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/ready")
def ready() -> dict[str, str | int]:
    return check_database_ready()


@app.get("/whoami")
def whoami() -> dict[str, str]:
    return instance_identity()


@app.get("/db-health")
def db_health() -> dict[str, str | int]:
    database_url = get_database_url()
    if not database_url:
        return {
            "status": "not-configured",
            "database_url_present": "false",
        }
    return check_database_ready()


@app.post("/checkins")
def create_checkin(payload: SignupRequest) -> dict[str, str | int]:
    ensure_checkins_table()

    with mysql_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                "INSERT INTO checkins (name) VALUES (%s)",
                (payload.name,),
            )
            user_id = cursor.lastrowid
        connection.commit()

    return {
        "status": "created",
        "id": user_id,
        "name": payload.name,
    }


@app.get("/checkins")
def list_checkins() -> dict[str, list[dict[str, str | int]]]:
    ensure_checkins_table()

    with mysql_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, name, created_at
                FROM checkins
                ORDER BY id DESC
                """
            )
            rows = cursor.fetchall()

    for row in rows:
        row["created_at"] = format_created_at(row["created_at"])

    return {"checkins": rows}


@app.delete("/checkins/{user_id}")
def delete_checkin(user_id: int) -> dict[str, str | int]:
    ensure_checkins_table()

    with mysql_connection() as connection:
        with connection.cursor() as cursor:
            deleted = cursor.execute("DELETE FROM checkins WHERE id = %s", (user_id,))
        connection.commit()

    if deleted == 0:
        raise HTTPException(status_code=404, detail="Check-in not found")

    return {
        "status": "deleted",
        "id": user_id,
    }
