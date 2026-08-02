# DAKSHboard - Comprehensive Product Review

## Executive Summary
**DAKSHboard** is a specialized athletic performance telemetry and workout analytics platform built with a **FastAPI** backend and a modern **React + Vite** frontend. It enables endurance athletes and runners to connect their Strava accounts, ingest multi-metric workout telemetry (heart rate, pace, elevation, cadence, laps), and visualize performance trends across time.

---

## 1. Product Architecture Overview

```
+------------------+         +------------------+         +-----------------------+
|   Strava API /   |  OAuth  |   FastAPI Core   | SQLite  |   React + Vite UI     |
| OAuth Service    | <-----> |   (Port 8000)    | <-----> |  (Recharts Dashboard) |
+------------------+         +------------------+         +-----------------------+
                                      |
                              Stream Parsing &
                              Lap Analysis Engine
```

### Core Components
1. **Backend Engine (`/core`)**
   - **Framework**: FastAPI with Uvicorn server.
   - **Database**: SQLite (`dakshboard_local.db`) managed via SQLAlchemy ORM.
   - **Data Models**:
     - `User`: User profile storing biometric limits (`max_hr`, `ftp`).
     - `Workout`: Summary stats (distance, duration, elevation gain, average HR, cadence, activity type) and stringified stream records (`time_stream`, `heartrate_stream`, `pace_stream`, `elevation_stream`, `cadence_stream`, `laps_data`).
     - `Telemetry`: Granular timestamped GPS and biometric data points.
   - **Integrations**: Strava OAuth 2.0 flow (`/api/auth/login`, `/api/auth/callback`) and automated workout sync (`/api/strava/sync-latest`).

2. **Frontend UI (`/dakshboard-web`)**
   - **Framework**: React 18 powered by Vite.
   - **Visualization**: `Recharts` library for interactive charts.
   - **Features**:
     - Monthly aggregation sidebar with active day counters and maximum streak computation.
     - Multi-layer filtering by month and activity type (`Run`, `Ride`, `Swim`, etc.).
     - Telemetry modal displaying pace conversion, heart rate distribution, elevation profile, and lap metrics.
     - Workout management (sync, delete).

---

## 2. Feature & Functionality Review

| Feature Category | Current Capability | Grade | Notes & Observations |
| :--- | :--- | :---: | :--- |
| **Data Ingestion** | Strava OAuth 2.0 & automated sync | **B+** | Works cleanly for Strava; manual file uploads (.FIT, .GPX) are currently missing. |
| **Telemetry Analysis** | Stream breakdown (HR, pace, elevation) | **A-** | Rich telemetry visualization per workout; relies on JSON-in-TEXT serialization. |
| **User Analytics** | Monthly stats, streaks, activity filters | **B+** | Great overview; lacks year-over-year or long-term training load (CTL/ATL/TSB) metrics. |
| **User Management** | Single local user context | **C+** | User ID is implicit/hardcoded in local testing; no multi-tenant JWT auth on API endpoints. |
| **UX & Visual Design** | Dark modern dashboard theme | **B+** | Clean layout with Recharts, responsive sidebar filter, and modal drill-down. |

---

## 3. Key Strengths
1. **Fast, Lightweight Architecture**: FastAPI combined with Vite results in near-instant hot-reloading and fast API responses.
2. **Deep Telemetry Breakdown**: Storing and rendering granular telemetry streams (pace, cadence, elevation, HR, laps) provides meaningful insights beyond standard summary statistics.
3. **Endurance-Specific Metrics**: Includes custom athletic algorithms like pace formatting (`calculatePace`), decimal velocity conversion (`msToMinKmDecimal`), and streak tracking.

---

## 4. Identified Technical Debt & Gaps

### Technical Debt
- **JSON Serialization in Relational DB**: Streams are stored as stringified TEXT columns (`time_stream`, `heartrate_stream`, etc.) rather than PostgreSQL JSONB or normalized time-series structures.
- **Hardcoded CORS & Local Endpoints**: API endpoints (`http://127.0.0.1:8000`) and CORS origins are hardcoded, requiring configuration centralization via environment variables (`VITE_API_BASE_URL`).
- **Single-User Hardcoding**: User authentication is minimal; multi-tenancy auth headers and session tokens are needed for production readiness.

### Functional Gaps
- **Third-Party Providers**: Support is currently limited to Strava (missing Garmin Connect, Wahoo, Apple Health, Coros, or raw FIT/TCX upload).
- **Advanced Performance Modeling**: Lacks Training Stress Score (TSS), Acute Training Load (ATL), Chronic Training Load (CTL), and Training Stress Balance (TSB) metrics.
- **Automated Testing**: Test suite coverage (`pytest` / React Testing Library) is minimal.

---

## 5. Strategic Recommendations & Next Steps

### Short-Term (1-2 Sprints)
- [ ] **Environment Configuration**: Refactor frontend fetch URLs to use `import.meta.env.VITE_API_URL`.
- [ ] **Manual File Import**: Add `.FIT` / `.GPX` file parser endpoints to allow uploading activities without relying solely on Strava.
- [ ] **API Unit Testing**: Implement pytest suite for `/api/workouts/` and Strava callback endpoints.

### Medium-Term (3-6 Sprints)
- [ ] **Multi-User Authentication**: Integrate JWT token-based auth or Firebase/OAuth login for full multi-tenant isolation.
- [ ] **Time-Series Optimization**: Migrate telemetry storage to PostgreSQL with TSVECTOR/JSONB or influx/Timescale DB for faster multi-workout comparative analysis.
- [ ] **Advanced Metrics Dashboard**: Implement Training Load (CTL/ATL/TSB) graphs and Heart Rate Zone distribution views.

---

## 6. Related Documents Checklist
To further enrich this product review and align technical implementation with product requirements, please provide any of the following available documents:

1. **Product Requirements Document (PRD)** or Feature Specifications
2. **UI/UX Mockups or Figma Designs**
3. **Strava API Integration Credentials & Webhook Specs**
4. **Data Privacy & User Biometric Compliance Guidelines**
5. **Product Roadmap / Backlog Priorities**
