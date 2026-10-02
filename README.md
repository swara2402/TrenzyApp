# Trenzy - AI-Powered Fashion Discovery Platform

Trenzy is a cutting-edge fashion discovery platform that combines intelligent product recommendations, social shopping experiences, and collaborative blend creation. The platform helps users discover fashion that matches their style through AI-powered recommendations, wishlist curation, and community-driven style voting.

## Technology Stack

**Backend:**
- FastAPI (async Python web framework)
- PostgreSQL 16 (relational database)
- Redis (optional: caching and rate limiting)
- Firebase Admin SDK (authentication and identity management)
- Socket.IO (real-time blend communication)
- SQLAlchemy ORM (database abstraction)
- Alembic (database migrations)

**Mobile & Web:**
- Flutter 3.16+ (iOS, Android, Web)
- Riverpod (state management)
- Firebase Auth (client-side auth)

**Testing:**
- Playwright (E2E tests)
- pytest (backend unit/integration tests)
- flutter test (Dart unit tests)

**DevOps:**
- Docker & Docker Compose (containerization)
- GitHub Actions (CI/CD)
- Structured JSON logging (observability)

## Repository Structure

```
trenzy/
├── backend/                      # FastAPI backend
│   ├── app/
│   │   ├── main.py              # FastAPI app setup, middleware, exception handling
│   │   ├── db.py                # SQLAlchemy engine, session factory
│   │   ├── models.py            # Database models (User, Product, Room, Wishlist, etc.)
│   │   ├── firebase_auth.py     # Firebase Admin SDK initialization & token verification
│   │   ├── config.py            # Environment configuration validation
│   │   ├── rate_limit.py        # Per-IP rate limiting middleware
│   │   ├── socket_server.py     # Socket.IO server setup
│   │   └── routes/              # API endpoint modules (products, auth, blends, etc.)
│   ├── migrations/              # Alembic database migration scripts
│   ├── tests/                   # pytest backend tests
│   ├── Dockerfile               # Production backend image
│   ├── docker-compose.yml       # Local dev setup (backend, postgres, redis)
│   ├── requirements.txt         # Python dependencies
│   └── alembic.ini              # Alembic configuration
├── lib/                         # Flutter app source code
│   ├── screens/                 # UI screens (Auth, Home, Search, Blend, etc.)
│   ├── providers/               # Riverpod state management
│   ├── services/                # API clients and business logic
│   ├── models/                  # Data models
│   ├── widgets/                 # Reusable UI components
│   └── ARCHITECTURE.md          # Flutter architecture documentation
├── test/                        # Flutter unit and widget tests
├── tests/                       # Playwright E2E tests
├── android/                     # Android-specific configuration
├── ios/                         # iOS-specific configuration
├── web/                         # Web-specific configuration
├── docs/                        # Comprehensive documentation
├── scripts/                     # Utility scripts (secret scanning, data loading)
├── .github/workflows/           # GitHub Actions CI/CD pipelines
└── pubspec.yaml                 # Flutter dependencies

```

## Quick Start

### Prerequisites

- Node.js 18+ & npm
- Python 3.11+
- Flutter 3.16+ SDK
- Docker & Docker Compose
- PostgreSQL 16 (or use Docker)
- Firebase project with credentials

### Local Development Setup

1. **Clone and setup environment:**
   ```bash
   git clone https://github.com/swara2402/TrenzyApp.git
   cd TrenzyApp
   
   # Copy .env example and fill in values
   cp backend/.env.example backend/.env
   # Edit backend/.env with your Firebase credentials, database URL, etc.
   ```

2. **Start backend with Docker:**
   ```bash
   cd backend
   docker-compose up --build
   # Migrations run automatically on startup
   ```

3. **Start Flutter web (in a new terminal):**
   ```bash
   flutter run -d web-server --web-port 8080
   # App will open at http://localhost:8080
   ```

4. **Verify health:**
   ```bash
   curl http://localhost:8000/api/health
   curl http://localhost:8080
   ```

### AI/ML Fashion Intelligence & Recommendation Pipeline

Trenzy features a multimodal recommendation and visual search pipeline powered by FashionCLIP embeddings. The current catalog search path uses the canonical Product vectors with a NumPy cosine scan; pgvector remains an optional future acceleration path.

**Documentation & Contracts:**
- [Model Card (MODEL_CARD.md)](MODEL_CARD.md): Model architectures, evaluation metrics, and operational boundaries.
- [ML Data Contract (ML_DATA_CONTRACT.md)](ML_DATA_CONTRACT.md): Schema specifications, vector dimensions, and data guarantees.
- [Recommendation Architecture (docs/recommendation.md)](docs/recommendation.md): Retrieval, Style DNA, event telemetry, and fallback mechanics.

