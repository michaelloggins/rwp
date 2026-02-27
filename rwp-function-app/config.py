import os
from dataclasses import dataclass


@dataclass
class Settings:
    """Configuration loaded from environment variables."""

    synapse_endpoint: str
    synapse_database: str

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            synapse_endpoint=os.environ["SYNAPSE_ENDPOINT"],
            synapse_database=os.environ.get("SYNAPSE_DATABASE", "rwp_analytics"),
        )


_settings: Settings | None = None


def get_settings() -> Settings:
    global _settings
    if _settings is None:
        _settings = Settings.from_env()
    return _settings
