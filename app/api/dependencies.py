# /app/api/dependencies
"""
FastAPI dependency injection providers.
"""
from app.services.cnc_service import CNCService

# Singleton service instance
_cnc_service: CNCService | None = None


def get_cnc_service() -> CNCService:
    """
    Dependency provider for CNC service (singleton pattern).
    
    :return: CNC service instance
    :rtype: CNCService
    """
    global _cnc_service
    
    if _cnc_service is None:
        _cnc_service = CNCService()
    
    return _cnc_service
