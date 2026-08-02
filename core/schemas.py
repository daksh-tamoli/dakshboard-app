from pydantic import BaseModel
from datetime import datetime
from typing import Optional

# THE TELEMETRY FIREWALL
# When the phone sends JSON, Pydantic will check it against this class. 
# If 'latitude' is missing or sent as a text string, Pydantic rejects the request with a 422 error.

class WorkoutBase(BaseModel):
    date: datetime
    total_distance: float
    moving_time: int
    elapsed_time: int
    total_elevation_gain: float
    average_heartrate: Optional[float] = None
    max_heartrate: Optional[float] = None
    average_cadence: Optional[float] = None
    
    # NEW: Allow API to send/receive streams
    time_stream: Optional[str] = None
    heartrate_stream: Optional[str] = None
    velocity_stream: Optional[str] = None
    distance_stream: Optional[str] = None

class TelemetryCreate(BaseModel):
    timestamp: datetime
    latitude: float
    longitude: float
    heart_rate: int

class WorkoutCreate(BaseModel):
    date: datetime
    total_distance: float
    moving_time: int
    elapsed_time: int
    total_elevation_gain: float

    average_heartrate: Optional[float] = None
    max_heartrate: Optional[float] = None
    average_cadence: Optional[float] = None

class Workout(WorkoutBase):
    id: int
    user_id: int

    class Config:
        orm_mode = True