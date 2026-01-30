
from app.database import engine, Base
from app.models import User, Guide

print("Dropping tables...")
Base.metadata.drop_all(bind=engine)
print("Tables dropped.")