**Key Endpoints:**
- `GET /api/search/products?q=query&vector=[...]` — Hybrid full-text and vector similarity search.
- `GET /api/style-dna/{product_id}` / `POST /api/style-dna/` — Style DNA profile management.
- `GET /api/style-dna/similar/{product_id}` — Stylistic similarity candidate retrieval.
- `POST /api/events/` — User interaction event telemetry (`view`, `click`, `like`, `purchase`).

**Running AI Pipeline Verification:**
```bash
cd backend
APP_ENV=test python -m app.ai.verification.run_pipeline
```

### Running Tests

**Backend & AI Pipeline Tests:**
```bash
cd backend
pip install -r requirements.txt
pip install pytest pytest-cov
APP_ENV=test TRENZY_TEST_DB=1 DEV_AUTH_BYPASS=true pytest tests/ -v
pytest tests/test_recommendation_pipeline.py -v
```

**Multi-Worker + Redis Smoke Test (validates cross-worker presence & state):**
```bash
# Prerequisites: Redis running locally (docker run -d -p 6379:6379 redis)

# Terminal 1: Start 2 uvicorn workers
cd backend
redis-server &  # or start Redis however you prefer
REDIS_URL=redis://localhost:6379 uvicorn app.main:api --workers 2 --host 0.0.0.0 --port 8000

# Terminal 2: Join same blend from 2 tabs/connections (simulates 2 users)
# Using a Socket.IO client (e.g., websocket-client-py, or curl with websocat):
# 1. Connect with valid auth token to join_blend event → groupId="test-blend-1", then swipe
# 2. In another connection, join same blend, observe presence of user 1 (onlineUserIds list)
# 3. Verify blend_state includes both users' swipes
# 4. Disconnect one user, verify presence update (member_offline event)
# 5. Verify user is still a BlendMember (disconnect ≠ leave)
# 6. Explicit leave_blend removes membership and broadcasts member_left

# Verification:
# - cross-worker messages routed correctly via Redis adapter
# - presence shared across workers (onlineUserIds updated in real-time)
# - membership persistent across disconnect
# - leave removes both presence and membership
```

**Flutter:**
```bash
flutter test
flutter analyze  # Static analysis
```

**E2E (Playwright):**
```bash
npm run qa:install       # Install Playwright browsers (one-time)
npm run qa              # Run all tests headless
npm run qa:ui           # Interactive debugger
npm run qa:headed       # Run in visible browser
```

## Architecture Overview

### High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (Client)                      │
│  Screens → Providers (State) → Services (Business Logic)     │
└──────────────────────┬──────────────────────────────────────┘
                       │ HTTPS + Firebase Token
                       ↓
┌─────────────────────────────────────────────────────────────┐
│                  FastAPI Backend (API)                       │
│  ├─ Routers (endpoints)                                      │
│  ├─ Service layer (business logic)                           │
│  ├─ Models (ORM)                                             │
│  └─ Database layer (SQLAlchemy)                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────┐     ┌──────────────────┐
│    PostgreSQL 16 (Database)      │     │ Redis (Optional) │
│  ├─ Users, Products, Blends      │     │ Caching/Rate-lim │
│  ├─ Wishlists, Carts, Orders     │     └──────────────────┘
│  └─ Social graph (Follow, Posts) │
└──────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              Real-Time (Socket.IO via HTTP)                 │
│  ├─ Blend room events (voting, results)                     │
│  └─ Notification delivery                                   │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

**Authentication:**
- Firebase Auth (client-side signup/login)
- Firebase Admin SDK (server-side token verification)
- Session state stored in SQLite (app) and PostgreSQL (server)
- 5-minute auth token cache to reduce verification overhead

**Product Discovery:**
- Search with full-text indexing on PostgreSQL
- Recommendations via collaborative filtering
- Wishlist with product variants and sizes

**Blends (Social Shopping):**
- Real-time voting via Socket.IO
- Group recommendation results
- Audit trail for blend history

**Social Features:**
- User following graph
- Posts and activity feed
- User suggestions (collaborative filtering)

See `docs/ARCHITECTURE.md` for detailed diagrams and design rationale.

## Database Setup

**Initial Setup:**
```bash
cd backend
# Docker Compose creates the database automatically
# Or manually:
createdb trenzy
export DATABASE_URL="postgresql://postgres:password@localhost:5432/trenzy"
alembic upgrade head
```

**Load Product Catalog:**

