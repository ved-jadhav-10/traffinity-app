-- ============================================
-- ParkHub Manager - Database Schema Migration
-- Traffinity App - Parking Management System
-- ============================================

-- ============================================
-- CREATE BASE TABLES (if they don't exist)
-- ============================================

-- Create parking_layouts table
CREATE TABLE IF NOT EXISTS public.parking_layouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  location TEXT,
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create parking_slots table
CREATE TABLE IF NOT EXISTS public.parking_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  layout_id UUID REFERENCES public.parking_layouts(id) ON DELETE CASCADE,
  slot_label TEXT NOT NULL,
  status TEXT DEFAULT 'available',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create vehicle_types table
CREATE TABLE IF NOT EXISTS public.vehicle_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parking_layout_id UUID REFERENCES public.parking_layouts(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  price_per_hour NUMERIC(10,2) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create bookings table
CREATE TABLE IF NOT EXISTS public.bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_id UUID REFERENCES public.parking_slots(id) ON DELETE CASCADE,
  user_name TEXT,
  vehicle_number TEXT,
  vehicle_type TEXT,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- ALTER TABLES (add new columns)
-- ============================================

-- 1. Add coordinates to parking_layouts table
-- This allows map display of parking locations
ALTER TABLE public.parking_layouts 
  ADD COLUMN IF NOT EXISTS latitude FLOAT8,
  ADD COLUMN IF NOT EXISTS longitude FLOAT8;

COMMENT ON COLUMN public.parking_layouts.latitude IS 'Parking location latitude for map display';
COMMENT ON COLUMN public.parking_layouts.longitude IS 'Parking location longitude for map display';

-- 2. Add missing fields to bookings table
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS booking_start_time TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS booking_end_time TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS vehicle_type_id UUID REFERENCES vehicle_types(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS duration INTEGER DEFAULT 1;

COMMENT ON COLUMN public.bookings.user_id IS 'Link to authenticated user who made the booking';
COMMENT ON COLUMN public.bookings.booking_start_time IS 'When the parking reservation starts';
COMMENT ON COLUMN public.bookings.booking_end_time IS 'When the parking reservation ends';
COMMENT ON COLUMN public.bookings.vehicle_type_id IS 'Link to vehicle type for pricing';
COMMENT ON COLUMN public.bookings.duration IS 'Booking duration in hours (1-24)';

-- 3. Add indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON public.bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_slot_id ON public.bookings(slot_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings(status);
CREATE INDEX IF NOT EXISTS idx_parking_slots_layout_id ON public.parking_slots(layout_id);
CREATE INDEX IF NOT EXISTS idx_parking_slots_status ON public.parking_slots(status);
CREATE INDEX IF NOT EXISTS idx_parking_layouts_coordinates ON public.parking_layouts(latitude, longitude);

-- 4. Update existing slot status values to match new constraint
-- Map any existing status values to the new valid ones
UPDATE public.parking_slots 
SET status = CASE 
  WHEN LOWER(status) IN ('available', 'free', 'open') THEN 'available'
  WHEN LOWER(status) IN ('reserved', 'pending') THEN 'reserved'
  WHEN LOWER(status) IN ('occupied', 'booked', 'taken') THEN 'occupied'
  WHEN LOWER(status) IN ('maintenance', 'closed', 'unavailable') THEN 'maintenance'
  ELSE 'available' -- Default to available if unknown status
END
WHERE status NOT IN ('available', 'reserved', 'occupied', 'maintenance');

-- 5. Add check constraint for slot status
ALTER TABLE public.parking_slots 
  DROP CONSTRAINT IF EXISTS parking_slots_status_check;
  
ALTER TABLE public.parking_slots 
  ADD CONSTRAINT parking_slots_status_check 
  CHECK (status IN ('available', 'reserved', 'occupied', 'maintenance'));

COMMENT ON CONSTRAINT parking_slots_status_check ON public.parking_slots IS 
  'available: Can be booked | reserved: Booking pending approval | occupied: Approved booking | maintenance: Temporarily unavailable';

-- 6. Update existing booking status values to match new constraint
-- Map any existing status values to the new valid ones
UPDATE public.bookings 
SET status = CASE 
  WHEN LOWER(status) IN ('pending', 'waiting') THEN 'pending'
  WHEN LOWER(status) IN ('approved', 'confirmed', 'active') THEN 'approved'
  WHEN LOWER(status) IN ('rejected', 'denied') THEN 'rejected'
  WHEN LOWER(status) IN ('cancelled', 'canceled') THEN 'cancelled'
  ELSE 'pending' -- Default to pending if unknown status
END
WHERE status NOT IN ('pending', 'approved', 'rejected', 'cancelled');

-- 7. Add check constraint for booking status
ALTER TABLE public.bookings 
  DROP CONSTRAINT IF EXISTS bookings_status_check;
  
ALTER TABLE public.bookings 
  ADD CONSTRAINT bookings_status_check 
  CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'));

COMMENT ON CONSTRAINT bookings_status_check ON public.bookings IS 
  'pending: Waiting admin approval | approved: Confirmed by admin | rejected: Denied by admin | cancelled: User cancelled';

-- 8. Add check constraint for duration (1-24 hours)
ALTER TABLE public.bookings
  DROP CONSTRAINT IF EXISTS bookings_duration_check;

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_duration_check
  CHECK (duration >= 1 AND duration <= 24);

COMMENT ON CONSTRAINT bookings_duration_check ON public.bookings IS 'Booking duration must be between 1 and 24 hours';

-- ============================================
-- Enable Row Level Security (RLS)
-- ============================================

-- Enable RLS on all tables
ALTER TABLE public.parking_layouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parking_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- ============================================
-- RLS Policies for parking_layouts
-- ============================================

-- Allow all authenticated users to view parking layouts
CREATE POLICY "Anyone can view parking layouts"
  ON public.parking_layouts
  FOR SELECT
  TO authenticated
  USING (true);

-- Only owners can manage their parking layouts
CREATE POLICY "Owners can manage their parking layouts"
  ON public.parking_layouts
  FOR ALL
  TO authenticated
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

-- ============================================
-- RLS Policies for parking_slots
-- ============================================

-- Allow all authenticated users to view parking slots
CREATE POLICY "Anyone can view parking slots"
  ON public.parking_slots
  FOR SELECT
  TO authenticated
  USING (true);

-- Only owners can manage parking slots
CREATE POLICY "Owners can manage parking slots"
  ON public.parking_slots
  FOR ALL
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT owner_id FROM public.parking_layouts WHERE id = layout_id
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT owner_id FROM public.parking_layouts WHERE id = layout_id
    )
  );

-- ============================================
-- RLS Policies for vehicle_types
-- ============================================

-- Allow all authenticated users to view vehicle types
CREATE POLICY "Anyone can view vehicle types"
  ON public.vehicle_types
  FOR SELECT
  TO authenticated
  USING (true);

-- Only owners can manage vehicle types
CREATE POLICY "Owners can manage vehicle types"
  ON public.vehicle_types
  FOR ALL
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT owner_id FROM public.parking_layouts WHERE id = parking_layout_id
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT owner_id FROM public.parking_layouts WHERE id = parking_layout_id
    )
  );

