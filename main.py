from fastapi import FastAPI, Depends, HTTPException
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session, sessionmaker
import httpx 

from models import Base, engine, Workout 
from schemas import WorkoutCreate
import os
from dotenv import load_dotenv
from datetime import datetime

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

#created using ai
@app.get("/api/auth/login")
def login_to_strava():
    # 1. We define the exact permissions (scopes) DAKSHboard needs to read your biometric files
    scopes = "activity:read_all,profile:read_all"
    
    # 2. We construct the secure URL using your Client ID loaded from the .env file
    # Notice we hardcode the redirect_uri to exactly match the developer portal
    strava_auth_url = (
        f"https://www.strava.com/oauth/authorize"
        f"?client_id={os.getenv('STRAVA_CLIENT_ID')}"
        f"&response_type=code"
        f"&redirect_uri=http://127.0.0.1:8000/api/auth/callback"
        f"&approval_prompt=force"
        f"&scope={scopes}"
    )
    
    # 3. We command the user's browser to leave our site and go to Strava
    return RedirectResponse(strava_auth_url)


@app.get("/api/auth/callback")
async def strava_callback(code: str, scope: str = ""):
    # 1. The URL parameter 'code' is caught automatically by FastAPI.
    
    # 2. We prepare the cryptographic exchange payload.
    # The POST request requires the parameters client_id, client_secret, code, and grant_type (set to 'authorization_code').
    token_url = "https://www.strava.com/oauth/token"
    payload = {
        "client_id": os.getenv("STRAVA_CLIENT_ID"),
        "client_secret": os.getenv("STRAVA_CLIENT_SECRET"),
        "code": code,
        "grant_type": "authorization_code"
    }
    
    # 3. We open an async connection and send the payload to Strava
    async with httpx.AsyncClient() as client:
        response = await client.post(token_url, data=payload)
        
    # 4. If Strava rejects the math, we crash gracefully
    if response.status_code != 200:
        raise HTTPException(status_code=400, detail="Strava Handshake Failed")
        
    # 5. We extract the JSON vault keys 
    strava_data = response.json()
    
    # For right now, we print it back to your screen to prove the handshake worked.
    # Once verified, we will route this data directly into your local SQLite database.
    return {
        "message": "Authentication Successful",
        "athlete_id": strava_data.get("athlete", {}).get("id"),
        "access_token": strava_data.get("access_token"),
        "refresh_token": strava_data.get("refresh_token")
    }
@app.get("/api/strava/sync-latest")
async def sync_latest_strava_runs(db: Session = Depends(get_db)):
    # 1. Fetch access token from environment
    access_token = os.getenv("STRAVA_ACCESS_TOKEN")
    if not access_token:
        raise HTTPException(status_code=401, detail="No access token found. Please authenticate first.")
    
    headers = {"Authorization": f"Bearer {access_token}"}
    strava_activities_url = "https://www.strava.com/api/v3/athlete/activities?per_page=10"
    
    # 2. Fetch raw activities from Strava
    async with httpx.AsyncClient() as client:
        response = await client.get(strava_activities_url, headers=headers)
        
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch data from Strava")
        
    raw_activities = response.json()
    synced_workouts = []
    
    # 3. Parse and extract telemetry for each activity
    for act in raw_activities:
        # Filter for running activities
        if act.get("type") in ["Run", "Workout"]:
            
            # Convert distance from meters to kilometers (rounded to 2 decimal places)
            distance_km = round(act.get("distance", 0.0) / 1000.0, 2)
            
            # Parse ISO date string to Python datetime
            raw_date = act.get("start_date_local")
            workout_date = datetime.fromisoformat(raw_date.replace("Z", "+00:00")) if raw_date else datetime.utcnow()
            
            moving_time = act.get("moving_time", 0)
            
            # Check if this exact workout is already saved in SQLite to prevent duplicates
            existing = db.query(Workout).filter(
                Workout.total_distance == distance_km,
                Workout.moving_time == moving_time
            ).first()
            
            if not existing:
                # Map cleaned Strava metrics into the SQLAlchemy Workout model
                db_workout = Workout(
                    date=workout_date,
                    total_distance=distance_km,
                    moving_time=moving_time,
                    elapsed_time=act.get("elapsed_time", 0),
                    total_elevation_gain=act.get("total_elevation_gain", 0.0),
                    average_heartrate=act.get("average_heartrate"),
                    max_heartrate=act.get("max_heartrate"),
                    average_cadence=act.get("average_cadence"),
                    user_id=1  # Assigned to default local user ID
                )
                
                db.add(db_workout)
                synced_workouts.append(db_workout)
                
    # 4. Commit all new workouts into the SQLite database file
    db.commit()
    
    return {
        "status": "success",
        "new_workouts_saved": len(synced_workouts),
        "message": f"Successfully parsed and stored {len(synced_workouts)} run(s) in dakshboard_local.db"
    }