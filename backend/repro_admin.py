
import requests
import json
import sys
import os

# Configuration
BASE_URL = "http://localhost:8000"
EMAIL = "arodmohamed111666@gmail.com"
PASSWORD = "reda2006"
OUTPUT_FILE = "repro_results.txt"

def log(msg):
    print(msg)
    with open(OUTPUT_FILE, "a", encoding="utf-8") as f:
        f.write(msg + "\n")

def test_admin_access():
    if os.path.exists(OUTPUT_FILE):
        os.remove(OUTPUT_FILE)
        
    log(f"[-] Attempting login as {EMAIL}...")
    
    # 1. Login
    login_data = {
        "email": EMAIL,
        "password": PASSWORD
    }
    
    try:
        response = requests.post(f"{BASE_URL}/api/v1/login", json=login_data)
        
        if response.status_code != 200:
            log(f"[!] Login failed. Status: {response.status_code}")
            log(f"[!] Response: {response.text}")
            return
            
        data = response.json()
        token = data.get("access_token")
        user = data.get("user", {})
        
        log(f"[+] Login successful!")
        log(f"[+] User Info: ID={user.get('id')}, Role={user.get('role')}, IsAdmin={user.get('is_admin')}")
        
        # 2. Access Admin Endpoint
        log(f"[-] Attempting to access protected admin endpoint: /api/v1/admin/users")
        
        headers = {
            "Authorization": f"Bearer {token}"
        }
        
        admin_response = requests.get(f"{BASE_URL}/api/v1/admin/users", headers=headers)
        
        log(f"[-] Status Code: {admin_response.status_code}")
        # Truncate response if too long
        resp_text = admin_response.text
        if len(resp_text) > 500:
            resp_text = resp_text[:500] + "..."
            
        log(f"[-] Response: {resp_text}")
        
        if admin_response.status_code == 200:
            log(f"[SUCCESS] Access Granted! The issue is resolved.")
        elif admin_response.status_code == 403:
            log(f"[FAIL] Access Denied (403). The issue persists.")
        else:
            log(f"[FAIL] Unexpected error. Status: {admin_response.status_code}")

    except Exception as e:
        log(f"[!] Exception occurred: {e}")

if __name__ == "__main__":
    test_admin_access()
