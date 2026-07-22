# 飲食健康管理系統 - 後端架構 (Backend)

本專案後端採用 **Supabase (PostgreSQL)** 資料庫與 **Gemini Multimodal AI API** 服務。

## 📁 後端目錄結構

```text
backend/
└── supabase/
    └── schema.sql   # Supabase 資料庫 Table Schema 與 Index 定義 (未開啟 RLS)
```

## 🗄️ 資料庫表格說明

### 1. `diet_daily_logs` (每日健康紀錄)
* `id`: UUID (Primary Key)
* `date`: DATE (Unique 日期，格式 `YYYY-MM-DD`)
* `water_intake_ml`: INT (累積喝水量)
* `sleep_minutes`: INT (累積睡眠分鐘數)
* `weight_kg`: NUMERIC (今日體重)

### 2. `diet_food_logs` (飲食熱量紀錄)
* `id`: UUID (Primary Key)
* `logged_date`: DATE (紀錄日期)
* `food_name`: TEXT (食物名稱)
* `calories`: INT (估算熱量 kcal)
* `image_url`: TEXT (可選餐點圖片連結)
