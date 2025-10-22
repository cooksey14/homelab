from pydantic_settings import BaseSettings
from typing import Optional
import os


class Settings(BaseSettings):
    """Application configuration settings."""
    
    # Database settings
    database_url: str = "postgresql+asyncpg://${DB_USER}:${DB_PASSWORD}@postgres:5432/homelab_command_center"
    
    # Redis settings
    redis_url: str = "redis://redis:6379/0"
    
    # Kubernetes settings
    kube_config_path: Optional[str] = None
    kube_namespace: str = "default"
    
    # Monitoring settings
    health_check_interval: int = 30  # seconds
    cluster_stats_interval: int = 60  # seconds
    
    # API settings
    api_title: str = "HomeLab Command Center"
    api_description: str = "Modern HomeLab monitoring and management platform"
    api_version: str = "1.0.0"
    
    # Security
    secret_key: str = "${SECRET_KEY}"
    
    # Logging
    log_level: str = "INFO"
    
    class Config:
        env_file = ".env"
        case_sensitive = False


# Global settings instance
settings = Settings()
