
import sys
import os

sys.path.append(os.getcwd())
from app.database import SessionLocal
from app.models import Guide

def approve_all_guides():
    db = SessionLocal()
    try:
        guides = db.query(Guide).filter(Guide.approval_status != "approved").all()
        print(f"Found {len(guides)} guides to approve.")
        for guide in guides:
            print(f"Approving guide {guide.id}...")
            guide.approval_status = "approved"
        
        db.commit()
        print("All guides APPROVED.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    approve_all_guides()
