"""
Unit tests for motion control endpoints.
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health_check() -> None:
    """
    Test health check endpoint.
    
    :return: None
    """
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}


def test_root_endpoint() -> None:
    """
    Test root endpoint returns API information.
    
    :return: None
    """
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert "version" in data


# Note: Testing actual CNC operations requires a running LinuxCNC instance
# These are placeholder tests showing the structure

@pytest.mark.skip(reason="Requires running LinuxCNC instance")
def test_absolute_move() -> None:
    """
    Test absolute movement endpoint.
    
    :return: None
    """
    response = client.post(
        "/motion/absolute",
        json={
            "x": 10.0,
            "y": 20.0,
            "z": 5.0,
            "feed_rate": 1000.0,
            "rapid": False
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "gcode" in data


@pytest.mark.skip(reason="Requires running LinuxCNC instance")
def test_get_position() -> None:
    """
    Test position query endpoint.
    
    :return: None
    """
    response = client.get("/status/position")
    assert response.status_code == 200
    data = response.json()
    assert "x" in data
    assert "y" in data
    assert "z" in data
