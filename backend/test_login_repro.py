
import requests
import json

BASE_URL = "http://127.0.0.1:8000"
LOGIN_ENDPOINT = "/api/v1/login"
REGISTER_ENDPOINT = "/api/v1/register"

def test_login():
    # 1. Register a user (if not exists)
    email = "test_login_user@example.com"
    password = "password123"
    
    reg_data = {
        "personal_info": {
            "full_name": "Test Login",
            "email": email,
            "phone": "+212600000001",
            "date_of_birth": "1990-01-01"
        },
        "role": "tourist",
        "password": password
    }
    
    print("Registering...")
    requests.post(f"{BASE_URL}{REGISTER_ENDPOINT}", json=reg_data)
    
    # 2. Login
    print("Logging in...")
    resp = requests.post(f"{BASE_URL}{LOGIN_ENDPOINT}", json={"email": email, "password": password})
    
    print(f"Status: {resp.status_code}")
    print(f"Response: {resp.text}")

if __name__ == "__main__":
    test_login()
