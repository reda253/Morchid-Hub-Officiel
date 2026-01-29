
import sys
# Add current directory to path so we can import app
sys.path.append(".")
try:
    from app.auth import hash_password
    print("Hashing 'password123'...")
    h = hash_password("password123")
    print(f"Hash: {h}")
except Exception as e:
    import traceback
    traceback.print_exc()
