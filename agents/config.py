from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    gemini_api_key: str
    agent_server_port: int = 4000
    guard_url: str = "http://localhost:8080"
    guard_api_key: str = ""

    # Gemini model used by all agents
    gemini_model: str = "gemini-1.5-flash"


settings = Settings()
