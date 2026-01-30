import sqlalchemy
from sqlalchemy import create_engine, text

# Connect to 'postgres' database to create new DB
DATABASE_URL = "postgresql+pg8000://postgres:2006@localhost:5432/postgres"

engine = create_engine(DATABASE_URL, isolation_level="AUTOCOMMIT")

with engine.connect() as conn:
    print("Connecting to postgres database...")
    # Check if database exists
    result = conn.execute(text("SELECT 1 FROM pg_database WHERE datname = 'Morchid_Hub'"))
    if not result.fetchone():
        print("Creating database Morchid_Hub...")
        conn.execute(text('CREATE DATABASE "Morchid_Hub"'))
        print("Database created successfully!")
    else:
        print("Database Morchid_Hub already exists.")
