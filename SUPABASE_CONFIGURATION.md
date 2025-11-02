# Supabase Configuration Guide for Traffinity App

## ✅ Your Credentials Have Been Added!

Your Supabase project is now connected to the app:

- **Project URL:** `https://pmsemyznsxeigmfhzyfg.supabase.co`
- **Anon Key:** Configured ✓

---

## 🔧 Required Supabase Configuration

Follow these steps in your Supabase dashboard to complete the setup:

### 1. Enable Authentication Providers

Go to: **Authentication** → **Providers** → **Email**

✅ Enable **Email provider**
✅ Set **Confirm email** to `ON` (for email verification via OTP)
✅ Set **Secure email change** to `ON`

---

### 2. Configure Google Sign In

Go to: **Authentication** → **Providers** → **Google**

✅ Enable **Google provider**
✅ Add your **Client ID** and **Client Secret** from Google Cloud Console

**To get Google OAuth credentials:**

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable **Google+ API**
4. Go to **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**
5. Configure consent screen
6. Add authorized redirect URIs:
   - `https://pmsemyznsxeigmfhzyfg.supabase.co/auth/v1/callback`
7. Copy the Client ID and Client Secret to Supabase

---

### 3. Configure Phone Authentication (SMS/OTP)

Go to: **Authentication** → **Providers** → **Phone**

✅ Enable **Phone provider**
✅ Choose an SMS provider:

- **Twilio** (recommended)
- **MessageBird**
- **Vonage**
- **TextLocal**

**Note:** Phone authentication requires SMS provider configuration and may incur costs.

#### For Twilio Setup:

1. Sign up at [Twilio](https://www.twilio.com/)
2. Get your Account SID and Auth Token
3. Add credentials to Supabase Phone provider settings
4. Configure a phone number for sending SMS

---

### 4. Set Up Redirect URLs

Go to: **Authentication** → **URL Configuration**

Add these redirect URLs:

- `http://localhost:3000/**` (for testing)
- `https://your-app-domain.com/**` (for production)
- Deep link URL: `io.supabase.traffinity://**` (for mobile app)

---

### 5. Create Database Tables

Go to: **SQL Editor** and run this SQL:

```sql
-- Create profiles table for user data
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  first_name TEXT,
  last_name TEXT,
  phone_number TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Public profiles are viewable by everyone"
  ON public.profiles FOR SELECT
  USING (true);

CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Create a trigger to create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, username, first_name, last_name, phone_number)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'username', ''),
    COALESCE(new.raw_user_meta_data->>'first_name', ''),
    COALESCE(new.raw_user_meta_data->>'last_name', ''),
    COALESCE(new.raw_user_meta_data->>'phone_number', '')
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at trigger to profiles
DROP TRIGGER IF EXISTS on_profile_updated ON public.profiles;
CREATE TRIGGER on_profile_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
```

---

### 6. Configure Email Templates (Optional but Recommended)

Go to: **Authentication** → **Email Templates**

Customize templates for:

- **Confirm signup** (OTP email)
- **Magic Link**
- **Change Email Address**
- **Reset Password**

Use your brand colors:

- Primary: `#06d6a0`
- Background: `#1c1c1c`
- Text: `#f5f6fa`

---

### 7. Set Up Storage (If needed for user avatars/files)

Go to: **Storage** → **New Bucket**

Create a bucket named `avatars`:

- ✅ Public bucket: `ON`
- File size limit: `5 MB`
- Allowed MIME types: `image/*`

Create policy for the bucket:

```sql
-- Allow users to upload their own avatar
CREATE POLICY "Users can upload avatar"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to update their own avatar
CREATE POLICY "Users can update avatar"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow public to view avatars
CREATE POLICY "Avatars are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');
```

---

### 8. Configure Security Settings

Go to: **Settings** → **API**

✅ **Enable:** JWT Expiry (set to 3600 seconds / 1 hour)
✅ **Enable:** Email OTP expiry (set to 300 seconds / 5 minutes)
✅ **Enable:** SMS OTP expiry (set to 300 seconds / 5 minutes)

---

## 🧪 Testing Your Setup

### Test Email Authentication:

1. Run your app: `flutter run`
2. Complete onboarding
3. Click "Create Account"
4. Fill in the form with a real email
5. Check your email for OTP
6. Enter OTP to verify

### Test Google Sign In:

1. Click "Sign In"
2. Click "Continue with Google"
3. Select your Google account
4. Verify you're logged in

### Test Phone Authentication:

1. Click "Sign In"
2. Click "Continue with Phone"
3. Enter phone number
4. Receive SMS OTP
5. Enter OTP to verify

---

## 🐛 Troubleshooting

### Email OTP not received?

- Check spam folder
- Verify email provider is enabled
- Check Supabase logs: **Authentication** → **Logs**

### Google Sign In fails?

- Verify Client ID and Secret are correct
- Check redirect URIs match exactly
- Ensure Google+ API is enabled

### Phone OTP not received?

- Verify phone provider (Twilio) is configured
- Check phone number format: `+91XXXXXXXXXX`
- Verify SMS credits in your SMS provider account
- Check Supabase logs for errors

### App crashes on startup?

- Verify Supabase URL and Anon Key are correct
- Check internet connection
- Run `flutter clean && flutter pub get`

---

## 📱 Deep Linking Setup (For OTP emails)

### Android (`android/app/src/main/AndroidManifest.xml`):

Add inside `<activity>` tag:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="https"
        android:host="pmsemyznsxeigmfhzyfg.supabase.co" />
</intent-filter>
```

### iOS (`ios/Runner/Info.plist`):

Add:

```xml
<key>FlutterDeepLinkingEnabled</key>
<true/>
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>io.supabase.traffinity</string>
        </array>
    </dict>
</array>
```

---

## 🎯 What's Next?

1. ✅ **Complete Supabase configuration** (follow steps above)
2. ✅ **Run the database SQL** to create tables and triggers
3. ✅ **Enable authentication providers** you want to use
4. ✅ **Test authentication flows** thoroughly
5. 🔄 **Create your home screen** and replace TODO navigation
6. 🔄 **Add user profile screen** to display/edit profile
7. 🔄 **Implement forgot password** functionality
8. 🔄 **Add social login** (Apple, Facebook, etc.)

---

## 🔐 Security Checklist

- ✅ `.env` file is git-ignored
- ✅ Row Level Security enabled on all tables
- ✅ Email confirmation enabled
- ✅ Secure password requirements set
- ⚠️ Configure rate limiting in production
- ⚠️ Set up monitoring and alerts
- ⚠️ Regular security audits

---

## 📞 Support

If you need help:

1. Check [Supabase Documentation](https://supabase.com/docs)
2. Visit [Supabase Discord](https://discord.supabase.com)
3. Check app logs for errors
4. Review Supabase dashboard logs

---

**Your authentication system is now ready to use! 🎉**

Just complete the Supabase configuration steps above and start testing!
