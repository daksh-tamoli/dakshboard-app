import { useEffect, useState } from 'react'
import { BarChart, Bar, LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, ReferenceLine } from 'recharts'

const formatDuration = (totalSeconds) => {
  if (!totalSeconds) return '0m 0s'
  const hours = Math.floor(totalSeconds / 3600)
  const mins = Math.floor((totalSeconds % 3600) / 60)
  return hours > 0 ? `${hours}hr ${mins}min` : `${mins}m ${totalSeconds % 60}s`
}

const calculatePace = (timeInSec, distInKm) => {
  if (!distInKm || distInKm === 0) return 'N/A'
  const secs = Math.floor((timeInSec / distInKm) % 60)
  return `${Math.floor((timeInSec / distInKm) / 60)}:${secs < 10 ? '0' : ''}${secs} /km`
}

const msToMinKmDecimal = (ms) => {
  if (!ms || ms === 0) return 0
  return (1000 / ms) / 60
}

const calculateMaxStreak = (dateStrings) => {
  if (dateStrings.length === 0) return 0
  const sortedDates = dateStrings.map(d => new Date(d)).sort((a, b) => a - b)
  let maxStreak = 1, currentStreak = 1
  for (let i = 1; i < sortedDates.length; i++) {
    const diffDays = Math.ceil(Math.abs(sortedDates[i] - sortedDates[i - 1]) / (1000 * 60 * 60 * 24))
    if (diffDays === 1) { currentStreak++; maxStreak = Math.max(maxStreak, currentStreak) } 
    else if (diffDays > 1) { currentStreak = 1 }
  }
  return maxStreak
}

// Activity Bifurcation Categorization Helper
const getActivityCategory = (typeStr) => {
  if (!typeStr) return 'Other'
  const lower = typeStr.toLowerCase()
  if (lower.includes('run') || lower.includes('walk') || lower.includes('hike')) return 'Run'
  if (lower.includes('ride') || lower.includes('cycle') || lower.includes('bike')) return 'Ride'
  if (lower.includes('swim')) return 'Swim'
  return 'Other'
}

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000'

