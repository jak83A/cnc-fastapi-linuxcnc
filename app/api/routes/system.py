# /app/api/routes/system.py
"""
API routes for system control (homing, E-stop, etc.).
"""
from fastapi import APIRouter, Depends, HTTPException
from app.models.requests import HomeRequest, EmergencyStopRequest, MachineStateRequest
from app.models.responses import HomeResponse, EmergencyStopResponse, MachineStateResponse, ErrorResponse
from app.services.cnc_service import CNCService
from app.api.dependencies import get_cnc_service
from app.core.exceptions import CNCException

router = APIRouter(prefix="/system", tags=["System Control"])


@router.post(
    "/home",
    response_model=HomeResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}}
)
async def home_machine(
    request: HomeRequest,
    cnc_service: CNCService = Depends(get_cnc_service)
) -> HomeResponse:
    """
    Home all machine axes.
    
    :param request: Home request parameters
    :type request: HomeRequest
    :param cnc_service: CNC service dependency
    :type cnc_service: CNCService
    :return: Homing operation result
    :rtype: HomeResponse
    :raises HTTPException: If homing fails
    """
    try:
        result = cnc_service.home_machine(wait=request.wait)
        return HomeResponse(**result)
    except CNCException as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")


@router.post(
    "/estop",
    response_model=EmergencyStopResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}}
)
async def emergency_stop(
    request: EmergencyStopRequest,
    cnc_service: CNCService = Depends(get_cnc_service)
) -> EmergencyStopResponse:
    """
    Activate or reset emergency stop.

    :param request: E-stop request (reset=True to clear, reset=False to activate)
    :type request: EmergencyStopRequest
    :param cnc_service: CNC service dependency
    :type cnc_service: CNCService
    :return: E-stop operation result
    :rtype: EmergencyStopResponse
    :raises HTTPException: If E-stop operation fails
    """
    try:
        if request.reset:
            result = cnc_service.reset_emergency_stop()
        else:
            result = cnc_service.trigger_emergency_stop()

        return EmergencyStopResponse(**result)
    except CNCException as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")


@router.post(
    "/power",
    response_model=MachineStateResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}}
)
async def machine_power(
    request: MachineStateRequest,
    cnc_service: CNCService = Depends(get_cnc_service)
) -> MachineStateResponse:
    """
    Turn machine on or off.

    :param request: Machine power request (on=True to enable, on=False to disable)
    :type request: MachineStateRequest
    :param cnc_service: CNC service dependency
    :type cnc_service: CNCService
    :return: Machine power operation result
    :rtype: MachineStateResponse
    :raises HTTPException: If operation fails
    """
    try:
        result = cnc_service.set_machine_power(on=request.on)
        return MachineStateResponse(**result)
    except CNCException as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")
