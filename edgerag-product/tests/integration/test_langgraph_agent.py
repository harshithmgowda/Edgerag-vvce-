import uuid
from app.db.database import SessionLocal
from app.db.models import EquipmentModel
from app.ai.agent import execute_langgraph_chat

def test_langgraph_state_machine_flow():
    db = SessionLocal()
    try:
        # Create temporary equipment fixture
        eq_id = str(uuid.uuid4())
        eq = EquipmentModel(
            id=eq_id,
            name="ABB Test Robot",
            model_number="IRB-TEST-6700",
            manufacturer="ABB Robotics",
            serial_number=f"SN-TEST-{uuid.uuid4().hex[:6]}",
            description="Testing fixture",
        )
        db.add(eq)
        db.commit()

        # Execute LangGraph workflow
        result = execute_langgraph_chat(
            question="What is the maximum payload capacity and emergency brake distance?",
            equipment_id=eq_id,
            ai_mode="SMART_AUTO",
            db=db,
        )

        assert result is not None
        assert result.answer is not None
        assert isinstance(result.execution_trace, list)
        assert len(result.execution_trace) >= 4

        # Verify trace contains all mandatory LangGraph nodes
        trace_str = " ".join(result.execution_trace)
        assert "[PLANNER]" in trace_str
        assert "[RETRIEVER]" in trace_str
        assert "[TOOL]" in trace_str
        assert "[REASONER]" in trace_str
        assert "[VERIFIER]" in trace_str
        assert "[RESULT]" in trace_str

    finally:
        db.close()
