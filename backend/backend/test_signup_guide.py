
import urllib.request
import json
import urllib.error
import random

rand_id = random.randint(10000, 99999)

url = "http://127.0.0.1:8000/api/v1/register"
data = {
    "personal_info": {
        "full_name": "Test Guide",
        "email": f"guide_{rand_id}@example.com",
        "phone": f"06611{rand_id}", 
        "date_of_birth": "1990-01-01"
    },
    "role": "guide",
    "password": "password123",
    "guide_details": {
        "languages": ["French", "English"],
        "specialties": ["histoire", "culture"],
        "cities_covered": ["Marrakech"],
        "years_of_experience": 5,
        "bio": "Expert guide with 5 years experience. I love showing people around my beautiful city of Marrakech and sharing its history."
    }
}

print(f"Sending guide data...")

req = urllib.request.Request(url, data=json.dumps(data).encode('utf-8'), headers={'Content-Type': 'application/json'})

try:
    with urllib.request.urlopen(req) as response:
        print("Success")
        print(response.read().decode('utf-8'))
except urllib.error.HTTPError as e:
    print(f"HTTP Error: {e.code}")
    content = e.read().decode('utf-8')
    print(content)
    with open('guide_error.txt', 'w', encoding='utf-8') as f:
        f.write(content)
except Exception as e:
    print(f"Error: {e}")
