
import sys
print(sys.executable)
try:
    import sqlalchemy
    print("sqlalchemy imported")
except ImportError as e:
    print(e)

try:
    import fastapi
    print("fastapi imported")
except ImportError as e:
    print(e)
    
try:
    import pg8000
    print("pg8000 imported")
except ImportError as e:
    print(e)

try:
    import passlib
    print("passlib imported")
except ImportError as e:
    print(e)
    
try:
    import jose
    print("jose imported")
except ImportError as e:
    print(e)