Keep the supplied dataset outside Git and mount it into the runtime, for example:

```text
/data/trenzy/catalog.csv
/data/trenzy/images/TRZ-0001.jpg
...
/data/trenzy/images/TRZ-2000.jpg
```

Run the validation-only smoke check first:

```bash
cd backend
python -m app.scripts.import_image_catalog \
  --image-dir /data/trenzy/images \
  --catalog-file /data/trenzy/catalog.csv \
  --dry-run
```

Then import the 2,000 products:

```bash
python -m app.scripts.import_image_catalog \
  --image-dir /data/trenzy/images \
  --catalog-file /data/trenzy/catalog.csv
```

Finally generate/resume FashionCLIP embeddings:

```bash
python -m app.scripts.import_image_catalog \
  --image-dir /data/trenzy/images \
  --catalog-file /data/trenzy/catalog.csv \
  --embed
```

For a small runtime smoke test, add `--limit 10`. Use `--batch-size 16` or `--batch-size 32` to control checkpoint/commit size. The embedding job is resumable: completed vectors for the current model/version are skipped, failed products are retried, and a changed source image resets its embedding status. A non-zero exit code means the catalog is not fully indexed.

The image directory is intentionally not committed to Git. Catalog assets are served from `/product-images/`; user uploads remain private behind authenticated routes. Product IDs come directly from the catalog (`TRZ-0001` through `TRZ-2000`) and image hashes are recorded for provenance/change detection.

**Run the import from GitHub Actions:** The repository includes `.github/workflows/import-trenzy-catalog.yml`. It is a manual workflow that runs on a **self-hosted GitHub Actions runner**, because the 2,000-image dataset is deliberately kept outside Git and FashionCLIP inference may benefit from local/GPU hardware.

Before running it:
1. Register a self-hosted runner for this repository.
2. Put the dataset on that runner, for example at `/data/trenzy/catalog.csv` and `/data/trenzy/images/`.
3. Add repository Actions secrets named `TRENZY_DB_HOST`, `TRENZY_DB_PORT`, `TRENZY_POSTGRES_DB`, `TRENZY_POSTGRES_USER`, and `TRENZY_POSTGRES_PASSWORD`.
4. Open **GitHub → Actions → Import Trenzy catalog → Run workflow**.
5. Keep **Generate FashionCLIP embeddings** enabled to import the catalog and generate/resume embeddings.

The workflow first performs the same zero-write dataset validation as `--dry-run`, then runs the idempotent importer. It fails rather than silently proceeding when the dataset is missing or invalid.

**Inspect Schema:**
```bash
psql trenzy
# In psql:
\dt                    # List tables
\d products            # Describe products table
```

See `docs/DATABASE.md` for schema documentation and migration strategies.

## Running Backend

**Development (auto-reload):**
```bash
cd backend
uvicorn app.main:api --reload --host 0.0.0.0 --port 8000
```

**Production (docker-compose):**
```bash
cd backend
docker-compose -f docker-compose.yml up -d
```

**Health check:**
```bash
curl http://localhost:8000/api/health
curl http://localhost:8000/api/health/ready
```

## Running Flutter

**Web (local dev):**
```bash
flutter run -d web-server --web-port 8080
```

**iOS:**
```bash
flutter run -d ios
```

**Android:**
```bash
flutter run -d android
```

**Build for production:**
Release builds no longer default to a hardcoded backend host (the former
`https://api.trenzy.com` default pointed at a dead server). You MUST pass the
backend URL at build time:

```bash
flutter build web --release --dart-define=TRENZY_API_BASE_URL=https://api.example.com
flutter build ios --release --dart-define=TRENZY_API_BASE_URL=https://api.example.com
flutter build apk --release --dart-define=TRENZY_API_BASE_URL=https://api.example.com
```

`FF_API_URL_OVERRIDE` can be used the same way; a release build without either
define fails fast with a clear message instead of silently routing to a
phantom server. Debug builds keep `http://localhost:8000`.

## Running Tests

**All tests (CI/CD equivalent):**
```bash
# Backend
cd backend && pytest tests/ -v

# Flutter
flutter test

# E2E (requires app running on http://localhost:8080)
npm run qa
```

**With coverage:**
```bash
# Backend
pytest tests/ --cov=app --cov-report=html

# Flutter
flutter test --coverage
```

## Deployment

### Staging Deployment

```bash
# Build and tag Docker image
docker build -f backend/Dockerfile -t trenzy-api:latest backend/

# Push to registry (e.g., Docker Hub, GCR)
docker tag trenzy-api:latest your-registry/trenzy-api:latest
docker push your-registry/trenzy-api:latest

# Deploy via docker-compose or Kubernetes
docker-compose -f backend/docker-compose.yml up -d
```

