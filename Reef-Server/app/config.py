from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = False
    environment: str = "production"

    # Supabase (for JWT verification via JWKS)
    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_service_role_key: str = ""

    # External services
    openrouter_api_key: str = ""
    gemini_api_key: str = ""
    mathpix_app_id: str = ""
    mathpix_app_key: str = ""
    groq_api_key: str = ""
    deepinfra_api_key: str = ""

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
