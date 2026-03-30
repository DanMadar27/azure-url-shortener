import logging
import os

from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from fastapi import Header, HTTPException

logger = logging.getLogger(__name__)

_api_key: str | None = None


def load_api_key() -> None:
    global _api_key
    vault_url = os.environ["KEY_VAULT_URL"]
    credential = DefaultAzureCredential()
    client = SecretClient(vault_url=vault_url, credential=credential)
    _api_key = client.get_secret("api-key").value
    logger.info("API key loaded from Key Vault")


def verify_api_key(x_api_key: str = Header(...)) -> None:
    if x_api_key != _api_key:
        raise HTTPException(status_code=401, detail="Invalid API key")
