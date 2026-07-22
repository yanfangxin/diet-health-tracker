# 個人飲食健康管理系統 (Diet Health Tracker)

本專案採用前後端分離架構與 Supabase / Gemini AI 整合開發。

## 📁 專案架構 (Monorepo Directory Structure)

```text
diet_health_tracker/
├── frontend/             # 前端 Flutter 移動端 / Web 應用程式
│   ├── lib/              # Clean Architecture 源碼 (models, services, widgets, screens)
│   ├── test/             # 測試檔
│   ├── pubspec.yaml      # Flutter 套件相依性
│   └── .env              # Supabase & Gemini API 環境變數設定
│
└── backend/              # 後端與 Supabase 資料庫 Schema
    ├── supabase/
    │   └── schema.sql    # PostgreSQL 表格與索引 Schema (無 RLS)
    └── README.md         # 後端資料庫架構說明
```

## 🌿 Git 分支開發規範 (Branching Strategy)

* `main`：主要穩定版本分支 (Production Branch)
* `feature/project-restructure`：目前開發分支（前後端拆分與四階段優化）
* `feature/<feature-name>`：未來新功能開發分支

## 🚀 快速啟動前端

```bash
cd frontend
flutter pub get
flutter run
```
