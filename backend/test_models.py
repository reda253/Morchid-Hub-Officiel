
from app.database import engine, Base, SessionLocal
from app.models import User, Guide, GuideRoute

def test_models():
    print("Creating tables...")
    try:
        Base.metadata.create_all(bind=engine)
        print("Tables created successfully.")
    except Exception as e:
        print(f"Error creating tables: {e}")
        import traceback
        traceback.print_exc()
        return


    print("Testing data insertion...")
    db = SessionLocal()
    try:
        # Create Dummy User & Guide
        import uuid
        uid = str(uuid.uuid4())
        user = User(
            id=uid, email=f"test{uid}@example.com", full_name="Test User", role="guide",
            is_active=True, is_email_verified=True
        )
        db.add(user)
        
        guide = Guide(
            user_id=uid, languages=["en"], specialties=["history"],
            cities_covered=["city"], bio="bio", years_of_experience=1
        )
        db.add(guide)
        db.commit()
        db.refresh(guide)
        
        # Create Dummy Route
        from shapely.geometry import Point, LineString
        from geoalchemy2.shape import from_shape
        
        start_point = Point(-7.5898, 33.5731)
        end_point = Point(-7.6100, 33.5850)
        route_line = LineString([(-7.5898, 33.5731), (-7.6100, 33.5850)])
        
        route = GuideRoute(
            guide_id=guide.id,
            route_line=from_shape(route_line, srid=4326),
            start_point=from_shape(start_point, srid=4326),
            end_point=from_shape(end_point, srid=4326),
            coordinates=[{"lat": 33.5731, "lng": -7.5898}],
            distance=1.0, duration=10.0,
            start_address="Start", end_address="End",
            is_active=True
        )
        db.add(route)
        db.commit()
        print("Route inserted successfully!")
        
    except Exception as e:
        print(f"Error inserting: {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    test_models()
