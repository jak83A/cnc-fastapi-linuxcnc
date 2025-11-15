# /app/services/main.py
"""
FastAPI application entry point.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config.settings import settings
from app.api.routes import motion, status, system

# Create FastAPI application
app = FastAPI(
    title=settings.api_title,
    version=settings.api_version,
    description="REST API for LinuxCNC CNC machine control with Mesa 7i92 card",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(motion.router)
app.include_router(status.router)
app.include_router(system.router)


@app.get("/", tags=["Health"])
async def root() -> dict[str, str]:
    """
    Root endpoint for health check.
    
    :return: API status message
    :rtype: dict[str, str]
    """
    return {
        "message": "CNC Control API is running",
        "version": settings.api_version,
        "docs": "/docs"
    }


@app.get("/health", tags=["Health"])
async def health_check() -> dict[str, str]:
    """
    Health check endpoint.
    
    :return: Health status
    :rtype: dict[str, str]
    """
    return {"status": "healthy"}
