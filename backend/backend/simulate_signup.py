import urllib.request
import json
import time

url = "http://127.0.0.1:8000/api/v1/register"

# Payload with VALID bio and VALID specialties (French)
payload = {
    "personal_info": {
        "full_name": "Test User Valid",
        "email": "test_valid_03@example.com",
        "phone": "+212600000003",
        "date_of_birth": "1990-01-01"
    },
    "role": "guide",
    "password": "password123",
    "guide_details": {
        "languages": ["English", "French"],
        "specialties": ["histoire"],  # Fixed: must be 'histoire', not 'history'
        "cities_covered": ["Marrakech"],
        "years_of_experience": 5,
        "bio": "A passionate guide with 5 years of experience in the beautiful city of Marrakech and its surroundings."
    }
}

def send_request():
    print(f"Sending POST request to {url}...")
    try:
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
        
        with urllib.request.urlopen(req) as response:
            print(f"Status Code: {response.getcode()}")
            response_body = response.read().decode('utf-8')
            print("Response JSON:")
            print(response_body)

    except urllib.error.HTTPError as e:
        print(f"HTTPError: {e.code}")
        print("Response JSON:")
        print(e.read().decode('utf-8'))
    except Exception as e:
        print(f"Request failed: {e}")

print("--- TEST 1: First Signup (Expect 201) ---")
send_request()

print("\n--- TEST 2: Duplicate Signup (Expect 400 - NOT 500) ---")
send_request()
