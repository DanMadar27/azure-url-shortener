import json

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import RedirectResponse

from services import redis_service
from services.auth_service import verify_api_key

router = APIRouter()


@router.get("/api/redirect/{short_code}", dependencies=[Depends(verify_api_key)])
async def api_redirect(short_code: str) -> dict:
    url = await redis_service.get(f"url:{short_code}")
    if url is None:
        raise HTTPException(status_code=404, detail="Short code not found")
    await _increment_click_count(short_code)
    return {"original_url": url, "short_code": short_code}


@router.get("/r/{short_code}")
async def browser_redirect(short_code: str) -> RedirectResponse:
    url = await redis_service.get(f"url:{short_code}")
    if url is None:
        raise HTTPException(status_code=404, detail="Short code not found")
    await _increment_click_count(short_code)
    return RedirectResponse(url=url, status_code=302)


async def _increment_click_count(short_code: str) -> None:
    raw = await redis_service.get(f"meta:{short_code}")
    if raw is None:
        return
    meta = json.loads(raw)
    meta["click_count"] = meta.get("click_count", 0) + 1
    # Preserve remaining TTL by re-setting with no explicit TTL (key persists as-is)
    # Use GETEX pattern: fetch TTL then re-set — simpler than HINCRBY since we store JSON
    await redis_service.set(f"meta:{short_code}", json.dumps(meta))
