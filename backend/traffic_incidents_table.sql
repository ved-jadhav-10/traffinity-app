-- Enable required extensions for geo-spatial queries
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;

-- Create traffic_incidents table
CREATE TABLE IF NOT EXISTS traffic_incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    incident_type TEXT NOT NULL CHECK (incident_type IN ('accident', 'roadwork', 'event')),
    severity TEXT NOT NULL CHECK (severity IN ('Minor', 'Moderate', 'Severe', 'Critical')),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    start_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    duration_minutes INTEGER NOT NULL, -- 5, 15, 30, 60, 240, or -1 for unknown
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for location queries (for efficient 20km radius search)
CREATE INDEX IF NOT EXISTS idx_traffic_incidents_location ON traffic_incidents USING GIST (
    ll_to_earth(latitude, longitude)
);

-- Create index for time-based queries (for auto-expiration)
CREATE INDEX IF NOT EXISTS idx_traffic_incidents_start_time ON traffic_incidents(start_time);

-- Create index for user queries
CREATE INDEX IF NOT EXISTS idx_traffic_incidents_user_id ON traffic_incidents(user_id);

-- Enable Row Level Security
ALTER TABLE traffic_incidents ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read incidents (public visibility)
CREATE POLICY "Anyone can view incidents"
    ON traffic_incidents FOR SELECT
    USING (true);

-- Policy: Authenticated users can insert incidents
CREATE POLICY "Authenticated users can report incidents"
    ON traffic_incidents FOR INSERT
    WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = user_id);

-- Policy: Users can update their own incidents
CREATE POLICY "Users can update own incidents"
    ON traffic_incidents FOR UPDATE
    USING (auth.uid() = user_id);

-- Policy: Users can delete their own incidents
CREATE POLICY "Users can delete own incidents"
    ON traffic_incidents FOR DELETE
    USING (auth.uid() = user_id);

-- Function to auto-expire incidents after 12 hours
CREATE OR REPLACE FUNCTION delete_expired_incidents()
RETURNS void AS $$
BEGIN
    DELETE FROM traffic_incidents
    WHERE start_time < NOW() - INTERVAL '12 hours';
END;
$$ LANGUAGE plpgsql;

-- Create a scheduled job to run the cleanup function (if pg_cron is available)
-- Note: This requires pg_cron extension. If not available, you can call this from your app
-- SELECT cron.schedule('delete-expired-incidents', '*/30 * * * *', 'SELECT delete_expired_incidents()');

-- Function to get incidents within radius (in meters)
CREATE OR REPLACE FUNCTION get_incidents_within_radius(
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    radius_meters INTEGER DEFAULT 20000
)
RETURNS SETOF traffic_incidents AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM traffic_incidents
    WHERE earth_distance(
        ll_to_earth(lat, lng),
        ll_to_earth(latitude, longitude)
    ) <= radius_meters
    AND start_time >= NOW() - INTERVAL '12 hours'
    ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON traffic_incidents TO authenticated;
GRANT SELECT ON traffic_incidents TO anon;
