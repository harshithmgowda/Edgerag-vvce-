from fastapi import APIRouter
from app.api.v1.endpoints import (
    health,
    auth,
    equipment,
    manuals,
    jobs,
    packages,
    devices,
    sync,
    incidents,
    ai,
)

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(health.router, tags=["Health"])
api_router.include_router(auth.router, tags=["Authentication"])
api_router.include_router(equipment.router, tags=["Equipment"])
api_router.include_router(manuals.router, tags=["Manuals"])
api_router.include_router(jobs.router, tags=["Processing Jobs"])
api_router.include_router(packages.router, tags=["Knowledge Packages"])
api_router.include_router(devices.router, tags=["Devices"])
api_router.include_router(sync.router, tags=["Hotspot Synchronization"])
api_router.include_router(incidents.router, tags=["Field Incidents"])
api_router.include_router(ai.router, tags=["AI Providers & Chat"])