-- ============================================
-- RLS Policies for bookings
-- ============================================

-- Users can view their own bookings
CREATE POLICY "Users can view their own bookings"
  ON public.bookings
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can create bookings
CREATE POLICY "Users can create bookings"
  ON public.bookings
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Owners can view all bookings for their parking layouts
CREATE POLICY "Owners can view bookings for their parking"
  ON public.bookings
  FOR SELECT
  TO authenticated
  USING (
    slot_id IN (
      SELECT ps.id FROM public.parking_slots ps
      JOIN public.parking_layouts pl ON ps.layout_id = pl.id
      WHERE pl.owner_id = auth.uid()
    )
  );

-- Owners can update booking status (approve/reject)
CREATE POLICY "Owners can update booking status"
  ON public.bookings
  FOR UPDATE
  TO authenticated
  USING (
    slot_id IN (
      SELECT ps.id FROM public.parking_slots ps
      JOIN public.parking_layouts pl ON ps.layout_id = pl.id
      WHERE pl.owner_id = auth.uid()
    )
  );

-- Users can delete their own bookings
CREATE POLICY "Users can delete their own bookings"
  ON public.bookings
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ============================================
-- Functions for automatic status updates
-- ============================================

-- Function to update slot status when booking is created
CREATE OR REPLACE FUNCTION public.update_slot_status_on_booking()
RETURNS TRIGGER AS $$
BEGIN
  -- When booking is created with pending status, set slot to reserved
  IF (TG_OP = 'INSERT' AND NEW.status = 'pending') THEN
    UPDATE public.parking_slots
    SET status = 'reserved'
    WHERE id = NEW.slot_id;
  END IF;

  -- When booking is approved, set slot to occupied
  IF (TG_OP = 'UPDATE' AND NEW.status = 'approved' AND OLD.status = 'pending') THEN
    UPDATE public.parking_slots
    SET status = 'occupied'
    WHERE id = NEW.slot_id;
  END IF;

  -- When booking is rejected or cancelled, set slot to available
  IF (TG_OP = 'UPDATE' AND NEW.status IN ('rejected', 'cancelled') AND OLD.status IN ('pending', 'approved')) THEN
    UPDATE public.parking_slots
    SET status = 'available'
    WHERE id = NEW.slot_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for booking status changes
