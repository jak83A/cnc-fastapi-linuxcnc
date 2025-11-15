# /app/api/routes/motion.py
"""
API routes for CNC motion control.
"""
from fastapi import APIRouter, Depends, HTTPException
from app.models.requests import MoveRequest, RelativeMoveRequest
from app.models.responses import MoveResponse, ErrorResponse
from app.services.cnc_service import CNCService
from app.api.dependencies import get_cnc_service
from app.core.exceptions import CNCException

router = APIRouter(prefix="/motion", tags=["Motion Control"])


@router.post(
    "/absolute",
    response_model=MoveResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}}
)
async def move_absolute(
    request: MoveRequest,
    cnc_service: CNCService = Depends(get_cnc_service)
) -> MoveResponse:
    """
    Move to absolute coordinates.
    
    :param request: Move request parameters
    :type request: MoveRequest
    :param cnc_service: CNC service dependency
    :type cnc_service: CNCService
    :return: Move execution result
    :rtype: MoveResponse
    :raises HTTPException: If move fails
    """
    try:
        result = cnc_service.execute_absolute_move(
            x=request.x,
            y=request.y,
            z=request.z,
            feed_rate=request.feed_rate,
            rapid=request.rapid,
            wait=request.wait
        )
        return MoveResponse(**result)
    except CNCException as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")


@router.post(
    "/relative",
    response_model=MoveResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}}
)
async def move_relative(
    request: RelativeMoveRequest,
    cnc_service: CNCService = Depends(get_cnc_service)
) -> MoveResponse:
    """
    Move relative to current position.
    
    :param request: Relative move request parameters
    :type request: RelativeMoveRequest
    :param cnc_service: CNC service dependency
    :type cnc_service: CNCService
    :return: Move execution result
    :rtype: MoveResponse
    :raises HTTPException: If move fails
    """
    try:
        result = cnc_service.execute_relative_move(
            x=request.x,
            y=request.y,
            z=request.z,
            feed_rate=request.feed_rate,
            rapid=request.rapid,
            wait=request.wait
        )
        return MoveResponse(**result)
    except CNCException as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")
