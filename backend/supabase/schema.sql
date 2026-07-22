-- ========================================================
-- 飲食健康管理系統 (Diet Health Tracker) - Supabase 資料庫 Schema
-- ========================================================

-- 1. 建立每日健康紀錄資料表 (diet_daily_logs)
CREATE TABLE IF NOT EXISTS public.diet_daily_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE UNIQUE NOT NULL,
    water_intake_ml INT DEFAULT 0,
    sleep_minutes INT DEFAULT 0,
    weight_kg NUMERIC(5, 2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 建立日期索引以加速查詢
CREATE INDEX IF NOT EXISTS idx_diet_daily_logs_date ON public.diet_daily_logs (date);

-- 2. 建立飲食熱量紀錄資料表 (diet_food_logs)
CREATE TABLE IF NOT EXISTS public.diet_food_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    logged_date DATE NOT NULL,
    food_name TEXT NOT NULL,
    calories INT NOT NULL,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 建立日期索引以加速查詢
CREATE INDEX IF NOT EXISTS idx_diet_food_logs_logged_date ON public.diet_food_logs (logged_date);
