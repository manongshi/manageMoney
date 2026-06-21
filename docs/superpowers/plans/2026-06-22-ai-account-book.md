# AI Account Book Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a runnable FastAPI + Uniapp AI bookkeeping project with core account, category, bill, statistics, budget, and AI text parsing flows.

**Architecture:** The backend is a synchronous FastAPI app with SQLAlchemy sessions, JWT auth, service helpers, and SQLite-by-default configuration. The frontend is a Uniapp/Vue3 mobile-first app organized by pages, API modules, stores, utilities, and reusable components.

**Tech Stack:** FastAPI, SQLAlchemy 2.x, Pydantic, python-jose, SQLite/MySQL-ready config, Uniapp, Vue3, Pinia, uview-plus, ECharts dependency.

---

### Task 1: Backend Contract Tests

**Files:**
- Create: `backend/tests/test_core_flow.py`

- [ ] Write tests for register/login, category list, bill add/list/update/delete, dashboard statistics, budget save/info, and AI parse.
- [ ] Run `python -m pytest backend/tests/test_core_flow.py -q` and confirm it fails before implementation exists.

### Task 2: Backend Application

**Files:**
- Create backend package under `backend/app/`
- Create: `backend/requirements.txt`
- Create: `backend/.env.example`

- [ ] Implement configuration, database session, models, schemas, security, response helpers, services, and API routers.
- [ ] Run backend tests and fix until they pass.

### Task 3: Frontend Application

**Files:**
- Create frontend package under `frontend/`

- [ ] Implement Uniapp config files, app bootstrap, API modules, stores, utilities, components, and pages.
- [ ] Keep data export UI and API calls out of the frontend.
- [ ] Run JavaScript syntax checks that do not build the project.

### Task 4: Runtime Documentation

**Files:**
- Create: `RUNNING.md`

- [ ] Document backend setup, frontend setup, default local database behavior, API env variables, and commands to run dev servers.
- [ ] Note that export, real speech recognition, Redis caching, and full AI provider calls are not part of this version.

### Task 5: Verification and Checkpoints

- [ ] Run allowed backend tests.
- [ ] Run Python syntax compilation.
- [ ] Run lightweight JavaScript syntax checks without `npm run build`.
- [ ] Commit important checkpoints.
