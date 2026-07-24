from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session, sessionmaker

from models import Base, engine, Workout 
from schemas import WorkoutCreate
import os
from dotenv import load_dotenv

load_dotenv()
strava_secret = os.getenv("STRAVA_CLIENT_SECRET")
print(f"SECURITY CHECK: the secret loaded is {strava_secret}")

# Create database tables if they don't exist
Base.metadata.create_all(bind=engine)

# Initialize FastAPI App
app = FastAPI(title="DAKSHboard API")

# Database Session Dependency
def get_db():
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# The Ingestion Endpoint
@app.post("/api/workouts/")
def create_workout(workout: WorkoutCreate, db: Session = Depends(get_db)):
    db_workout = Workout(**workout.model_dump())
    db.add(db_workout)
    db.commit()
    db.refresh(db_workout)
    return db_workout

#get framework
#all workouts
@app.get("/api/workouts/")
def read_workouts(db: Session = Depends(get_db)):
    workouts = db.query(Workout).all()
    return workouts

#single workout
@app.get("/api/workouts/{workout_id}")
def read_workout(workout_id: int, db: Session = Depends(get_db)):
    workout = db.query(Workout).filter(Workout.id == workout_id).first()
    if not workout:
        raise HTTPException(status_code = 404, detail = "workout not found")
    return workout