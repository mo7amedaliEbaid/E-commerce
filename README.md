# ecom

A small e-commerce app: a Go REST API (using [Gin](https://github.com/gin-gonic/gin) and MongoDB) with a Flutter mobile client. Users can sign up/log in, browse and search products, manage a cart and addresses, and check out. Auth is JWT-based.

Full endpoint-by-endpoint reference (headers, body, params, responses, known quirks): **[API.md](API.md)**.

## Tech stack

- Go 1.23+
- [Gin](https://github.com/gin-gonic/gin) — HTTP router
- MongoDB (via `go.mongodb.org/mongo-driver`)
- JWT (`dgrijalva/jwt-go`) + bcrypt for auth

## Project structure

```
main.go            entrypoint, route registration
routes/             public route definitions
controllers/         request handlers (users, products, cart, addresses)
database/            Mongo client setup + cart/order DB operations
middleware/           JWT auth middleware
models/               MongoDB document schemas
tokens/               JWT generation/validation
docker-compose.yaml   Mongo + mongo-express for local dev
mobile/               Flutter client app (see below)
```

## Prerequisites

- Go 1.23+
- A MongoDB instance — either via Docker Compose (included) or a native install

## Setup

1. **Configure environment variables**

   ```bash
   cp .env.example .env
   ```

   Fill in `.env` with real values (defaults in `.env.example` work for local dev as-is — they match the credentials in `docker-compose.yaml`). See [Environment variables](#environment-variables) below for what each one does.

2. **Start MongoDB**

   Option A — Docker Compose (spins up Mongo + a [mongo-express](https://github.com/mongo-express/mongo-express) UI at `localhost:8081`):

   ```bash
   docker compose up -d
   ```

   Option B — native MongoDB (e.g. via Homebrew on macOS):

   ```bash
   brew tap mongodb/brew
   brew install mongodb-community@7.0
   brew services start mongodb/brew/mongodb-community@7.0

   # create the user matching docker-compose's credentials / your .env
   mongosh mongodb://localhost:27017/admin --eval '
     db.createUser({ user: "development", pwd: "testpassword", roles: [{ role: "root", db: "admin" }] })
   '
   ```

3. **Install Go dependencies**

   ```bash
   go mod tidy
   ```

4. **Run the server**

   ```bash
   set -a; source .env; set +a
   go run main.go
   ```

   Listens on `:8000` by default (override with `PORT`).

5. **Verify**

   ```bash
   curl http://localhost:8000/users/productview
   # → []
   ```

## Environment variables

| Variable | Required | Default | Notes |
|---|---|---|---|
| `MONGO_URI` | Yes | — | Full Mongo connection string, e.g. `mongodb://development:testpassword@localhost:27017`. App fails fast if unset. |
| `MONGO_ROOT_USERNAME` | Only for `docker compose up` | — | Seeds Mongo's root user via `MONGO_INITDB_ROOT_USERNAME`. |
| `MONGO_ROOT_PASSWORD` | Only for `docker compose up` | — | Seeds Mongo's root user via `MONGO_INITDB_ROOT_PASSWORD`. |
| `SECRET_LOVE` | Recommended | empty string | HMAC signing key for JWTs. Works if unset, but every token is signed with an empty key — set a real value outside of local dev. |
| `PORT` | No | `8000` | HTTP listen port. |

`.env` is gitignored; `.env.example` documents the shape without real secrets — see [API.md § Known issues](API.md#known-issues) and the note below for why this matters.

## Images

Product images are hosted externally (e.g. [Cloudinary](https://cloudinary.com)) — this app has no upload endpoint. Upload an image there yourself, then pass the resulting URL as the `image` field when creating a product via `POST /admin/addproduct`. The app exposes a GET-only redirect at `GET /products/:id/image` so clients get a stable link instead of depending on the underlying image host directly.

## Mobile app

A simple Flutter client lives in `mobile/`, built against the endpoints in [API.md](API.md): login/signup, product list with search, add-to-cart, instant buy, a product-add dialog (via the unauthenticated `/admin/addproduct`), and a cart screen with remove/checkout. Session (token + user id) is held in memory only — no persistence across restarts.

```bash
cd mobile
flutter pub get
flutter run
```

Base URL is set in `mobile/lib/config.dart`. It defaults to `http://localhost:8000`, and auto-switches to `http://10.0.2.2:8000` on Android emulators (the alias emulators use to reach the host machine). Neither works from a **physical device** — edit `config.dart` to point at your dev machine's LAN IP instead (find it via System Settings → Wi-Fi → Details, or `ipconfig getifaddr en0`), and make sure the device is on the same Wi-Fi network. Flutter Web will also hit CORS errors against this backend, since the Go server doesn't set CORS headers.

## A note on this codebase

This started from a public Go/Mongo tutorial project. It works, but has some rough edges worth knowing about before you build on it — missing panic recovery, an admin route that isn't actually protected, endpoints that trust client-supplied user IDs rather than the authenticated token, etc. All documented in **[API.md § Known issues](API.md#known-issues)**.
