
import sys
import os

sys.path.append(os.getcwd())
from app.database import SessionLocal
from app.models import Guide

def approve_guide(guide_id):
    db = SessionLocal()
    try:
        guide = db.query(Guide).filter(Guide.id == guide_id).first()
        if guide:
            print(f"Approving guide {guide_id}...")
            guide.approval_status = "approved"
            db.commit()
            print("Guide APPROVED.")
        else:
            print("Guide not found.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    GUIDE_ID = "ad5306c4-2ec9-475f-bf60-ea98c2e60b0e"
    approve_guide(GUIDE_ID)
