import json
import os
import random
import re
import string
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, HttpUrl

from services import redis_service
from services.auth_service import verify_api_key

router = APIRouter(prefix="/api", dependencies=[Depends(verify_api_key)])

SHORT_CODE_TTL = 30 * 24 * 3600  # 30 days in seconds
CODE_ALPHABET = string.ascii_letters + string.digits
CODE_LENGTH = 6
MAX_COLLISION_RETRIES = 5


class ShortenRequest(BaseModel):
    url: HttpUrl
    custom_code: str | None = None


class ShortenResponse(BaseModel):
    short_code: str
    short_url: str


@router.post("/shorten", response_model=ShortenResponse)
async def shorten(body: ShortenRequest) -> ShortenResponse:
    url_str = str(body.url)

    if body.custom_code is not None:
        short_code = _validate_custom_code(body.custom_code)
        if await redis_service.get(f"url:{short_code}") is not None:
            raise HTTPException(status_code=409, detail="Custom code already taken")
    else:
        short_code = await _generate_unique_code()

    await redis_service.set(f"url:{short_code}", url_str, ttl=SHORT_CODE_TTL)
    meta = json.dumps({
        "created_at": datetime.now(timezone.utc).isoformat(),
        "click_count": 0,
        "original_url": url_str,
    })
    await redis_service.set(f"meta:{short_code}", meta, ttl=SHORT_CODE_TTL)

    hostname = os.environ.get("WEBSITE_HOSTNAME", "localhost:8000")
    short_url = f"https://{hostname}/r/{short_code}"

    return ShortenResponse(short_code=short_code, short_url=short_url)


@router.get("/stats/{short_code}")
async def stats(short_code: str) -> dict:
    raw = await redis_service.get(f"meta:{short_code}")
    if raw is None:
        raise HTTPException(status_code=404, detail="Short code not found")
    return json.loads(raw)


def _validate_custom_code(code: str) -> str:
    if not re.fullmatch(r"[a-zA-Z0-9]{3,20}", code):
        raise HTTPException(
            status_code=422,
            detail="custom_code must be 3-20 alphanumeric characters",
        )
    return code


async def _generate_unique_code() -> str:
    for _ in range(MAX_COLLISION_RETRIES):
        code = "".join(random.choices(CODE_ALPHABET, k=CODE_LENGTH))
        if await redis_service.get(f"url:{code}") is None:
            return code
    raise HTTPException(status_code=503, detail="Could not generate a unique short code — please retry")
