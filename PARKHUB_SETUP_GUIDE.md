# 🅿️ ParkHub Manager - Complete Setup Guide

This guide walks you through setting up the complete ParkHub Manager feature in your Traffinity app.

## 📋 Table of Contents
1. [Merge Parking Database (If Separate)](#0-merge-parking-database-if-separate)
2. [Database Setup](#1-database-setup)
3. [Edge Function Deployment](#2-edge-function-deployment)
4. [Supabase Configuration](#3-supabase-configuration)
5. [Testing Checklist](#4-testing-checklist)
6. [Admin Workflow](#5-admin-workflow)

---

## 0. Merge Parking Database (If Separate)

**⚠️ IMPORTANT: If you currently have parking tables in a separate Supabase project, follow these steps first to merge everything into your main Traffinity project (`pmsemyznsxeigmfhzyfg`).**

### Why Merge?
- ✅ Single authentication system
- ✅ Proper foreign key constraints with `auth.users`
- ✅ RLS policies work with `auth.uid()`
- ✅ Simpler codebase (one API key)
- ✅ Lower costs (one project instead of two)
- ✅ Better data integrity

### Step 0.1: Export Existing Data (If Any)

**Only do this if you have test data in your separate parking project:**

1. Go to your separate parking Supabase project dashboard
2. Navigate to **Table Editor**
3. For each table (`parking_layouts`, `parking_slots`, `bookings`, `vehicle_types`):
   - Click on the table
   - Click **Export** → Choose **CSV**
   - Save the files locally

### Step 0.2: Update Flutter App Configuration

**No changes needed!** Your app is already configured to use the main Traffinity project:

```dart
// lib/config/supabase_config.dart (already correct)
static const String supabaseUrl = 'https://pmsemyznsxeigmfhzyfg.supabase.co';
```

The `ParkingService` in `lib/services/parking_service.dart` uses the same Supabase client, so it will automatically work with the merged database.

### Step 0.3: Proceed to Database Setup

Now continue with **Step 1.1 below** to run the migration in your **main Traffinity project** (`pmsemyznsxeigmfhzyfg`). This will create all parking tables in the same database as your auth system.

### Step 0.4: Import Old Data (If You Exported Any)

**After running the migration in Step 1.1:**

1. Go to your main Traffinity project → **Table Editor**
2. Select the table you want to import into
3. Click **Insert** → **Import data from CSV**
4. Upload the CSV file you exported earlier
5. Map columns correctly and import

### Step 0.5: Delete Old Project (Optional)

Once you've confirmed everything works in the merged setup:
1. Go to your old parking project dashboard
2. Navigate to **Settings** → **General**
3. Scroll down and click **Delete Project**
4. This will stop any charges from the unused project

---

## 1. Database Setup

### Step 1.1: Run Migration SQL in Main Traffinity Project

**🎯 Run this in your MAIN Traffinity project (`pmsemyznsxeigmfhzyfg`), NOT a separate parking project:**

1. Open your **main Traffinity Supabase Dashboard**: https://supabase.com/dashboard/project/pmsemyznsxeigmfhzyfg
2. Navigate to **SQL Editor**
3. Open the file `database/parking_schema_migration.sql` from this project
4. Copy the entire contents and paste into the SQL Editor
5. Click **Run** to execute the migration
6. Verify success - you should see confirmation messages for each operation

**What this migration does:**
- Adds `latitude` and `longitude` columns to `parking_layouts` table
- Adds booking fields to `bookings` table with **foreign key to `auth.users`** (ensures data integrity)
- Links `user_id` to authenticated users (bookings auto-delete when user is deleted)
- Creates `parking_availability` view for real-time slot counts
- Adds trigger to automatically update slot status when bookings are created
- Creates function to expire old bookings (`free_expired_parking_slots()`)
- Sets up Row Level Security (RLS) policies using `auth.uid()` (works because everything is in one database)

### Step 1.2: Populate Parking Data

After migration, you need to add parking locations. The tables will be empty after the initial migration.

**First, insert parking layouts:**

```sql
-- Insert sample parking locations with GPS coordinates
-- Replace with your actual parking locations
INSERT INTO parking_layouts (name, location, latitude, longitude, owner_id)
VALUES 
  ('Connaught Place Parking', 'New Delhi', 28.6139, 77.2090, auth.uid()),
  ('Noida City Center Parking', 'Noida', 28.5355, 77.3910, auth.uid());

-- Verify parking layouts created
SELECT id, name, location, latitude, longitude FROM parking_layouts;
```

**Then, add parking slots for each layout:**

```sql
-- Get the layout IDs first
SELECT id, name FROM parking_layouts;

-- Add slots for first parking (replace <layout-id> with actual ID from above query)
INSERT INTO parking_slots (layout_id, slot_label, status)
SELECT 
  '<layout-id-1>'::uuid,
  'A' || generate_series(1, 10),
  'available';

-- Add vehicle types with pricing (replace <layout-id> with actual ID)
INSERT INTO vehicle_types (parking_layout_id, name, price_per_hour)
VALUES 
  ('<layout-id-1>'::uuid, 'Car', 50.00),
  ('<layout-id-1>'::uuid, 'Bike', 20.00),
  ('<layout-id-1>'::uuid, 'SUV', 80.00);
```

**Pro tip:** You can also add data via Supabase Dashboard → Table Editor → Insert row.

### Step 1.3: Enable Realtime

1. Go to **Database** → **Publications** in your main Traffinity Supabase Dashboard (or run SQL below)
2. Enable realtime for these tables:
   - ✅ `parking_slots`
   - ✅ `bookings`
   - ✅ `parking_layouts`

**Alternative: Enable via SQL**
```sql
-- Enable realtime for parking tables
ALTER PUBLICATION supabase_realtime ADD TABLE parking_slots;
ALTER PUBLICATION supabase_realtime ADD TABLE bookings;
ALTER PUBLICATION supabase_realtime ADD TABLE parking_layouts;

-- Verify tables are enabled
SELECT schemaname, tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime';
```

### Step 1.4: Verify Integration with Auth

Check that the foreign key constraint is working:

```sql
-- This should show the foreign key constraint on user_id
SELECT
  tc.table_name, 
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'bookings' 
  AND tc.constraint_type = 'FOREIGN KEY'
  AND kcu.column_name = 'user_id';

-- Should return: bookings | user_id | users | id
```

This confirms `bookings.user_id` is properly linked to `auth.users.id` in the same database! ✅

---

## 2. Edge Function Deployment

### Step 2.1: Install Supabase CLI

If you haven't already:

```powershell
# Using npm
npm install -g supabase

# Or using Scoop (Windows)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

### Step 2.2: Login to Supabase

```powershell
supabase login
```

### Step 2.3: Link Project

```powershell
# Link to your main Traffinity project
supabase link --project-ref pmsemyznsxeigmfhzyfg
```

### Step 2.4: Deploy Edge Function

```powershell
cd c:\Users\Test\OneDrive\Desktop\Coding\flutter_projects\traffinity\traffinity-app

# Deploy the send-booking-email function
supabase functions deploy send-booking-email
```

### Step 2.5: Configure Email Service (Optional)

The Edge Function template includes a TODO for email integration. You can:

**Option A: Use Resend (Recommended)**
```powershell
# Set Resend API key as secret
supabase secrets set RESEND_API_KEY=<your-resend-api-key>
```

Then uncomment the Resend integration code in `supabase/functions/send-booking-email/index.ts` (lines 190-203).

**Option B: Use SendGrid, AWS SES, or other providers**
- Modify the email sending section in `index.ts`
- Set appropriate environment variables

**Option C: Use Supabase Native Email (Limited)**
- No additional setup needed, but has rate limits
- Good for testing, not recommended for production

---

## 3. Supabase Configuration

### Step 3.1: Create Database Webhook for Email Trigger

1. Go to **Database** → **Webhooks** in your main Traffinity Supabase Dashboard
2. Click **Create a new hook**
3. Configure webhook:
   - **Name**: `send-booking-approval-email`
   - **Table**: `bookings`
   - **Events**: ☑️ Update
   - **Type**: `HTTP Request`
   - **Method**: `POST`
   - **URL**: `https://pmsemyznsxeigmfhzyfg.supabase.co/functions/v1/send-booking-email`
   - **HTTP Headers**:
     ```
     Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBtc2VteXpuc3hlaWdtZmh6eWZnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE5MjgyODcsImV4cCI6MjA3NzUwNDI4N30.xkvQ8w_Lq9eAAsmpu9TETNB8CkAkOnceIdv27-GdCek
     Content-Type: application/json
     ```
4. Click **Create webhook**

### Step 3.2: Set up Scheduled Job for Expired Bookings

1. Go to **Database** → **Cron jobs** (via pg_cron extension)
2. Run this SQL to create a scheduled job that runs every hour:

```sql
-- Enable pg_cron extension if not enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule job to free expired parking slots every hour
SELECT cron.schedule(
  'free-expired-slots',
  '0 * * * *', -- Run at minute 0 of every hour
  $$SELECT free_expired_parking_slots();$$
);

-- Verify the cron job was created
SELECT * FROM cron.job;
```

---

## 4. Testing Checklist

### ✅ Database Tests

- [ ] Verify all tables exist with new columns
  ```sql
  SELECT column_name, data_type 
  FROM information_schema.columns 
  WHERE table_name IN ('parking_layouts', 'bookings', 'parking_slots');
  ```

- [ ] Check parking_layouts have coordinates
  ```sql
  SELECT name, latitude, longitude FROM parking_layouts;
  ```

- [ ] Test parking_availability view
  ```sql
  SELECT * FROM parking_availability;
  ```

### ✅ Flutter App Tests

1. **Map Screen**
   - [ ] Open Territory tab → Tap "ParkHub Manager"
   - [ ] Verify map loads with TomTom tiles
   - [ ] Check parking markers appear at correct GPS locations
   - [ ] Verify availability badges show correct counts (green) or X (red)
   - [ ] Tap marker → Bottom sheet shows parking details

2. **Layout Screen**
   - [ ] Tap "View Parking" on bottom sheet
   - [ ] Verify 4-column grid displays all slots
   - [ ] Check color coding: Green (available), Yellow (reserved), Red (occupied)
   - [ ] Verify legend and availability count at top
   - [ ] Tap available slot → Opens booking form

3. **Booking Form**
   - [ ] Verify vehicle number field accepts input
   - [ ] Check vehicle type dropdown shows all types with prices
   - [ ] Date picker allows today + next 7 days only
   - [ ] Time picker works correctly
   - [ ] Duration dropdown shows 1-24 hours
   - [ ] Total price calculates correctly (price_per_hour × duration)
   - [ ] Submit booking → Returns to layout with success message
   - [ ] Verify slot status changes to "Reserved" (yellow)

4. **My Bookings Screen**
   - [ ] Open from navigation or Territory tab
   - [ ] Check Active tab shows approved bookings
   - [ ] Check Pending tab shows bookings awaiting approval
   - [ ] Check Past tab shows expired bookings
   - [ ] Verify status badges are color-coded correctly
   - [ ] Check "Time Until" displays for upcoming bookings

### ✅ Real-time Tests

- [ ] Open layout screen on 2 devices
- [ ] Book slot on device 1
- [ ] Verify device 2 sees slot turn yellow immediately
- [ ] Approve booking from admin
- [ ] Verify both devices show slot turn red

### ✅ Email Tests

- [ ] Create a test booking
- [ ] Approve it from admin panel
- [ ] Check user receives confirmation email
- [ ] Verify email contains correct parking details, spot number, date/time

### ✅ Edge Cases

- [ ] Try booking already reserved slot → Should show error
- [ ] Try booking for past date → Should be blocked by date picker
- [ ] Try booking for more than 7 days ahead → Should be blocked
- [ ] Wait for booking to expire → Slot should auto-free
- [ ] Test concurrent bookings → Only first should succeed

---

## 5. Admin Workflow

### Approving Bookings

**Option A: Via Supabase Dashboard**
1. Go to **Table Editor** → `bookings`
2. Find booking with `status = 'pending'`
3. Click to edit → Change `status` to `'approved'`
4. Save → Email automatically sent, slot status updates to 'occupied'

**Option B: Via Admin Website/Panel** (Recommended)
Create a simple admin interface to:
- List all pending bookings
- Show parking name, slot, user details, time
- One-click approve/reject buttons
- Update booking status via Supabase client

Example admin query:
```sql
-- Get all pending bookings with details
SELECT 
  b.id,
  b.user_name,
  b.vehicle_number,
  b.vehicle_type,
  b.booking_start_time,
  b.booking_end_time,
  b.duration,
  s.slot_label,
  pl.name as parking_name
FROM bookings b
JOIN parking_slots s ON b.slot_id = s.id
JOIN parking_layouts pl ON s.parking_layout_id = pl.id
WHERE b.status = 'pending'
ORDER BY b.created_at DESC;
```

### Monitoring

- Check `parking_availability` view for real-time counts
- Monitor booking history in `bookings` table
- Review Edge Function logs in Supabase Dashboard → Functions → Logs

---

## 🚀 Quick Start Summary

1. ✅ **(If applicable)** Export data from separate parking project
2. ✅ Run `parking_schema_migration.sql` in **main Traffinity project** SQL Editor (pmsemyznsxeigmfhzyfg)
3. ✅ Verify foreign key constraint on `bookings.user_id` → `auth.users.id`
4. ✅ Add latitude/longitude to parking_layouts
5. ✅ Enable Realtime on `parking_slots` and `bookings` tables
6. ✅ Deploy Edge Function: `supabase functions deploy send-booking-email`
7. ✅ Create database webhook for booking approval emails
8. ✅ Schedule cron job for expired bookings cleanup
9. ✅ (Optional) Configure email service (Resend/SendGrid)
10. ✅ **(If applicable)** Import old data and delete separate parking project
11. ✅ Test complete booking flow in app

---

## 🆘 Troubleshooting

### Map doesn't show markers
- Verify parking_layouts have latitude/longitude set
- Check TomTom API key in `parkhub_map_screen.dart` (if using authenticated tiles)
- Ensure location permissions granted on device

### Slots don't update in real-time
- Verify Realtime is enabled on `parking_slots` table
- Check Supabase project is not paused/sleeping
- Look for subscription errors in Flutter logs

### Emails not sending
- Verify Edge Function is deployed: `supabase functions list`
- Check webhook is created and pointing to correct function URL
- Review function logs: Supabase Dashboard → Functions → Logs
- Confirm email service credentials are set (if using Resend/SendGrid)

### Booking creation fails
- Check RLS policies allow insert for authenticated users
- Verify all required fields are provided
- Look for constraint violations in Supabase logs
- **Ensure user is authenticated** - `user_id` must reference a valid user in `auth.users`

### Foreign key constraint error on user_id
- This means you're trying to create a booking with a `user_id` that doesn't exist in `auth.users`
- Verify the user is properly authenticated: `SupabaseService().currentUser?.id`
- Check that the migration ran in the **same project** as your auth system

### Slots stay reserved forever
- Verify cron job is scheduled: `SELECT * FROM cron.job;`
- Manually run cleanup: `SELECT free_expired_parking_slots();`
- Check booking_end_time is in the past

---

## 📝 Next Steps

1. **Customize UI**: Adjust colors in `parking_layout_screen.dart` to match your brand
2. **Add Payment**: Integrate Razorpay/Stripe for actual payment processing
3. **Push Notifications**: Send reminder when booking is about to start
4. **Admin Dashboard**: Build web admin panel for better booking management
5. **Analytics**: Track popular parking spots, peak times, revenue

---

## 🎉 You're All Set!

Your ParkHub Manager feature is now fully functional. Users can:
- 🗺️ Discover nearby parking on an interactive map
- 📍 View real-time parking availability
- 🚗 Book parking spots in advance (1-24 hours)
- ⏰ See booking status and receive email confirmations
- 📱 Manage all bookings from My Bookings screen

**Need help?** Review the code comments in each file or reach out to your development team.

Happy parking! 🅿️
