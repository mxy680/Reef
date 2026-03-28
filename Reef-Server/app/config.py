from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = False
    environment: str = "development"

    # Supabase
    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_service_role_key: str = ""

    # External Services
    openrouter_api_key: str = ""
    gemini_api_key: str = ""
    mathpix_app_id: str = ""
    mathpix_app_key: str = ""
    groq_api_key: str = ""
    deepinfra_api_key: str = ""
    elevenlabs_api_key: str = ""
    reef_inference_url: str = "https://inference.studyreef.com"
    reef_inference_token: str = ""

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()
