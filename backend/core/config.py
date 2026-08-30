from functools import lru_cache

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )

    database_url: str = Field(
        default="sqlite:///./data/budget_gurugram.db",
        validation_alias=AliasChoices("DATABASE_URL", "database_url"),
    )
    openai_api_key: str = Field(default="", validation_alias=AliasChoices("OPENAI_API_KEY", "openai_api_key"))
    openai_model_enrich: str = Field(default="gpt-5.6", validation_alias=AliasChoices("OPENAI_MODEL_ENRICH", "openai_model_enrich"))
    openai_model_ask: str = Field(default="gpt-5.6", validation_alias=AliasChoices("OPENAI_MODEL_ASK", "openai_model_ask"))
    openai_model_match: str = Field(default="gpt-5.6-mini", validation_alias=AliasChoices("OPENAI_MODEL_MATCH", "openai_model_match"))
    openai_embed_model: str = Field(default="text-embedding-3-small", validation_alias=AliasChoices("OPENAI_EMBED_MODEL", "openai_embed_model"))
    search_api_key: str = Field(default="", validation_alias=AliasChoices("SEARCH_API_KEY", "search_api_key"))
    city_slugs: str = Field(default="gurugram,gurgaon", validation_alias=AliasChoices("CITY_SLUGS", "city_slugs"))
    city_center_lat: float = Field(default=28.4945, validation_alias=AliasChoices("CITY_CENTER_LAT", "city_center_lat"))
    city_center_lng: float = Field(default=77.0894, validation_alias=AliasChoices("CITY_CENTER_LNG", "city_center_lng"))
    city_bbox: str = Field(default="28.35,76.92,28.56,77.16", validation_alias=AliasChoices("CITY_BBOX", "city_bbox"))
    qa_daily_limit: int = Field(default=20, validation_alias=AliasChoices("QA_DAILY_LIMIT", "qa_daily_limit"))
    scrape_interval_hours: int = Field(default=3, validation_alias=AliasChoices("SCRAPE_INTERVAL_HOURS", "scrape_interval_hours"))
    retrieval_min_similarity: float = Field(default=0.30, validation_alias=AliasChoices("RETRIEVAL_MIN_SIMILARITY", "retrieval_min_similarity"))
    list_cache_seconds: int = Field(default=300, validation_alias=AliasChoices("LIST_CACHE_SECONDS", "list_cache_seconds"))

    @property
    def city_slug_list(self) -> list[str]:
        return [part.strip().lower() for part in self.city_slugs.split(",") if part.strip()]

    @property
    def bbox(self) -> tuple[float, float, float, float]:
        min_lat, min_lng, max_lat, max_lng = (float(part) for part in self.city_bbox.split(","))
        return min_lat, min_lng, max_lat, max_lng

    @property
    def sqlalchemy_url(self) -> str:
        url = self.database_url
        if url.startswith("postgres://"):
            return "postgresql+psycopg://" + url[len("postgres://") :]
        if url.startswith("postgresql://") and "+psycopg" not in url:
            return "postgresql+psycopg://" + url[len("postgresql://") :]
        return url


@lru_cache
def get_settings() -> Settings:
    return Settings()
