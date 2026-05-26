"""Application configuration loaded from environment variables."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # App
    debug: bool = True
    cors_origins: list[str] = ["*"]

    # Database
    database_url: str = "postgresql+asyncpg://posecraft:posecraft@localhost:5432/posecraft"

    # Milvus
    milvus_host: str = "localhost"
    milvus_port: int = 19530

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # MinIO / Object Storage
    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_bucket: str = "posecraft"

    # LLM APIs
    qwen_api_base: str = "https://dashscope.aliyuncs.com/api/v1"
    qwen_api_key: str = ""
    qwen_model: str = "qwen-vl-max"

    deepseek_api_base: str = "https://api.deepseek.com"
    deepseek_api_key: str = ""
    deepseek_model: str = "deepseek-chat"

    glm_api_base: str = "https://open.bigmodel.cn/api/paas/v4"
    glm_api_key: str = ""
    glm_model: str = "glm-4v"

    # Limits
    max_recommendations_per_request: int = 5
    recommendation_cache_ttl: int = 300  # seconds

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
    }


settings = Settings()
