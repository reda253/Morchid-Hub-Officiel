
from app.database import SessionLocal
from app.models import User

def check_user_admin_status():
    db = SessionLocal()
    email = "arodmohamed111666@gmail.com"
    try:
        user = db.query(User).filter(User.email == email).first()
        if user:
            print(f"User Found: {user.email}")
            print(f"ID: {user.id}")
            print(f"is_admin: {user.is_admin}")
            print(f"Role: {user.role}")
        else:
            print(f"User with email {email} NOT found.")
    except Exception as e:
        print(f"Error querying database: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    check_user_admin_status()
