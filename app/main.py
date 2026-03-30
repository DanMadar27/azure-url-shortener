import logging
import math
import time

from fastapi import FastAPI, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from routers import redirect, shorten
from services import auth_service, redis_service

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
logger = logging.getLogger(__name__)

app = FastAPI(title="URL Shortener")


@app.on_event("startup")
async def startup() -> None:
    auth_service.load_api_key()
    await redis_service.connect()


app.include_router(shorten.router)
app.include_router(redirect.router)

app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/")
async def index() -> FileResponse:
    return FileResponse("static/index.html")


@app.get("/health")
async def health() -> JSONResponse:
    redis_ok = await redis_service.ping()
    if redis_ok:
        logger.info("Health check: ok")
        return JSONResponse(content={"status": "ok", "redis": "connected"})
    logger.error("Health check: Redis unreachable")
    return JSONResponse(status_code=503, content={"status": "degraded", "redis": "unreachable"})


# ── Rate limiting middleware ─────────────────────────────────────────────────
RATE_LIMIT = 60  # requests per minute


@app.middleware("http")
async def rate_limit(request: Request, call_next):
    if not request.url.path.startswith("/api/"):
        return await call_next(request)

    api_key = request.headers.get("x-api-key", "anonymous")
    window = math.floor(time.time() / 60)
    bucket_key = f"ratelimit:{api_key}:{window}"

    try:
        count = await redis_service.incr(bucket_key)
        if count == 1:
            await redis_service.expire(bucket_key, 60)
        if count > RATE_LIMIT:
            return JSONResponse(
                status_code=429,
                content={"detail": "Rate limit exceeded"},
                headers={"Retry-After": "60"},
            )
    except Exception:
        logger.warning("Rate limit check failed — failing open")

    return await call_next(request)
