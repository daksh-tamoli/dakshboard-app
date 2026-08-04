from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class WorkoutCreate(BaseModel):
    date: datetime
    total_distance: float
    moving_time: int
    elapsed_time: int
    total_elevation_gain: float
    average_heartrate: Optional[float] = None
    max_heartrate: Optional[float] = None
    average_cadence: Optional[float] = None

class WorkoutOut(BaseModel):
    """Response model returned by /api/workouts/ — matches Flutter Workout.fromJson() exactly"""
    id: int
    type: Optional[str] = None
    date: Optional[datetime] = None
    total_distance: float = 0.0
    moving_time: int = 0
    elapsed_time: int = 0
    total_elevation_gain: float = 0.0
    average_heartrate: Optional[float] = None
    max_heartrate: Optional[float] = None
    average_cadence: Optional[float] = None
    pace_stream: Optional[str] = None
    heartrate_stream: Optional[str] = None
    time_stream: Optional[str] = None
    elevation_stream: Optional[str] = None
    cadence_stream: Optional[str] = None
    laps_data: Optional[str] = None
    user_id: Optional[int] = None

    class Config:
        from_attributes = True  # Pydantic v2 (was orm_mode in v1)

class MaxHrUpdate(BaseModel):
    max_hr: int