DROP TRIGGER IF EXISTS trigger_update_slot_status ON public.bookings;
CREATE TRIGGER trigger_update_slot_status
  AFTER INSERT OR UPDATE ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.update_slot_status_on_booking();

-- Function to automatically free expired bookings
CREATE OR REPLACE FUNCTION public.free_expired_parking_slots()
RETURNS void AS $$
BEGIN
  -- Find all approved bookings that have expired
  UPDATE public.parking_slots ps
  SET status = 'available'
  FROM public.bookings b
  WHERE ps.id = b.slot_id
    AND b.status = 'approved'
    AND b.booking_end_time < NOW()
    AND ps.status = 'occupied';
    
  -- Optional: Update booking status to indicate it's completed
  -- UPDATE public.bookings
  -- SET status = 'completed'
  -- WHERE status = 'approved'
  --   AND booking_end_time < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.free_expired_parking_slots() IS 
  'Call this periodically (e.g., every 5 minutes) to automatically free expired parking slots';

-- ============================================
-- Helpful Views for Admin Dashboard
-- ============================================

-- View for available slots per parking layout
CREATE OR REPLACE VIEW public.parking_availability AS
SELECT 
  pl.id AS layout_id,
  pl.name AS parking_name,
  pl.location,
  pl.latitude,
  pl.longitude,
  COUNT(ps.id) AS total_slots,
  COUNT(ps.id) FILTER (WHERE ps.status = 'available') AS available_slots,
  COUNT(ps.id) FILTER (WHERE ps.status = 'reserved') AS reserved_slots,
  COUNT(ps.id) FILTER (WHERE ps.status = 'occupied') AS occupied_slots,
  COUNT(ps.id) FILTER (WHERE ps.status = 'maintenance') AS maintenance_slots
FROM public.parking_layouts pl
LEFT JOIN public.parking_slots ps ON pl.id = ps.layout_id
GROUP BY pl.id, pl.name, pl.location, pl.latitude, pl.longitude;

COMMENT ON VIEW public.parking_availability IS 'Shows slot availability summary for each parking layout';

-- ============================================
-- Migration Complete!
-- ============================================

-- Next steps for admin:
-- 1. Add latitude and longitude values for existing parking_layouts
-- 2. Enable Realtime on these tables in Supabase Dashboard
-- 3. Deploy the Edge Function for email notifications
-- 4. Set up a cron job to call free_expired_parking_slots() every 5 minutes

SELECT 'Migration completed successfully! Remember to:
1. Update parking_layouts with latitude/longitude coordinates
2. Enable Realtime in Supabase Dashboard
3. Deploy email notification Edge Function
4. Set up cron job for expired bookings' AS reminder;
