# KhataDost — Digital Khata for Kirana Shops

> *"Your Ledger's Best Friend"*

[![Flutter](https://img.shields.io/badge/Flutter-3.24.3-blue?logo=flutter)](https://flutter.dev)
[![Go](https://img.shields.io/badge/Go-1.24.4-00ADD8?logo=go)](https://golang.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql)](https://postgresql.org)

---

## The Problem

India has over 12 million kirana stores — small neighbourhood shops that sell everything from rice to shampoo. Every one of them runs on credit. A customer walks in, picks up groceries, says *"udhaar de do"* (put it on my tab), and the shopkeeper writes it down in a paper notebook.

That notebook gets lost. Numbers go wrong. Chasing payments is awkward. And when 50 customers all have running tabs, there is no fast way to know who owes what.

KhataDost replaces that notebook.

---

## What It Does

A shopkeeper opens the app and points their phone camera at the products on the counter. The AI identifies each item, pulls it from the shop's inventory with the right price, and builds the bill automatically. The shopkeeper reviews, picks the customer, and marks it as cash or udhaar. If it's udhaar, the customer's running balance updates instantly. When it's time to collect, the app sends a WhatsApp reminder so the shopkeeper never has to make an awkward call.

**Three core flows:**

**1. Smart Billing via Camera**
Point camera at products → Gemini Vision identifies items → matched against shop's own inventory → review and edit → cash or add to customer's khata.

**2. Manual Billing**
Search inventory → add items → same review and checkout. Floating scan button always available to switch to camera mid-bill.

**3. Digital Khata**
Every customer has a running ledger. Full transaction timeline, outstanding balance at a glance, one-tap WhatsApp reminder.

---

## Features

| Screen | What the shopkeeper can do |
|--------|---------------------------|
| **Dashboard** | Today's sales, total outstanding dues, low stock alerts, recent bills, quick access to inventory |
| **Inventory** | Add, edit, delete items — name, price, quantity, unit, packed or loose, category |
| **Bills** | Manual billing with search, camera scan billing, full bill history |
| **Customers** | Add and manage customers, per-customer analytics, full khata ledger |
| **Settings** | Shop profile, change password, logout, delete account |

---

## Tech Stack

### Mobile App (`/app`)
Flutter, feature-first clean architecture, pure BLoC state management.

| Package | Purpose |
|---------|---------|
| Flutter 3.24.3 · Dart 3.5.3 | Framework |
| `flutter_bloc` | State management |
| `go_router` | Navigation + auth redirect guards |
| `dio` | HTTP client |
| `get_it` | Dependency injection |
| `flutter_secure_storage` | JWT persistence |
| `freezed` + `json_serializable` | Immutable models |
| `camera` / `image_picker` | Scan flow |
| `fl_chart` | Dashboard charts |

### Backend (`/backend`)
Go, layered Handler → Service → Repository architecture.

| Package | Purpose |
|---------|---------|
| Go 1.24.4 | Language |
| `go-chi/chi` | HTTP router |
| `pgx` + `sqlx` | PostgreSQL driver |
| `sqlc` | Type-safe Go from raw SQL |
| `golang-migrate` | Database migrations |
| `golang-jwt` + `bcrypt` | Auth |
| `godotenv` | Config |

### External Services
| Service | Purpose |
|---------|---------|
| PostgreSQL 17 | Primary database |
| Google Gemini Vision API | AI item detection from camera |

---

## How the Scan Flow Works

```
Shopkeeper points camera at products
            ↓
  Gemini Vision identifies item names
            ↓
  Backend matches against shop inventory
            ↓
  Found in DB              Not in DB
  Price + stock            Shown as unrecognised
  pulled in                Name + price editable
            ↓                     ↓
          Review screen (edit qty, remove items)
                      ↓
          Pick customer  or  Walk-in
                      ↓
         Cash         or      Udhaar
           ↓                     ↓
      Bill saved           Khata updated
      Stock deducted       Stock deducted
```

---

## Repo Structure

```
KhataDost/
├── app/          ← Flutter mobile client
├── backend/      ← Go REST API
└── docs/
    ├── architecture.md
    └── features/
        └── auth.md
```

Full architecture → [docs/architecture.md](docs/architecture.md)

---

## Build Status

| Feature | Flutter | Backend | Wired |
|---------|---------|---------|-------|
| Auth | ✅ | ✅ | ✅ |
| Dashboard | 🔧 | 🔧 | — |
| Inventory | 🔧 | 🔧 | — |
| Billing | 🔧 | 🔧 | — |
| Customers + Khata | 🔧 | 🔧 | — |
| Settings | 🔧 | 🔧 | — |

---

*Solo project by Sanu1001. Built to learn Go backend development while solving a real problem.*