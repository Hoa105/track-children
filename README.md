# Track Children

Ứng dụng hỗ trợ phụ huynh và người chăm sóc theo dõi sức khỏe, sự phát triển
và các hoạt động hằng ngày của trẻ.

## Kiến trúc project

Repository được tổ chức theo mô hình monorepo gồm bốn thành phần:

- `mobile`: Flutter mobile app cho phụ huynh/người chăm sóc.
- `backend`: FastAPI API, business logic và database.
- `ai-service`: NLP, indicator mapping, rule engine và tích hợp LLM.
- `admin-web`: React admin web cho quản trị viên.

```text
track-children/
├── mobile/                     # Flutter application
│   ├── lib/
│   │   ├── app/                # App configuration and routes
│   │   ├── core/               # Shared theme, widgets, network, storage
│   │   ├── features/           # Feature modules
│   │   │   └── <feature>/
│   │   │       ├── models/
│   │   │       ├── api/
│   │   │       ├── screens/
│   │   │       └── widgets/
│   │   ├── models/
│   │   ├── services/
│   │   └── shared/             # Reusable UI and utilities
│   ├── test/
│   ├── pubspec.yaml
│   └── README.md
│
├── backend/                    # FastAPI backend
│   ├── app/
│   │   ├── main.py
│   │   ├── core/               # Config, security, database
│   │   ├── features/           # Backend feature modules
│   │   │   └── <feature>/
│   │   │       ├── model.py
│   │   │       ├── schema.py
│   │   │       ├── router.py
│   │   │       └── service.py
│   │   ├── shared/             # Permissions, access, clients
│   │   └── seed/               # Initial data
│   ├── tests/
│   ├── requirements.txt
│   ├── .env.example
│   └── README.md
│
├── ai-service/                 # Rule-based NLP and LLM service
│   ├── app/
│   │   ├── main.py
│   │   ├── nlp/                # Text normalization and indicators
│   │   ├── rules/              # Rule engine
│   │   ├── llm/                # LLM client
│   │   ├── api/                # AI API routes
│   │   └── schemas/            # Request and response schemas
│   ├── tests/
│   ├── requirements.txt
│   ├── .env.example
│   └── README.md
│
├── admin-web/                  # React administration interface
│   ├── src/
│   │   ├── app/                # App configuration
│   │   ├── core/               # Shared frontend infrastructure
│   │   ├── features/           # Feature modules
│   │   │   └── <feature>/
│   │   │       ├── components/
│   │   │       ├── pages/
│   │   │       └── api/
│   │   └── shared/             # Reusable components and utilities
│   ├── public/
│   ├── package.json
│   └── README.md
│
├── docs/
│   ├── architecture/           # System architecture
│   ├── database/               # Database design and migrations
│   ├── api/                    # API contracts
│   └── ai/                    # AI design and rules
│
├── docker-compose.yml
├── .gitignore
└── README.md
```

## Chạy các service

### Mobile

```powershell
cd mobile
flutter pub get
flutter run
```

### Backend

```powershell
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload
```

API health check: `GET http://localhost:8000/health`.

### AI service

```powershell
cd ai-service
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8001
```

### Admin web

```powershell
cd admin-web
npm install
npm run dev
```

## Chạy bằng Docker Compose

```powershell
docker compose up --build
```