### Production Deployment

1. **Prepare environment:**
   ```bash
   # Set production secrets in .env (never commit)
   FIREBASE_SERVICE_ACCOUNT_JSON=...
   POSTGRES_PASSWORD=...
   POSTGRES_USER=postgres
   DATABASE_URL=postgresql://...
   ```

2. **Build and deploy:**
   ```bash
   docker build -f backend/Dockerfile -t trenzy-api:v1.0.0 backend/
   docker run -d \
     --name trenzy-backend \
     -p 8000:8000 \
     --env-file backend/.env \
     trenzy-api:v1.0.0
   ```

3. **Verify:**
   ```bash
   curl https://your-domain.com/api/health
   ```

See `docs/DEPLOYMENT.md` for detailed production checklist and rollback procedures.

## Security Model

**Authentication & Authorization:**
- All endpoints (except /health, /login, /signup) require Firebase token
- Token verified server-side before every request
- User isolation enforced in database queries
- No access to other users' data

**Data Protection:**
- CORS restricted to approved origins (staging/production)
- Rate limiting enabled (configurable per IP)
- Sensitive data (passwords, tokens) never logged
- HTTPS required in production

**API Security:**
- Input validation on all endpoints (Pydantic models)
- SQL injection prevented via SQLAlchemy ORM parameterized queries
- CSRF protection via SameSite cookies
- Secure payment processing (Stripe in test/production mode)

**Infrastructure:**
- Docker runs backend as non-root user
- Secrets provided via environment variables (never in code)
- Database backups automated
- Logs structured and forwarded to central logging

See `docs/SECURITY.md` for threat model, mitigations, and incident response procedures.

## Observability

**Logging:**
- Structured JSON logging (timestamp, level, module, request_id, user_id)
- All requests logged with method, path, status, latency
- Errors logged with full stack trace
- Security events (auth failures, payment issues) highlighted

**Health Checks:**
- `/api/health` - Full health status (database, Firebase, products)
- `/api/health/ready` - Readiness probe for Kubernetes/load balancers

**Metrics:**
- Request latency per endpoint
- Error rates by type (4xx, 5xx)
- Database query times
- Authentication success/failure rates

Set `LOG_FORMAT=json` to enable structured logging; stream to ELK, Datadog, etc.

## Performance Considerations

**Database:**
- Indexes on foreign keys, user_uid, created_at
- Pagination (default 20 items, max 100)
- Connection pooling (SQLAlchemy)

**API:**
- Response filtering (product list returns minimal fields)
- Caching: products (1h), recommendations (30m), search (5m)
- Rate limiting: 100 requests per 15 minutes per IP

**Frontend:**
- Lazy-loaded screens and images
- Riverpod selectors to prevent unnecessary rebuilds
- Offline support for cached data

See `docs/ARCHITECTURE.md` for detailed performance recommendations.

## Troubleshooting

**"cannot connect to docker daemon"**
```bash
# Ensure Docker is running
docker ps
```

**"Firebase Admin failed to initialize"**
```bash
# Check FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_SERVICE_ACCOUNT_FILE
echo $FIREBASE_SERVICE_ACCOUNT_JSON
# Ensure credentials file is valid JSON
```

**"database connection refused"**
```bash
# Check PostgreSQL is running and accessible
psql postgresql://postgres@localhost:5432/trenzy
# Or check docker container
docker logs backend-db-1
```

**"Flutter app not loading"**
```bash
# Check web server is running on port 8080
curl http://localhost:8080
# Check browser console for errors
# Try: flutter run -d web-server --web-port 8080 --verbose
```

**"Tests failing in CI but passing locally"**
- Ensure environment variables are set in `.env.test`
- Check database migration ran: `alembic upgrade head`
- Verify test credentials exist: `TEST_USER_EMAIL`, `TEST_USER_PASSWORD`

See `docs/TROUBLESHOOTING.md` for additional debugging tips.

## Contributing

1. Create a feature branch from `main`
2. Make changes and ensure tests pass locally
3. Commit with clear messages
4. Push and create a pull request
5. All CI/CD checks must pass before merge
6. Code review required

## License

ISC License. See LICENSE file for details.

## Support

For issues, questions, or feature requests, open a GitHub issue or contact the Trenzy team.

---

**Version**: 1.0.0-beta  
**Last Updated**: 2024  
**Status**: Beta / pre-production — run the security and catalog checks before production deployment.
