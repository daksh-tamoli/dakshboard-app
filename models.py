from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Index
from sqlalchemy.orm import declarative_base, relationship

Base = declarative_base()

class User(Base):
    __tablename__ = 'users'
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    max_hr = Column(Integer, nullable=True)
    ftp = Column(Integer, nullable=True) 
    workouts = relationship("Workout", back_populates="user", cascade="all, delete-orphan")

# WORKOUT
class Workout(Base):
    __tablename__ = 'workouts'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id'))
    user = relationship("User", back_populates="workouts")
    date = Column(DateTime, index=True)
    total_distance = Column(Float)
    moving_time = Column(Integer)
    elapsed_time = Column(Integer)
    total_elevation_gain = Column(Float)

    average_heartrate = Column(Float)
    max_heartrate = Column(Float)
    average_cadence = Column(Float)

# TELEMETRY
class Telemetry(Base):
    __tablename__ = 'telemetry'

    id = Column(Integer, primary_key = True, index = True)
    workout_id = Column(Integer, ForeignKey('workouts.id', ondelete = "CASCADE"))

    timestamp = Column(DateTime)
    latitude = Column(Float)
    longitude = Column(Float)
    heart_rate = Column(Integer)

#AI WAS USED HERE ONWARDS
    # --- THE IGNITION SEQUENCE ---
from sqlalchemy import create_engine

# 1. Create the database engine (SQLite for local testing)
# echo=True tells SQLAlchemy to print the raw SQL commands to your terminal so you can see it working.
engine = create_engine('sqlite:///dakshboard_local.db', echo=True)

# 2. Command the Base to build all the tables based on your blueprints
Base.metadata.create_all(engine)
print("DAKSHboard Database successfully initialized.")