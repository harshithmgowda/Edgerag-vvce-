import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_endpoint():
    res = client.get("/api/v1/health")
    assert res.status_code == 200
    data = res.json()
    assert "status" in data
    assert "database" in data
    assert "version" in data

def test_auth_login():
    res = client.post("/api/v1/auth/login", json={
        "username": "admin",
        "password": "IndustrialAdmin2026!"
    })
    assert res.status_code == 200
    data = res.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"

def test_equipment_lifecycle():
    # Login
    auth_res = client.post("/api/v1/auth/login", json={
        "username": "admin",
        "password": "IndustrialAdmin2026!"
    })
    token = auth_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Create equipment
    eq_payload = {
        "name": "Integration Test S7-1500",
        "model_number": "6ES7516-TEST",
        "manufacturer": "Siemens AG",
        "serial_number": "SN-TEST-881273",
        "description": "Test equipment unit"
    }
    create_res = client.post("/api/v1/equipment", json=eq_payload, headers=headers)
    assert create_res.status_code in [201, 400]  # 400 if already created in previous run

    # List equipment
    list_res = client.get("/api/v1/equipment")
    assert list_res.status_code == 200
    assert isinstance(list_res.json(), list)

def test_idempotent_incident_sync():
    import uuid
    incident_uuid = str(uuid.uuid4())

    payload = {
        "device_id": str(uuid.uuid4()),
        "sync_timestamp": "2026-10-19T14:00:00Z",
        "incidents": [
            {
                "id": incident_uuid,
                "equipment_id": str(uuid.uuid4()),
                "title": "Thermal Overload Sensor Triggered",
                "description": "Axis 2 motor thermal cut-off tripped at 92C.",
                "severity": "HIGH",
                "recorded_offline_at": "2026-10-19T13:45:00Z",
                "linked_manual_page": 44
            }
        ]
    }

    # First sync
    first_res = client.post("/api/v1/sync/incidents", json=payload)
    assert first_res.status_code == 200
    data1 = first_res.json()
    assert data1["total_received"] == 1
    assert data1["accepted_count"] == 1

    # Second sync with exact same UUID (Idempotency test)
    second_res = client.post("/api/v1/sync/incidents", json=payload)
    assert second_res.status_code == 200
    data2 = second_res.json()
    assert data2["total_received"] == 1
    assert data2["duplicate_count"] == 1
    assert data2["accepted_count"] == 0
