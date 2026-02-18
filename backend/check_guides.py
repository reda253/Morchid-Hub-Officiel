from app.database import SessionLocal
from app.models import Guide, User

db = SessionLocal()
try:
    guides = db.query(Guide).all()
    print(f"Total guides: {len(guides)}")
    for guide in guides:
        user = db.query(User).filter(User.id == guide.user_id).first()
        print(f"Guide ID: {guide.id}, User: {user.full_name}, Status: {guide.approval_status}, Verified: {guide.is_verified}")
except Exception as e:
    print(f"Error: {e}")
finally:
    db.close()
