-- ============================================
-- Live Events Table for Traffinity App
-- ============================================
-- This script creates the live_events table for user-submitted events
-- Run this in your Supabase SQL Editor

-- Enable UUID extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing table and related objects if you want a fresh start (CAREFUL!)
-- Uncomment the following lines only if you want to recreate the table
-- DROP TABLE IF EXISTS live_events CASCADE;

-- Create live_events table for user-submitted events
CREATE TABLE IF NOT EXISTS live_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  location TEXT NOT NULL,
  city TEXT NOT NULL,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  end_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '3 hours'),
  event_type TEXT NOT NULL CHECK (event_type IN ('concert', 'hackathon', 'festival', 'conference', 'expo', 'sports', 'other')),
  estimated_attendance INTEGER DEFAULT 200 CHECK (estimated_attendance >= 0),
  traffic_impact TEXT NOT NULL DEFAULT 'medium' CHECK (traffic_impact IN ('low', 'medium', 'high')),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  submitted_by UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Add constraints to ensure valid data
  CONSTRAINT valid_coordinates CHECK (
    (latitude IS NULL AND longitude IS NULL) OR 
    (latitude IS NOT NULL AND longitude IS NOT NULL AND 
     latitude BETWEEN -90 AND 90 AND 
     longitude BETWEEN -180 AND 180)
  ),
  CONSTRAINT valid_time_range CHECK (end_time > start_time)
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_live_events_city ON live_events(city);
CREATE INDEX IF NOT EXISTS idx_live_events_start_time ON live_events(start_time);
CREATE INDEX IF NOT EXISTS idx_live_events_end_time ON live_events(end_time);
CREATE INDEX IF NOT EXISTS idx_live_events_city_time ON live_events(city, start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_live_events_coordinates ON live_events(latitude, longitude) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_live_events_type ON live_events(event_type);
CREATE INDEX IF NOT EXISTS idx_live_events_submitted_by ON live_events(submitted_by);

-- Add comment to table
COMMENT ON TABLE live_events IS 'User-submitted live events for traffic and event tracking';

-- Enable Row Level Security
ALTER TABLE live_events ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Anyone can view live events" ON live_events;
DROP POLICY IF EXISTS "Authenticated users can create events" ON live_events;
DROP POLICY IF EXISTS "Users can update own events" ON live_events;
DROP POLICY IF EXISTS "Users can delete own events" ON live_events;

-- Create policies
-- 1. Anyone (including anonymous users) can read live events
CREATE POLICY "Anyone can view live events"
  ON live_events
  FOR SELECT
  USING (true);

-- 2. Authenticated users can insert events (and must set submitted_by to their own ID)
CREATE POLICY "Authenticated users can create events"
  ON live_events
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = submitted_by);

-- 3. Users can update their own events only
CREATE POLICY "Users can update own events"
  ON live_events
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = submitted_by)
  WITH CHECK (auth.uid() = submitted_by);

-- 4. Users can delete their own events only
CREATE POLICY "Users can delete own events"
  ON live_events
  FOR DELETE
  TO authenticated
  USING (auth.uid() = submitted_by);

-- Create function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_live_events_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_update_live_events_updated_at ON live_events;

-- Create trigger for auto-updating updated_at
CREATE TRIGGER trigger_update_live_events_updated_at
  BEFORE UPDATE ON live_events
  FOR EACH ROW
  EXECUTE FUNCTION update_live_events_updated_at();

-- Create function to auto-delete expired events
-- Events are deleted 7 days after they end
CREATE OR REPLACE FUNCTION delete_expired_events()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM live_events
  WHERE end_time < NOW() - INTERVAL '7 days';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comment to cleanup function
COMMENT ON FUNCTION delete_expired_events() IS 'Deletes events that ended more than 7 days ago. Returns count of deleted events.';

-- Grant permissions
GRANT SELECT ON live_events TO anon;
GRANT ALL ON live_events TO authenticated;
GRANT EXECUTE ON FUNCTION delete_expired_events() TO authenticated;

-- ============================================
-- Setup Complete!
-- ============================================
-- 
-- Optional: Set up a scheduled cleanup (requires pg_cron extension)
-- To enable automatic cleanup, run this in your Supabase dashboard:
-- 
-- 1. Go to Database > Extensions
-- 2. Enable "pg_cron" extension
-- 3. Then run this SQL:
--
-- SELECT cron.schedule(
--   'delete-expired-events',
--   '0 2 * * *',  -- Run at 2 AM daily
--   'SELECT delete_expired_events();'
-- );
--
-- ============================================

-- Test queries (optional - comment out before running in production)
-- SELECT COUNT(*) FROM live_events;
-- SELECT * FROM live_events ORDER BY created_at DESC LIMIT 10;
-- SELECT delete_expired_events(); -- Manual cleanup test

