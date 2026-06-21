# AI Account Book Design

## Scope

Build a runnable full-stack AI bookkeeping app from the provided README, with export removed from this version.

Included:
- User registration, login, JWT authentication, and profile.
- Default categories, category list, create, update, delete, and ordering metadata.
- Bill create, update, delete, paginated list, search, and filters.
- Dashboard, day/month/category/trend statistics.
- Monthly budget save and status.
- AI text parsing for natural-language bookkeeping, with a local rule fallback when no AI key exists.
- Uniapp/Vue3 frontend pages for login, dashboard, bills, statistics, budget, and profile.

Excluded:
- Data export.
- Real speech recognition.
- Production Redis caching.
- Full OpenAI/DeepSeek network integration.

## Backend

The backend lives in `backend/` and uses FastAPI, SQLAlchemy 2.x, Pydantic, and JWT. It defaults to SQLite so it can run locally without external services, while `.env.example` keeps configuration hooks for MySQL, Redis, and AI providers.

API responses use the README shape:

```json
{
  "code": 200,
  "msg": "success",
  "data": {}
}
```

Routes keep the documented paths such as `/auth/login`, `/bill/list`, `/statistics/month`, and `/ai/parse`.

## Frontend

The frontend lives in `frontend/` and follows the Uniapp/Vue3 directory layout from the README. It uses Pinia-style stores, API modules, reusable bill/category/chart components, and practical mobile-first pages.

The visual direction is a restrained finance console: quiet background, clear money hierarchy, high-contrast income/expense states, compact cards, and fast daily-entry workflows.

## Data Flow

1. User registers or logs in.
2. Backend issues a JWT and seeds default categories for that user.
3. Frontend stores token locally and sends it as `Authorization: Bearer <token>`.
4. User creates bills manually or asks `/ai/parse` to structure natural-language text before saving.
5. Statistics and budget pages aggregate persisted bills by authenticated user.

## Verification

Allowed verification excludes Maven and frontend build commands. Use backend unit/API tests, Python syntax compilation, and JavaScript syntax checks where possible.
