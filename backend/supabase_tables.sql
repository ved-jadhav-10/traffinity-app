-- Create favorite_locations table
CREATE TABLE IF NOT EXISTS public.favorite_locations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    address TEXT,
    category TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create index on user_id for faster queries
CREATE INDEX IF NOT EXISTS favorite_locations_user_id_idx ON public.favorite_locations(user_id);

-- Enable Row Level Security
ALTER TABLE public.favorite_locations ENABLE ROW LEVEL SECURITY;

-- Create policy: Users can only see their own favorite locations
CREATE POLICY "Users can view own favorite locations" 
ON public.favorite_locations FOR SELECT 
USING (auth.uid() = user_id);

-- Create policy: Users can insert their own favorite locations
CREATE POLICY "Users can insert own favorite locations" 
ON public.favorite_locations FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Create policy: Users can delete their own favorite locations
CREATE POLICY "Users can delete own favorite locations" 
ON public.favorite_locations FOR DELETE 
USING (auth.uid() = user_id);

-- Create recent_searches table
CREATE TABLE IF NOT EXISTS public.recent_searches (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    query TEXT NOT NULL,
    name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create index on user_id for faster queries
CREATE INDEX IF NOT EXISTS recent_searches_user_id_idx ON public.recent_searches(user_id);

-- Create index on created_at for sorting
CREATE INDEX IF NOT EXISTS recent_searches_created_at_idx ON public.recent_searches(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.recent_searches ENABLE ROW LEVEL SECURITY;

-- Create policy: Users can only see their own recent searches
CREATE POLICY "Users can view own recent searches" 
ON public.recent_searches FOR SELECT 
USING (auth.uid() = user_id);

-- Create policy: Users can insert their own recent searches
CREATE POLICY "Users can insert own recent searches" 
ON public.recent_searches FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Create policy: Users can update their own recent searches
CREATE POLICY "Users can update own recent searches" 
ON public.recent_searches FOR UPDATE 
USING (auth.uid() = user_id);

-- Create policy: Users can delete their own recent searches
CREATE POLICY "Users can delete own recent searches" 
ON public.recent_searches FOR DELETE 
USING (auth.uid() = user_id);

-- Add user profile columns to auth.users metadata
-- Note: These columns should be added through Supabase Dashboard's SQL Editor
-- Run this SQL to add columns to store user profile data:

-- Create user_profiles table to extend auth.users
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone_number TEXT,
    vehicles JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create index on id for faster queries
CREATE INDEX IF NOT EXISTS user_profiles_id_idx ON public.user_profiles(id);

-- Enable Row Level Security
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Create policy: Users can only see their own profile
CREATE POLICY "Users can view own profile" 
ON public.user_profiles FOR SELECT 
USING (auth.uid() = id);

-- Create policy: Users can insert their own profile
CREATE POLICY "Users can insert own profile" 
ON public.user_profiles FOR INSERT 
WITH CHECK (auth.uid() = id);

-- Create policy: Users can update their own profile
CREATE POLICY "Users can update own profile" 
ON public.user_profiles FOR UPDATE 
USING (auth.uid() = id);

-- Create function to automatically create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id)
  VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to call the function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create collections table
CREATE TABLE IF NOT EXISTS public.collections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    collection_name TEXT NOT NULL,
    collection_description TEXT,
    collection_picture TEXT,
    date_created TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create index on user_id for faster queries
CREATE INDEX IF NOT EXISTS collections_user_id_idx ON public.collections(user_id);

-- Enable Row Level Security
ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;

-- Create policies for collections
CREATE POLICY "Users can view own collections" 
ON public.collections FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own collections" 
ON public.collections FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own collections" 
ON public.collections FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own collections" 
ON public.collections FOR DELETE 
USING (auth.uid() = user_id);

-- Create collection_locations table
CREATE TABLE IF NOT EXISTS public.collection_locations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    collection_id UUID NOT NULL REFERENCES public.collections(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    memory_name TEXT NOT NULL,
    memory_description TEXT,
    picture TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    address TEXT,
    date_added TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS collection_locations_collection_id_idx ON public.collection_locations(collection_id);
CREATE INDEX IF NOT EXISTS collection_locations_user_id_idx ON public.collection_locations(user_id);

-- Enable Row Level Security
ALTER TABLE public.collection_locations ENABLE ROW LEVEL SECURITY;

-- Create policies for collection_locations
CREATE POLICY "Users can view own collection locations" 
ON public.collection_locations FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own collection locations" 
ON public.collection_locations FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own collection locations" 
ON public.collection_locations FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own collection locations" 
ON public.collection_locations FOR DELETE 
USING (auth.uid() = user_id);
