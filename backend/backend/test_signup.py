
import urllib.request
import json
import urllib.error
import random

rand_id = random.randint(10000, 99999) # 5 digits

url = "http://127.0.0.1:8000/api/v1/register"
data = {
    "personal_info": {
        "full_name": "Test User",
        "email": f"test_{rand_id}@example.com",
        "phone": f"06611{rand_id}", 
        "date_of_birth": "1990-01-01"
    },
    "role": "tourist",
    "password": "password123"
}

print(f"Sending data...")

req = urllib.request.Request(url, data=json.dumps(data).encode('utf-8'), headers={'Content-Type': 'application/json'})

try:
    with urllib.request.urlopen(req) as response:
        print("Success")
        print(response.read().decode('utf-8'))
except urllib.error.HTTPError as e:
    print(f"HTTP Error: {e.code}")
    content = e.read().decode('utf-8')
    with open('error_response.json', 'w', encoding='utf-8') as f:
        f.write(content)
except Exception as e:
    print(f"Error: {e}")
