# Auth — Feature Doc
**Project:** KhataDost (mac)  
**Status:** Ready to build  
**Scope:** Splash, Welcome, Login, Register  

---

## What this feature does

Handles the full entry point of the app. A shopkeeper opens the app, either registers for the first time or logs back in, and lands on the Dashboard. JWT is persisted so returning users skip the welcome screen entirely.

---

## User flows

### First time open
```
App launch
  → Splash (native + Flutter)
  → read JWT from secure storage
  → no token found
  → Welcome screen
```

### Returning user (token valid)
```
App launch
  → Splash
  → read JWT → valid
  → Dashboard (skip Welcome)
```

### Login
```
Welcome → "Log in"
  → LoginPage
  → enter email + password
  → submit
    ↓ success  → save JWT → Dashboard
    ↓ failure  → show error on form, stay on LoginPage
```

### Register
```
Welcome → "Sign up"
  → RegisterPage
  → enter name, shop name, phone, email, password, access code
  → submit
    ↓ valid code + new email  → save JWT → Dashboard
    ↓ invalid access code     → "Invalid access code"
    ↓ email already taken     → "An account with this email already exists"
    ↓ other server error      → generic error message
```

### Logout (triggered from Settings)
```
Settings → Logout
  → clear JWT from secure storage
  → dispatch LogoutRequested event
  → Welcome screen
```

---

## Screens

### SplashPage
- Flutter-level splash (shown after native splash)
- No UI interaction, just logic
- Reads JWT → redirects via GoRouter

### WelcomePage
- "Welcome to KhataDost" heading
- Two buttons: "Log in" and "Sign up"
- No form, just navigation

### LoginPage
- Fields: Email, Password
- Submit button: "Log in"
- Link: "Don't have an account? Sign up"
- Error shown inline on form (not a snackbar)

### RegisterPage
- Fields: Name, Shop name, Phone, Email, Password, Access code
- Submit button: "Create account"
- Link: "Already have an account? Log in"
- Error shown inline on form

---

## Access code
- A single hardcoded string on the backend, read from `.env`
- Value for dev/demo: `KHATA2025`
- Backend validates it before creating the account
- If wrong → 400 response with clear message

---

## BLoC

### Events
```dart
LoginRequested(email, password)
RegisterRequested(name, shopName, phone, email, password, accessCode)
LogoutRequested
```

### States
```dart
AuthInitial
AuthLoading
AuthSuccess(user)
AuthFailure(message)
Unauthenticated
```

### Scope
- AuthBloc is **global** — provided at the root in main.dart
- GoRouter listens to AuthBloc state for redirect logic

---

## Data

### Registration request body
```json
{
  "name": "Ramesh",
  "shop_name": "Ramesh Kirana",
  "phone": "9876543210",
  "email": "ramesh@example.com",
  "password": "secret123",
  "access_code": "KHATA2025"
}
```

### Registration response
```json
{
  "token": "<jwt>",
  "user": {
    "id": "uuid",
    "name": "Ramesh",
    "shop_name": "Ramesh Kirana",
    "email": "ramesh@example.com",
    "phone": "9876543210"
  }
}
```

### Login request body
```json
{
  "email": "ramesh@example.com",
  "password": "secret123"
}
```

### Login response
```json
{
  "token": "<jwt>",
  "user": {
    "id": "uuid",
    "name": "Ramesh",
    "shop_name": "Ramesh Kirana",
    "email": "ramesh@example.com",
    "phone": "9876543210"
  }
}
```

---

## API endpoints used

| Method | Path | Auth required |
|--------|------|---------------|
| POST | /v1/register | No |
| POST | /v1/login | No |

---

## GoRouter routes

| Route | Page |
|-------|------|
| / | SplashPage |
| /welcome | WelcomePage |
| /login | LoginPage |
| /register | RegisterPage |
| /home/dashboard | redirect target on success |

**Redirect guard logic:**
- If no JWT → redirect any `/home/...` to `/welcome`
- If JWT valid → redirect `/welcome`, `/login`, `/register` to `/home/dashboard`

---

## Flutter file map

```
features/auth/
├── data/
│   ├── models/
│   │   ├── user_model.dart
│   │   └── auth_response_model.dart
│   ├── datasources/
│   │   └── auth_remote_datasource.dart
│   └── repositories/
│       └── auth_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── user.dart
│   └── repositories/
│       └── auth_repository.dart
└── presentation/
    ├── bloc/
    │   ├── auth_bloc.dart
    │   ├── auth_event.dart
    │   └── auth_state.dart
    ├── pages/
    │   ├── splash_page.dart
    │   ├── welcome_page.dart
    │   ├── login_page.dart
    │   └── register_page.dart
    └── widgets/
        ├── login_form.dart
        └── register_form.dart
```

---

## Backend file map (mas)

```
internal/
├── handler/
│   └── auth_handler.go       ← POST /v1/register · POST /v1/login
├── service/
│   └── auth_service.go       ← validate access code, hash password, generate JWT
└── repository/
    └── auth_repository.go    ← insert user, find user by email

db/
├── migrations/
│   └── 001_create_users.sql
└── queries/
    └── auth.sql              ← sqlc queries
```

---

## Build order

1. Flutter — splash, welcome, login, register pages with **mocked datasource**
2. Flutter — AuthBloc wired, GoRouter redirect guard working, JWT stored (mocked token)
3. Backend — users table migration, register + login handlers
4. Flutter — swap mock datasource → real Dio calls
5. Test end to end: register → JWT saved → reopen app → lands on dashboard

---

## What is deferred (not in this feature)

- Shop address, UPI ID → Settings feature
- Password reset / forgot password → not in scope
- Token refresh → not in scope for now, just re-login on expiry