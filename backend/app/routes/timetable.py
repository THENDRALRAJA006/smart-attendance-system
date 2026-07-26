# ============================================================
# SmartAttend — Legacy Timetable Router (v13 ERP Compatibility)
# Replaced by app.routes.erp_timetable
# ============================================================

from fastapi import APIRouter

router = APIRouter(prefix="/api/timetable", tags=["Timetable (Deprecated OCR)"])

@router.get("", summary="Deprecated - Use /api/erp/timetable")
def legacy_timetable_stub():
    return {"message": "OCR Timetable has been upgraded to manual ERP Timetable. Please use /api/erp/timetable"}
