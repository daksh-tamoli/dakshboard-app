from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session, sessionmaker
import httpx 

from models import Base, engine, Workout, User 
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

# Auto-migrate SQLite schema for missing columns
try:
    with engine.connect() as conn:
        from sqlalchemy import text
        result = conn.execute(text("PRAGMA table_info(workouts)"))
        existing_cols = [row[1] for row in result.fetchall()]
        if "type" not in existing_cols:
            conn.execute(text("ALTER TABLE workouts ADD COLUMN type TEXT"))
            conn.commit()
except Exception as migration_err:
    print(f"Migration check warning: {migration_err}")

# Initialize FastAPI App
app = FastAPI(title="DAKSHboard API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)   

@app.get("/")
def read_root():
    return {
        "status": "online",
        "message": "DAKSHboard API is running",
        "documentation": "/docs"
    }

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
def login_to_strava(request: Request):
    scopes = "read,activity:read_all,profile:read_all"
    backend_base = os.getenv("BACKEND_URL")
    
    if not backend_base:
        scheme = request.headers.get("x-forwarded-proto", request.url.scheme)
        host = request.headers.get("x-forwarded-host", request.url.netloc)
        backend_base = f"{scheme}://{host}"
        
    backend_base = backend_base.rstrip("/")
    redirect_uri = f"{backend_base}/api/auth/callback"
    import urllib.parse
    encoded_redirect = urllib.parse.quote(redirect_uri, safe='')
    
    strava_auth_url = (
        f"https://www.strava.com/oauth/authorize"
        f"?client_id={os.getenv('STRAVA_CLIENT_ID')}"
        f"&response_type=code"
        f"&redirect_uri={encoded_redirect}"
        f"&approval_prompt=force"
        f"&scope={scopes}"
    )
    return RedirectResponse(strava_auth_url)


@app.get("/api/auth/callback")
async def strava_callback(code: str, scope: str = "", request: Request = None, db: Session = Depends(get_db)):
    frontend_base = os.getenv("FRONTEND_URL")
    if not frontend_base and request:
        referer = request.headers.get("referer")
        if referer and "localhost" not in referer and "127.0.0.1" not in referer:
            from urllib.parse import urlparse
            parsed = urlparse(referer)
            frontend_base = f"{parsed.scheme}://{parsed.netloc}"
            
    if not frontend_base:
        frontend_base = "http://localhost:5173"
        
    frontend_base = frontend_base.rstrip("/")
    token_url = "https://www.strava.com/oauth/token"
    payload = {
        "client_id": os.getenv("STRAVA_CLIENT_ID"),
        "client_secret": os.getenv("STRAVA_CLIENT_SECRET"),
        "code": code,
        "grant_type": "authorization_code"
    }
    
    async with httpx.AsyncClient() as client:
        response = await client.post(token_url, data=payload)
        
    if response.status_code != 200:
        print(f"STRAVA OAUTH HANDSHAKE FAILED: {response.text}")
        return RedirectResponse(url=f"{frontend_base}/?auth=error")
        
    strava_data = response.json()
    access_token = strava_data.get("access_token")
    refresh_token = strava_data.get("refresh_token")
    athlete_data = strava_data.get("athlete", {})
    athlete_id = athlete_data.get("id")

    # Save/Update User in Database for Multi-User Support
    if athlete_id:
        existing_user = db.query(User).filter(User.strava_id == athlete_id).first()
        if existing_user:
            existing_user.access_token = access_token
            existing_user.refresh_token = refresh_token
            existing_user.firstname = athlete_data.get("firstname")
            existing_user.lastname = athlete_data.get("lastname")
            existing_user.profile = athlete_data.get("profile")
        else:
            new_user = User(
                strava_id=athlete_id,
                access_token=access_token,
                refresh_token=refresh_token,
                firstname=athlete_data.get("firstname"),
                lastname=athlete_data.get("lastname"),
                profile=athlete_data.get("profile")
            )
            db.add(new_user)
        db.commit()
    
    # Also persist default tokens into .env file if available
    ENV_PATH = Path(__file__).resolve().parent / ".env"
    if ENV_PATH.exists():
        if access_token:
            set_key(str(ENV_PATH), "STRAVA_ACCESS_TOKEN", access_token)
            os.environ["STRAVA_ACCESS_TOKEN"] = access_token
        if refresh_token:
            set_key(str(ENV_PATH), "STRAVA_REFRESH_TOKEN", refresh_token)
            os.environ["STRAVA_REFRESH_TOKEN"] = refresh_token
        
    # Trigger automatic workout ingestion
    try:
        await sync_latest_strava_runs(strava_id=athlete_id, db=db)
    except Exception as e:
        print(f"Auto-sync during callback encountered error: {e}")
        
    # Redirect browser back to React dashboard frontend with success status and athlete info
    import urllib.parse
    athlete_param = urllib.parse.quote(json.dumps(athlete_data)) if athlete_data else ""
    return RedirectResponse(url=f"{frontend_base}/?auth=success&athlete={athlete_param}")




@app.get("/api/strava/sync-latest")
async def sync_latest_strava_runs(strava_id: int = None, db: Session = Depends(get_db)):
    ENV_PATH = Path(__file__).resolve().parent / ".env"
    if ENV_PATH.exists():
        load_dotenv(ENV_PATH, override=True)

    client_id = os.getenv("STRAVA_CLIENT_ID")
    client_secret = os.getenv("STRAVA_CLIENT_SECRET")
    
    # Resolve target user token from Database or fallback to .env
    target_user = None
    if strava_id:
        target_user = db.query(User).filter(User.strava_id == strava_id).first()
    if not target_user:
        target_user = db.query(User).order_by(User.id.desc()).first()

    refresh_token = target_user.refresh_token if (target_user and target_user.refresh_token) else os.getenv("STRAVA_REFRESH_TOKEN")

    if not all([client_id, client_secret, refresh_token]):
        print("CRITICAL ERROR: Missing Strava credentials. Please log in first.")
        raise HTTPException(status_code=500, detail="Missing Strava OAuth credentials. Please log in first.")

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
            print(f"STRAVA AUTH FAILURE: {auth_response.text}")
            raise HTTPException(status_code=401, detail="Failed to refresh Strava access token.")
            
        auth_data = auth_response.json()
        active_access_token = auth_data.get("access_token")
        new_refresh_token = auth_data.get("refresh_token")
        
        if target_user:
            target_user.access_token = active_access_token
            if new_refresh_token:
                target_user.refresh_token = new_refresh_token
            db.commit()

        if ENV_PATH.exists() and new_refresh_token:
            set_key(str(ENV_PATH), "STRAVA_ACCESS_TOKEN", active_access_token)
            set_key(str(ENV_PATH), "STRAVA_REFRESH_TOKEN", new_refresh_token)

        headers = {"Authorization": f"Bearer {active_access_token}"}
        strava_activities_url = "https://www.strava.com/api/v3/athlete/activities?per_page=200"
        
        response = await client.get(strava_activities_url, headers=headers)
        
        if response.status_code != 200:
            print(f"STRAVA API FAILURE (Activities): {response.text}")
            raise HTTPException(status_code=response.status_code, detail="Failed to fetch activities")
            
        raw_activities = response.json()
        synced_workouts = []
        user_db_id = target_user.id if target_user else 1
        
        for act in raw_activities:
            act_type = act.get("type", "Other")
            distance_km = round(act.get("distance", 0.0) / 1000.0, 2)
            raw_date = act.get("start_date_local")
            workout_date = datetime.fromisoformat(raw_date.replace("Z", "+00:00")) if raw_date else datetime.utcnow()
            moving_time = act.get("moving_time", 0)
            
            existing = db.query(Workout).filter(
                Workout.user_id == user_db_id,
                Workout.total_distance == distance_km,
                Workout.moving_time == moving_time
            ).first()
            
            if not existing:
                streams_url = f"https://www.strava.com/api/v3/activities/{act['id']}/streams?keys=time,heartrate,velocity_smooth,altitude,cadence&key_by_type=true"
                stream_res = await client.get(streams_url, headers=headers)
                streams_data = stream_res.json() if stream_res.status_code == 200 else {}
                
                laps_url = f"https://www.strava.com/api/v3/activities/{act['id']}/laps"
                laps_res = await client.get(laps_url, headers=headers)
                laps_data = laps_res.json() if laps_res.status_code == 200 else []

                db_workout = Workout(
                    type=act_type,
                    date=workout_date,
                    total_distance=distance_km,
                    moving_time=moving_time,
                    elapsed_time=act.get("elapsed_time", 0),
                    total_elevation_gain=act.get("total_elevation_gain", 0.0),
                    average_heartrate=act.get("average_heartrate"),
                    max_heartrate=act.get("max_heartrate"),
                    average_cadence=act.get("average_cadence"),
                    user_id=user_db_id,
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