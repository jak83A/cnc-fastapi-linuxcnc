"""
API routes for machine status queries.
"""
from fastapi import APIRouter, Depends, HTTPException
from app.models.responses import PositionResponse, MachineStatusResponse, ErrorResponse
from app.services.cnc_service import CNCService
from app.api.dependencies import get_cnc_service
from app.core.exceptions import CNCException

router = APIRouter(prefix="/status", tags=["Status"])


@router.get(
    "/position",
    response_model=PositionResponse,
    responses={500: {"model": ErrorResponse}}
)
async def get_position(
    cnc_service: CNCService = Depends(get_cnc_service)
) -> PositionResponse:
    """
    Get current machine position for all axes.
    
    :param cnc_service: CNC service dependency
    :type cnc_service: CNCService
    :return: Current position
    :rtype: PositionResponse
    :raises HTTPException: If status query fails
    """
    try:
        position = cnc_service.get_position()
        return PositionResponse(**position)
    except CNCException as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")


@router.get(
    "/",
    response_model=MachineStatusResponse,
    responses={500: {"model": ErrorResponse}}
)
async def get_machine_status(
    cnc_service: CNCService = Depends(get_cnc_service)
) -> MachineStatusResponse:
    """
    Get comprehensive machine status including position, homing, and E-stop state.
    
    :param cnc_service: CNC service dependency
    :type cnc_service: CNCService
    :return: Complete machine status
    :rtype: MachineStatusResponse
    :raises HTTPException: If status query fails
    """
    try:
        status = cnc_service.get_status()
        return MachineStatusResponse(**status)
    except CNCException as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")
