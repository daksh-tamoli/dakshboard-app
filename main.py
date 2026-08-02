from fastapi import FastAPI, Depends, HTTPException
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session, sessionmaker
import httpx 

from models import Base, engine, Workout 
from schemas import WorkoutCreate
import os
from dotenv import load_dotenv, set_key, find_dotenv
from datetime import datetime
import json
from pathlib import Path

from fastapi.middleware.cors import CORSMiddleware

load_dotenv()
strava_secret = os.getenv("STRAVA_CLIENT_SECRET")
print(f"SECURITY CHECK: the secret loaded is {strava_secret}")

# Create database tables if they don't exist
Base.metadata.create_all(bind=engine)

# Initialize FastAPI App
app = FastAPI(title="DAKSHboard API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)   

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

    
    ENV_PATH = Path(__file__).resolve().parent / ".env"
    if not ENV_PATH.exists():
        print(f"CRITICAL SYSTEM ERROR: .env file NOT FOUND at {ENV_PATH}")
        raise HTTPException(status_code=500, detail="Missing .env file.")
    load_dotenv(ENV_PATH, override=True)

    client_id = os.getenv("STRAVA_CLIENT_ID")
    client_secret = os.getenv("STRAVA_CLIENT_SECRET")
    refresh_token = os.getenv("STRAVA_REFRESH_TOKEN")


    if not all([client_id, client_secret, refresh_token]):
        print("CRITICAL ERROR: Missing Strava credentials. Check your .env file.")
        raise HTTPException(status_code=500, detail="Missing Strava OAuth credentials.")

    async with httpx.AsyncClient() as client:
        auth_url = "https://www.strava.com/oauth/token"
        auth_payload = {
            "client_id": client_id,
            "client_secret": client_secret,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token"
        }
        
        auth_response = await client.post(auth_url, data=auth_payload)
        
        if auth_response.status_code != 200:
            # Printing the reason Strava rejected the refresh
            print(f"STRAVA AUTH FAILURE: {auth_response.text}")
            raise HTTPException(status_code=401, detail="Failed to refresh Strava access token.")
            
        auth_data = auth_response.json()
        active_access_token = auth_data.get("access_token")
        new_refresh_token = auth_data.get("refresh_token")
        print("Token refreshed successfully. Fetching activities...")
        
        if new_refresh_token:
            set_key(str(ENV_PATH), "STRAVA_ACCESS_TOKEN", active_access_token)
            set_key(str(ENV_PATH), "STRAVA_REFRESH_TOKEN", new_refresh_token)
            os.environ["STRAVA_ACCESS_TOKEN"] = active_access_token
            os.environ["STRAVA_REFRESH_TOKEN"] = new_refresh_token
            print(f"Successfully rotated tokens and saved to: {ENV_PATH}")
        headers = {"Authorization": f"Bearer {active_access_token}"}
        strava_activities_url = "https://www.strava.com/api/v3/athlete/activities?per_page=200"
        
        response = await client.get(strava_activities_url, headers=headers)
        
        if response.status_code != 200:
            print(f"STRAVA API FAILURE (Activities): {response.text}")
            raise HTTPException(status_code=response.status_code, detail="Failed to fetch activities")
            
        raw_activities = response.json()
        synced_workouts = []
        
        for act in raw_activities:
            if act.get("type") in ["Run", "Workout"]:
                distance_km = round(act.get("distance", 0.0) / 1000.0, 2)
                raw_date = act.get("start_date_local")
                workout_date = datetime.fromisoformat(raw_date.replace("Z", "+00:00")) if raw_date else datetime.utcnow()
                moving_time = act.get("moving_time", 0)
                
                existing = db.query(Workout).filter(
                    Workout.total_distance == distance_km,
                    Workout.moving_time == moving_time
                ).first()
                
                if not existing:
                    # FETCH ALL STREAMS
                    streams_url = f"https://www.strava.com/api/v3/activities/{act['id']}/streams?keys=time,heartrate,velocity_smooth,altitude,cadence&key_by_type=true"
                    stream_res = await client.get(streams_url, headers=headers)
                    if stream_res.status_code != 200:
                        print(f"STRAVA API FAILURE (Streams) for {act['id']}: {stream_res.text}")
                    streams_data = stream_res.json() if stream_res.status_code == 200 else {}
                    
                    # FETCH LAPS
                    laps_url = f"https://www.strava.com/api/v3/activities/{act['id']}/laps"
                    laps_res = await client.get(laps_url, headers=headers)
                    if laps_res.status_code != 200:
                        print(f"STRAVA API FAILURE (Laps) for {act['id']}: {laps_res.text}")
                    laps_data = laps_res.json() if laps_res.status_code == 200 else []

                    db_workout = Workout(
                        date=workout_date,
                        total_distance=distance_km,
                        moving_time=moving_time,
                        elapsed_time=act.get("elapsed_time", 0),
                        total_elevation_gain=act.get("total_elevation_gain", 0.0),
                        average_heartrate=act.get("average_heartrate"),
                        max_heartrate=act.get("max_heartrate"),
                        average_cadence=act.get("average_cadence"),
                        user_id=1,
                        time_stream=json.dumps(streams_data.get('time', {}).get('data')) if 'time' in streams_data else None,
                        heartrate_stream=json.dumps(streams_data.get('heartrate', {}).get('data')) if 'heartrate' in streams_data else None,
                        pace_stream=json.dumps(streams_data.get('velocity_smooth', {}).get('data')) if 'velocity_smooth' in streams_data else None,
                        elevation_stream=json.dumps(streams_data.get('altitude', {}).get('data')) if 'altitude' in streams_data else None,
                        cadence_stream=json.dumps(streams_data.get('cadence', {}).get('data')) if 'cadence' in streams_data else None,
                        laps_data=json.dumps(laps_data)
                    )
                    
                    db.add(db_workout)
                    synced_workouts.append(db_workout)
                    
        db.commit()
        print(f"Sync complete. {len(synced_workouts)} new workouts saved.")
        return {"status": "success", "new_workouts": len(synced_workouts)}
        
@app.delete("/api/workouts/{workout_id}")
def delete_workout(workout_id: int, db: Session = Depends(get_db)):
    workout = db.query(Workout).filter(Workout.id == workout_id).first()
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    
    db.delete(workout)
    db.commit()
    
    return {"message": "Workout permanently deleted"}