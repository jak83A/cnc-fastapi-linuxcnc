"""
Application settings and configuration.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict
from pathlib import Path


class Settings(BaseSettings):
    """Application configuration settings."""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False
    )
    
    # LinuxCNC Configuration
    linuxcnc_path: str = "/usr/lib/python3/dist-packages"
    hal_config_file: str = "config/mesa7i92-zero3.hal"
    
    # API Configuration
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    api_title: str = "CNC Control API"
    api_version: str = "1.0.0"
    
    # Logging
    log_level: str = "INFO"
    
    # CNC Settings
    default_feed_rate: float = 1000.0
    max_feed_rate: float = 10000.0
    poll_interval: float = 0.05
    
    # Safety
    require_homing: bool = True
    enable_soft_limits: bool = True
    
    @property
    def hal_config_path(self) -> Path:
        """
        Get absolute path to HAL configuration file.
        
        :return: Path to HAL file
        :rtype: Path
        """
        base_path = Path(__file__).parent.parent.parent
        return base_path / self.hal_config_file


# Create global settings instance
settings = Settings()
