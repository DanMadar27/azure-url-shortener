import logging
import os

from azure.identity.aio import ManagedIdentityCredential
from azure.keyvault.secrets.aio import SecretClient
from fastapi import Header, HTTPException

logger = logging.getLogger(__name__)

_api_key: str | None = None


async def load_api_key() -> None:
    global _api_key
    vault_url = os.environ["KEY_VAULT_URL"]
    async with ManagedIdentityCredential() as credential:
        async with SecretClient(vault_url=vault_url, credential=credential) as client:
            _api_key = (await client.get_secret("api-key")).value
    logger.info("API key loaded from Key Vault")


def verify_api_key(x_api_key: str = Header(...)) -> None:
    if x_api_key != _api_key:
        raise HTTPException(status_code=401, detail="Invalid API key")
