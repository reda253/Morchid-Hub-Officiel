
import requests
import json

# Configuration
BASE_URL = "http://127.0.0.1:8000"
LOGIN_ENDPOINT = "/api/v1/login"
ROUTE_ENDPOINT = "/api/v1/guides/routes"

# Guide credentials (assuming a guide account exists from previous context or I'll need to create one)
# I'll try to signup a new guide first to be sure
REGISTER_ENDPOINT = "/api/v1/register"

def test_save_route():
    try:
        # 1. Register a new guide
        guide_email = "guide_test_route@example.com"
        guide_password = "password123"
        
        register_data = {
            "personal_info": {
                "full_name": "Guide Test Route",
                "email": guide_email,
                "phone": "+212600000099",
                "date_of_birth": "1990-01-01"
            },
            "role": "guide",
            "password": guide_password,
            "guide_details": {
                "languages": ["English"],
                "specialties": ["histoire"],
                "cities_covered": ["Casablanca"],
                "years_of_experience": 5,
                "bio": "This is a test bio that is long enough to pass the validation check which requires at least 50 characters."
            }
        }
        
        print("1. Registering guide...")
        resp = requests.post(f"{BASE_URL}{REGISTER_ENDPOINT}", json=register_data)
        if resp.status_code == 201 or resp.status_code == 400: # 400 if already exists
            print("   Registration successful or already exists.")
        else:
            print(f"   Registration failed: {resp.status_code}")
            try:
                print(json.dumps(resp.json(), indent=2))
            except:
                print(resp.text)
            return

        # 2. Login
        print("2. Logging in...")
        login_data = {"email": guide_email, "password": guide_password}
        resp = requests.post(f"{BASE_URL}{LOGIN_ENDPOINT}", json=login_data)
        if resp.status_code != 200:
            print(f"   Login failed: {resp.status_code} - {resp.text}")
            return
            
        token = resp.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        print("   Login successful.")

        # 3. Save Route
        print("3. Saving route...")
        route_data = {
            "coordinates": [
                {"lat": 33.5731, "lng": -7.5898},
                {"lat": 33.5850, "lng": -7.6100}
            ],
            "distance": 5.2,
            "duration": 15.0,
            "start_address": "Start Point",
            "end_address": "End Point"
        }
        
        resp = requests.post(f"{BASE_URL}{ROUTE_ENDPOINT}", json=route_data, headers=headers)
        print(f"   Response Code: {resp.status_code}")
        print(f"   Response Body: {resp.text}")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_save_route()
