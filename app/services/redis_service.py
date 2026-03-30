import asyncio
import base64
import json
import logging
import os

import redis.asyncio as aioredis
from azure.identity import DefaultAzureCredential

logger = logging.getLogger(__name__)

_client: aioredis.Redis | None = None
_credential = DefaultAzureCredential()

REDIS_HOST = os.environ["REDIS_HOST"]
REDIS_PORT = 6380
REDIS_SCOPE = "https://redis.azure.com/.default"
TOKEN_REFRESH_INTERVAL_SECONDS = 20 * 3600  # refresh every 20 hours


def _get_token() -> str:
    return _credential.get_token(REDIS_SCOPE).token


def _extract_oid(token: str) -> str:
    # Decode the JWT payload (no signature verification needed — Azure issued it)
    payload = token.split(".")[1]
    payload += "=" * (-len(payload) % 4)  # fix padding
    return json.loads(base64.b64decode(payload))["oid"]


def _build_client(token: str) -> aioredis.Redis:
    return aioredis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        ssl=True,
        username=_extract_oid(token),
        password=token,
        decode_responses=True,
    )


async def connect() -> None:
    global _client
    token = _get_token()
    _client = _build_client(token)
    await _client.ping()
    logger.info("Redis connection established")

    asyncio.create_task(_token_refresh_loop())


async def _token_refresh_loop() -> None:
    while True:
        await asyncio.sleep(TOKEN_REFRESH_INTERVAL_SECONDS)
        try:
            global _client
            token = _get_token()
            old_client = _client
            _client = _build_client(token)
            await _client.ping()
            await old_client.aclose()
            logger.info("Redis token refreshed and connection re-established")
        except Exception:
            logger.exception("Redis token refresh failed — keeping existing connection")


async def ping() -> bool:
    try:
        return await _client.ping()
    except Exception:
        logger.exception("Redis ping failed")
        return False


async def get(key: str) -> str | None:
    return await _client.get(key)


async def set(key: str, value: str, ttl: int | None = None) -> None:
    await _client.set(key, value, ex=ttl)


async def incr(key: str) -> int:
    return await _client.incr(key)


async def expire(key: str, ttl: int) -> None:
    await _client.expire(key, ttl)