function App() {
  const [workouts, setWorkouts] = useState([])
  const [loading, setLoading] = useState(true)
  const [syncing, setSyncing] = useState(false)
  const [selectedWorkout, setSelectedWorkout] = useState(null)
  const [authBanner, setAuthBanner] = useState(null)

  // Athlete Profile State
  const [athlete, setAthlete] = useState(() => {
    try {
      const saved = localStorage.getItem('strava_athlete')
      return saved ? JSON.parse(saved) : null
    } catch (e) {
      return null
    }
  })
  
  // STATE DEFINITIONS
  const [selectedMonth, setSelectedMonth] = useState('All')
  const [selectedType, setSelectedType] = useState('All')

  const fetchWorkouts = () => {
    fetch(`${API_BASE_URL}/api/workouts/`)
      .then((res) => res.json())
      .then((data) => {
        setWorkouts(data.sort((a, b) => new Date(a.date) - new Date(b.date)))
        setLoading(false)
      })
      .catch((err) => { console.error(err); setLoading(false) })
  }

  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    const athleteParam = params.get('athlete')

    if (athleteParam) {
      try {
        const parsedAthlete = JSON.parse(decodeURIComponent(athleteParam))
        setAthlete(parsedAthlete)
        localStorage.setItem('strava_athlete', JSON.stringify(parsedAthlete))
      } catch (e) {
        console.error("Failed to parse athlete parameters", e)
      }
    }

    if (params.get('auth') === 'success') {
      setAuthBanner({ type: 'success', text: 'Successfully authenticated with Strava and imported latest workouts!' })
      window.history.replaceState({}, document.title, window.location.pathname)
    } else if (params.get('auth') === 'error') {
      setAuthBanner({ type: 'error', text: 'Strava authentication failed. Please try again.' })
      window.history.replaceState({}, document.title, window.location.pathname)
    }
    fetchWorkouts()
  }, [])

  const handleStravaAuth = () => {
    const origin = encodeURIComponent(window.location.origin)
    window.location.href = `${API_BASE_URL}/api/auth/login?frontend_origin=${origin}`
  }

  const handleLogout = () => {
    localStorage.removeItem('strava_athlete')
    setAthlete(null)
    setAuthBanner({ type: 'success', text: 'Disconnected from Strava account.' })
  }

  const forceSync = () => {
    setSyncing(true)
    const syncUrl = athlete && athlete.id 
      ? `${API_BASE_URL}/api/strava/sync-latest?strava_id=${athlete.id}` 
      : `${API_BASE_URL}/api/strava/sync-latest`
      
    fetch(syncUrl)
      .then(res => res.json())
      .then((data) => {
        fetchWorkouts()
        setSyncing(false)
        setAuthBanner({ type: 'success', text: `Sync complete! ${data.new_workouts || 0} new workouts imported.` })
      })
      .catch(err => {
        console.error(err)
        setSyncing(false)
        setAuthBanner({ type: 'error', text: 'Failed to sync activities from Strava.' })
      })
  }

  const deleteWorkout = (e, id) => {
    e.stopPropagation() 
    if (!window.confirm("Permanently delete?")) return
    fetch(`${API_BASE_URL}/api/workouts/${id}`, { method: 'DELETE' })
      .then(() => {
        setWorkouts(workouts.filter(w => w.id !== id))
        if (selectedWorkout?.id === id) setSelectedWorkout(null)
      })
  }

  // SIDEBAR AGGREGATION
  const monthlyStats = workouts.reduce((acc, run) => {
    const date = new Date(run.date)
    const monthYear = date.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })
    const dayStr = date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })

    if (!acc[monthYear]) acc[monthYear] = { name: monthYear, runs: [], totalDistance: 0, totalTime: 0, activeDaysSet: new Set() }
    acc[monthYear].runs.push(run)
    acc[monthYear].totalDistance += (run.total_distance || 0)
    acc[monthYear].totalTime += (run.moving_time || 0)
    acc[monthYear].activeDaysSet.add(dayStr)
    return acc
  }, {})

  const sidebarMonths = Object.values(monthlyStats).map(stat => ({
    ...stat, activeDays: stat.activeDaysSet.size, streak: calculateMaxStreak(Array.from(stat.activeDaysSet))
  })).reverse()

  // MONTH & CATEGORY BIFURCATION FILTERING
  const displayedWorkouts = selectedMonth === 'All' ? workouts : monthlyStats[selectedMonth]?.runs || []
  
  // Calculate activity type counts dynamically
  const categoryCounts = displayedWorkouts.reduce((acc, run) => {
    const cat = getActivityCategory(run.type)
    acc[cat] = (acc[cat] || 0) + 1
    return acc
  }, { Run: 0, Ride: 0, Swim: 0, Other: 0 })

  const finalWorkouts = displayedWorkouts.filter(run => {
    if (selectedType === 'All') return true
    return getActivityCategory(run.type) === selectedType
  })

  // CHART DATA AGGREGATION (Based on filtered finalWorkouts)
  const aggregatedData = finalWorkouts.reduce((acc, run) => {
    const dateStr = new Date(run.date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
    if (!acc[dateStr]) acc[dateStr] = { name: dateStr, Distance: 0 }
    acc[dateStr].Distance += (run.total_distance || 0)
    return acc
  }, {})
  const chartData = Object.values(aggregatedData).map(d => ({ name: d.name, Distance: Number(d.Distance.toFixed(2)) }))

  const getStreamData = (workout) => {
    if (!workout || !workout.time_stream) return []
    try {
      const time = JSON.parse(workout.time_stream)
      const hr = workout.heartrate_stream ? JSON.parse(workout.heartrate_stream) : []
      const pace = workout.pace_stream ? JSON.parse(workout.pace_stream) : []
      const elev = workout.elevation_stream ? JSON.parse(workout.elevation_stream) : []
      const cad = workout.cadence_stream ? JSON.parse(workout.cadence_stream) : []
      
      return time.map((t, i) => ({
        time: formatDuration(t),
        hr: hr[i] || null,
        pace: msToMinKmDecimal(pace[i]),
        elevation: elev[i] || null,
        cadence: cad[i] ? cad[i] * 2 : null 
      })).filter((_, i) => i % 5 === 0) 
    } catch (e) { return [] }
  }

  const getLaps = (workout) => {
    if (!workout || !workout.laps_data) return []
    try { return JSON.parse(workout.laps_data) } catch (e) { return [] }
  }

  return (
    <div style={{ display: 'flex', backgroundColor: '#121212', color: '#fff', height: '100vh', width: '100vw', overflow: 'hidden', fontFamily: 'sans-serif' }}>
      
      {/* SIDEBAR */}
      <div style={{ width: '300px', minWidth: '300px', borderRight: '1px solid #2a2a2a', display: 'flex', flexDirection: 'column', backgroundColor: '#181818', height: '100vh' }}>
        <div style={{ padding: '1.5rem 1.5rem 1rem 1.5rem' }}>
          <h1 style={{ color: '#FC4C02', margin: '0 0 0.25rem 0', fontSize: '1.75rem', letterSpacing: '-0.5px' }}>DAKSHboard</h1>
          <p style={{ color: '#888', margin: '0 0 1.25rem 0', fontSize: '0.85rem' }}>Biometric Telemetry</p>

          {/* LOGGED IN ATHLETE PROFILE OR LOGIN BUTTON */}
          {athlete ? (
            <div style={{ backgroundColor: '#222', borderRadius: '8px', padding: '0.75rem 1rem', marginBottom: '1rem', border: '1px solid #333' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.5rem' }}>
                {athlete.profile ? (
                  <img src={athlete.profile} alt="Athlete" style={{ width: '40px', height: '40px', borderRadius: '50%', objectFit: 'cover' }} />
                ) : (
                  <div style={{ width: '40px', height: '40px', borderRadius: '50%', backgroundColor: '#FC4C02', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold' }}>
                    {athlete.firstname ? athlete.firstname[0] : 'S'}
                  </div>
                )}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontWeight: 'bold', fontSize: '0.95rem', color: '#fff', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {athlete.firstname} {athlete.lastname}
                  </div>
                  <div style={{ fontSize: '0.75rem', color: '#00c853', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '0.3rem' }}>
                    <span style={{ display: 'inline-block', width: '6px', height: '6px', borderRadius: '50%', backgroundColor: '#00c853' }}></span>
                    Connected to Strava
                  </div>
                </div>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid #333', paddingTop: '0.5rem', marginTop: '0.5rem' }}>
                <button onClick={handleLogout} style={{ background: 'none', border: 'none', color: '#888', cursor: 'pointer', fontSize: '0.75rem', padding: 0 }}>
                  Disconnect
                </button>
              </div>
            </div>
          ) : (
            <button 
              onClick={handleStravaAuth} 
              style={{ 
                width: '100%', 
                backgroundColor: '#FC4C02', 
                color: '#fff', 
                border: 'none', 
                borderRadius: '6px', 
                padding: '0.85rem', 
                fontWeight: 'bold', 
                cursor: 'pointer',
                marginBottom: '0.75rem',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '0.5rem'
              }}
            >
              <span>Connect with Strava</span>
            </button>
          )}

          <button 
            onClick={forceSync} 
            disabled={syncing} 
            style={{ 
              width: '100%', 
              backgroundColor: syncing ? '#444' : '#282828', 
              color: syncing ? '#aaa' : '#fff', 
              border: '1px solid #444', 
              borderRadius: '6px', 
              padding: '0.75rem', 
              fontWeight: 'bold', 
              cursor: syncing ? 'not-allowed' : 'pointer' 
            }}
          >
            {syncing ? 'Syncing...' : 'Sync Latest Workouts'}
          </button>
        </div>

        <div style={{ flex: 1, overflowY: 'auto', padding: '0 1rem 1rem 1rem' }}>
          <div onClick={() => setSelectedMonth('All')} style={{ padding: '0.85rem 1rem', marginBottom: '0.5rem', borderRadius: '8px', cursor: 'pointer', border: selectedMonth === 'All' ? '1px solid #FC4C02' : '1px solid transparent', backgroundColor: selectedMonth === 'All' ? '#222' : 'transparent' }}>
            <h3 style={{ margin: 0, color: selectedMonth === 'All' ? '#FC4C02' : '#fff', fontSize: '1rem' }}>All Time</h3>
          </div>
          {sidebarMonths.map(month => (
            <div key={month.name} onClick={() => setSelectedMonth(month.name)} style={{ padding: '0.85rem 1rem', marginBottom: '0.5rem', borderRadius: '8px', cursor: 'pointer', backgroundColor: '#1e1e1e', border: selectedMonth === month.name ? '1px solid #FC4C02' : '1px solid #2a2a2a' }}>
              <h3 style={{ margin: '0 0 0.5rem 0', color: selectedMonth === month.name ? '#FC4C02' : '#fff', fontSize: '0.95rem' }}>{month.name}</h3>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.5rem' }}>
                <div><div style={{ fontSize: '0.7rem', color: '#888' }}>DISTANCE</div><div style={{ fontWeight: 'bold', fontSize: '1rem' }}>{month.totalDistance.toFixed(1)} km</div></div>
                <div><div style={{ fontSize: '0.7rem', color: '#888' }}>ACTIVE TIME</div><div style={{ fontWeight: 'bold', fontSize: '1rem' }}>{formatDuration(month.totalTime)}</div></div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* MAIN FEED */}
      <div style={{ flex: 1, padding: '2rem', overflowY: 'auto', height: '100vh' }}>
        
        {/* AUTH / SYNC STATUS BANNER */}
        {authBanner && (
          <div style={{ 
            backgroundColor: authBanner.type === 'success' ? 'rgba(0, 200, 83, 0.15)' : 'rgba(244, 67, 54, 0.15)', 
            border: `1px solid ${authBanner.type === 'success' ? '#00c853' : '#f44336'}`, 
            borderRadius: '8px', 
            padding: '0.85rem 1.25rem', 
            marginBottom: '1.5rem',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            color: authBanner.type === 'success' ? '#69f0ae' : '#ff8a80'
          }}>
            <span>{authBanner.text}</span>
            <button 
              onClick={() => setAuthBanner(null)} 
              style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer', fontSize: '1.2rem', fontWeight: 'bold' }}
            >
              ×
            </button>
          </div>
        )}
        
        {/* BIFURCATION TILES WITH LIVE COUNT BADGES */}
        <div style={{ display: 'flex', gap: '0.75rem', marginBottom: '2rem' }}>
          {[
            { id: 'All', label: 'All', count: displayedWorkouts.length },
            { id: 'Run', label: 'Run / Walk', count: categoryCounts.Run },
            { id: 'Ride', label: 'Ride / Cycle', count: categoryCounts.Ride },
            { id: 'Swim', label: 'Swim', count: categoryCounts.Swim },
            { id: 'Other', label: 'Workout / Other', count: categoryCounts.Other }
          ].map(tab => (
            <button
              key={tab.id}
              onClick={() => setSelectedType(tab.id)}
              style={{
                flex: 1,
                padding: '0.85rem 0.5rem',
                backgroundColor: selectedType === tab.id ? '#FC4C02' : '#1e1e1e',
                color: selectedType === tab.id ? '#fff' : '#aaa',
                border: selectedType === tab.id ? '1px solid #FC4C02' : '1px solid #2a2a2a',
                borderRadius: '8px',
                cursor: 'pointer',
                fontWeight: 'bold',
                fontSize: '0.85rem',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: '0.25rem',
                transition: 'all 0.2s',
                textTransform: 'uppercase',
                letterSpacing: '0.5px'
              }}
            >
              <span>{tab.label}</span>
              <span style={{ fontSize: '0.75rem', opacity: 0.8, backgroundColor: selectedType === tab.id ? 'rgba(255,255,255,0.2)' : '#2a2a2a', padding: '0.1rem 0.4rem', borderRadius: '10px' }}>
                {tab.count}
              </span>
            </button>
          ))}
        </div>

        {loading ? <p>Loading...</p> : finalWorkouts.length === 0 ? <p style={{ color: '#888' }}>No workouts found for this activity filter.</p> : (
          <>
            {/* VOLUME CHART */}
            <div style={{ backgroundColor: '#1e1e1e', borderRadius: '8px', padding: '1.5rem', marginBottom: '2rem', height: '250px', border: '1px solid #2a2a2a' }}>
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={chartData}>
                  <XAxis dataKey="name" stroke="#888" fontSize={12} />
                  <Tooltip contentStyle={{ backgroundColor: '#222', border: 'none' }} cursor={{ fill: '#2a2a2a' }} />
                  <Bar dataKey="Distance" fill="#FC4C02" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
            
            {/* WORKOUT CARDS GRID */}
            <div style={{ display: 'grid', gap: '1.5rem', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))' }}>
              {[...finalWorkouts].reverse().map(run => {
                return (
                  <div key={run.id} onClick={() => setSelectedWorkout(run)} style={{ backgroundColor: '#1e1e1e', borderRadius: '8px', padding: '1.5rem', cursor: 'pointer', position: 'relative', border: '1px solid #2a2a2a' }}>
                    
                    {/* TOP HEADER: Date on Left */}
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem', paddingRight: '4.5rem' }}>
                      <div style={{ color: '#aaa', fontSize: '0.85rem', fontWeight: 'bold' }}>
                        {new Date(run.date).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' })}
                      </div>
                    </div>

                    <button 
                      onClick={(e) => deleteWorkout(e, run.id)} 
                      style={{ position: 'absolute', top: '1.25rem', right: '1.25rem', backgroundColor: 'transparent', color: '#ff4444', border: '1px solid #ff4444', borderRadius: '4px', cursor: 'pointer', padding: '0.25rem 0.55rem', fontSize: '0.75rem' }}
                    >
                      Delete
                    </button>

                    {/* DISTANCE DISPLAY */}
                    <div style={{ fontSize: '2.25rem', fontWeight: 'bold', margin: '0.5rem 0 1rem 0' }}>
                      {run.total_distance} <span style={{ fontSize: '1rem', color: '#aaa' }}>km</span>
                    </div>
                    
                    {/* BOTTOM FOOTER: Metrics on Left, Activity Type Badge on Bottom Right */}
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginTop: '0.5rem' }}>
                      <div style={{ color: '#888', fontSize: '0.85rem' }}>
                        HR: {run.average_heartrate ? Math.round(run.average_heartrate) : '--'} bpm | Time: {formatDuration(run.moving_time)}
                      </div>
                      
                      <div style={{ backgroundColor: '#2a2a2a', padding: '0.25rem 0.65rem', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 'bold', color: '#ccc', border: '1px solid #3a3a3a', whiteSpace: 'nowrap' }}>
                        {run.type || 'Other'}
                      </div>
                    </div>

                  </div>
                )
              })}
            </div>
          </>
        )}
      </div>

      {/* EXPANDED TELEMETRY MODAL OVERLAY */}
      {selectedWorkout && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.95)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '1rem' }}>
          <div style={{ backgroundColor: '#121212', borderRadius: '12px', width: '95vw', maxWidth: '1600px', height: '95vh', padding: '2rem', overflowY: 'auto', border: '1px solid #333' }}>
            
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '1.5rem' }}>
              <div>
                <h2 style={{ margin: 0, color: '#FC4C02' }}>Full Telemetry Breakdown</h2>
                <div style={{ color: '#888', fontSize: '0.85rem', marginTop: '0.25rem' }}>{new Date(selectedWorkout.date).toLocaleString()} | {selectedWorkout.type || 'Other'}</div>
              </div>
              <button onClick={() => setSelectedWorkout(null)} style={{ backgroundColor: '#333', color: '#fff', border: 'none', borderRadius: '4px', padding: '0.5rem 1.5rem', cursor: 'pointer', fontSize: '1rem' }}>Close</button>
            </div>

            {/* SUMMARY STATS */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: '1rem', marginBottom: '2rem' }}>
              <div style={{ backgroundColor: '#1e1e1e', padding: '1.5rem', borderRadius: '8px', border: '1px solid #2a2a2a' }}><div style={{ color: '#888', fontSize: '0.75rem' }}>DISTANCE</div><div style={{ fontSize: '1.5rem', fontWeight: 'bold' }}>{selectedWorkout.total_distance} km</div></div>
              <div style={{ backgroundColor: '#1e1e1e', padding: '1.5rem', borderRadius: '8px', border: '1px solid #2a2a2a' }}><div style={{ color: '#888', fontSize: '0.75rem' }}>TIME</div><div style={{ fontSize: '1.5rem', fontWeight: 'bold' }}>{formatDuration(selectedWorkout.moving_time)}</div></div>
              <div style={{ backgroundColor: '#1e1e1e', padding: '1.5rem', borderRadius: '8px', border: '1px solid #2a2a2a' }}><div style={{ color: '#888', fontSize: '0.75rem' }}>AVG PACE</div><div style={{ fontSize: '1.5rem', fontWeight: 'bold' }}>{calculatePace(selectedWorkout.moving_time, selectedWorkout.total_distance)}</div></div>
              <div style={{ backgroundColor: '#1e1e1e', padding: '1.5rem', borderRadius: '8px', border: '1px solid #2a2a2a' }}><div style={{ color: '#888', fontSize: '0.75rem' }}>AVG HR</div><div style={{ fontSize: '1.5rem', fontWeight: 'bold' }}>{selectedWorkout.average_heartrate ? Math.round(selectedWorkout.average_heartrate) : '--'}</div></div>
            </div>

            {/* CHARTS GRID */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: '2rem', marginBottom: '2rem' }}>
              
              {/* HR CHART WITH GRADIENT & REF LINE */}
              <div style={{ height: '350px', backgroundColor: '#1e1e1e', borderRadius: '8px', padding: '1.5rem', border: '1px solid #2a2a2a' }}>
                <h4 style={{ margin: '0 0 1rem 0', color: '#aaa' }}>Heart Rate Stream & Zones</h4>
                {selectedWorkout.heartrate_stream ? (
                  <ResponsiveContainer width="100%" height="85%">
                    <LineChart data={getStreamData(selectedWorkout)}>
                      <defs>
                        <linearGradient id="hrGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#ff4444" stopOpacity={1}/>
                          <stop offset="40%" stopColor="#ffaa00" stopOpacity={1}/>
                          <stop offset="80%" stopColor="#00cc44" stopOpacity={1}/>
                        </linearGradient>
                      </defs>
                      <XAxis dataKey="time" stroke="#888" fontSize={12} minTickGap={30} />
                      <YAxis domain={['dataMin - 5', 'dataMax + 5']} stroke="#888" fontSize={12} />
                      <Tooltip contentStyle={{ backgroundColor: '#222', border: 'none' }} />
                      <ReferenceLine y={selectedWorkout.average_heartrate} stroke="#fff" strokeDasharray="3 3" label={{ position: 'insideTopLeft', value: 'Avg HR', fill: '#fff', fontSize: 12 }} />
                      <Line type="monotone" dataKey="hr" stroke="url(#hrGradient)" dot={false} strokeWidth={2} />
                    </LineChart>
                  </ResponsiveContainer>
                ) : <p style={{ color: '#666', textAlign: 'center', marginTop: '3rem' }}>No HR stream.</p>}
              </div>

              {/* PACE & ELEVATION COMBINED CHART */}
              <div style={{ height: '350px', backgroundColor: '#1e1e1e', borderRadius: '8px', padding: '1.5rem', border: '1px solid #2a2a2a' }}>
                <h4 style={{ margin: '0 0 1rem 0', color: '#aaa' }}>Pace & Elevation Stream</h4>
                {selectedWorkout.pace_stream ? (
                  <ResponsiveContainer width="100%" height="85%">
                    <LineChart data={getStreamData(selectedWorkout)}>
                      <XAxis dataKey="time" stroke="#888" fontSize={12} minTickGap={30} />
                      <YAxis yAxisId="left" domain={['dataMin', 'dataMax']} reversed={true} stroke="#4488ff" fontSize={12} />
                      <YAxis yAxisId="right" orientation="right" domain={['dataMin - 10', 'dataMax + 10']} stroke="#888" fontSize={12} />
                      <Tooltip contentStyle={{ backgroundColor: '#222', border: 'none' }} />
                      <Line yAxisId="left" type="monotone" dataKey="pace" stroke="#4488ff" dot={false} strokeWidth={2} name="Pace (min/km decimal)" />
                      <Line yAxisId="right" type="monotone" dataKey="elevation" stroke="#888" dot={false} strokeWidth={2} name="Elevation (m)" />
                    </LineChart>
                  </ResponsiveContainer>
                ) : <p style={{ color: '#666', textAlign: 'center', marginTop: '3rem' }}>No Pace/Elevation streams.</p>}
              </div>

            </div>

            {/* LAPS TABLE */}
            <div style={{ backgroundColor: '#1e1e1e', borderRadius: '8px', padding: '1.5rem', border: '1px solid #2a2a2a' }}>
              <h4 style={{ margin: '0 0 1rem 0', color: '#aaa' }}>Lap Splits</h4>
              {getLaps(selectedWorkout).length > 0 ? (
                <div style={{ width: '100%', overflowX: 'auto' }}>
                  <table style={{ width: '100%', textAlign: 'left', borderCollapse: 'collapse' }}>
                    <thead>
                      <tr style={{ borderBottom: '1px solid #333', color: '#888', fontSize: '0.85rem' }}>
                        <th style={{ padding: '0.75rem' }}>Lap</th>
                        <th style={{ padding: '0.75rem' }}>Distance</th>
                        <th style={{ padding: '0.75rem' }}>Time</th>
                        <th style={{ padding: '0.75rem' }}>Pace</th>
                        <th style={{ padding: '0.75rem' }}>Avg HR</th>
                      </tr>
                    </thead>
                    <tbody>
                      {getLaps(selectedWorkout).map((lap, index) => (
                        <tr key={index} style={{ borderBottom: '1px solid #2a2a2a' }}>
                          <td style={{ padding: '0.75rem' }}>{lap.lap_index || index + 1}</td>
                          <td style={{ padding: '0.75rem' }}>{(lap.distance / 1000).toFixed(2)} km</td>
                          <td style={{ padding: '0.75rem' }}>{formatDuration(lap.moving_time)}</td>
                          <td style={{ padding: '0.75rem' }}>{calculatePace(lap.moving_time, lap.distance / 1000)}</td>
                          <td style={{ padding: '0.75rem' }}>{lap.average_heartrate ? Math.round(lap.average_heartrate) : '--'} bpm</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : <p style={{ color: '#666' }}>No lap data saved for this activity.</p>}
            </div>

          </div>
        </div>
      )}
    </div>
  )
}

export default App