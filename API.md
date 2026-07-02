# API Reference

Base URL (local): `http://localhost:8000`

Go/Gin + MongoDB e-commerce API. Routes are registered in [`main.go`](main.go); handlers live in [`controllers/`](controllers).

## Authentication

Protected routes require a header literally named **`token`** (not the standard `Authorization: Bearer ...`):

```
token: <JWT>
```

The JWT is obtained from the `token` field returned by `POST /users/signup` or `POST /users/login`. It's HMAC-SHA256 signed using the `SECRET_LOVE` env var, expires in 24h, and carries `Email`, `First_Name`, `Last_Name`, `Uid` claims. A `Refresh_Token` (7-day expiry, no claims populated) is also returned but no endpoint here consumes it.

Missing/invalid token → **HTTP 500** (not 401 — see [Known issues](#known-issues)) with `{"error": "..."}`.

Middleware: [`middleware/middleware.go`](middleware/middleware.go). Because it's registered with `router.Use()` partway through `main.go`, everything registered *before* it (the "Public" section below) is unauthenticated, and everything after requires the token.

---

## Public endpoints

### `POST /users/signup`
Source: `controllers/controllers.go:45`

**Headers:** `Content-Type: application/json`

**Body:**
| Field | Type | Required |
|---|---|---|
| `first_name` | string | yes, 2–30 chars |
| `last_name` | string | yes, 2–30 chars |
| `password` | string | yes, min 6 chars |
| `email` | string | yes, valid email |
| `phone` | string | yes |

```json
{
  "first_name": "Ada",
  "last_name": "Lovelace",
  "password": "secret123",
  "email": "ada@example.com",
  "phone": "1234567890"
}
```

**Response:**
- `201` — `"Successfully Signed Up!!"`
- `400` — `{"error": "<bind or validation error>"}`, or `{"error": "Phone is already in use"}`
- `500` — `{"error": "<db error>"}`

---

### `POST /users/login`
Source: `controllers/controllers.go:103`

**Headers:** `Content-Type: application/json`

**Body:**
```json
{ "email": "ada@example.com", "password": "secret123" }
```

**Response:** `302 Found` (not `200` — see [Known issues](#known-issues)) with the full user document, including the password hash:
```json
{
  "_id": "6a46402f7ba7f0d8f08ad543",
  "first_name": "Ada",
  "last_name": "Lovelace",
  "password": "$2a$14$p6ZJV2fM0ZLpD3znfBUDqeq2zde2NnrsIgr8MB0lDI6Kbl7fI6DWy",
  "email": "ada@example.com",
  "phone": "1234567890",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "Refresh_Token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "created_at": "2026-07-02T10:40:47Z",
  "updtaed_at": "2026-07-02T10:40:47Z",
  "user_id": "6a46402f7ba7f0d8f08ad543",
  "usercart": [],
  "address": [],
  "orders": []
}
```
Note the field is `Refresh_Token` (capitalized) and `updtaed_at` (typo) — both are struct-tag typos in [`models/models.go`](models/models.go), not documentation errors.

- `500` — `{"error": "login or password incorrect"}` (no such email), or `{"error": "Login Or Passowrd is Incorerct"}` (wrong password)

---

### `POST /admin/addproduct`
Source: `controllers/controllers.go:134`. Despite the path, **not** auth-protected (see [Known issues](#known-issues)).

**Headers:** `Content-Type: application/json`

**Body** (no server-side validation — all fields optional in practice):
| Field | Type |
|---|---|
| `product_name` | string |
| `price` | uint64 |
| `rating` | uint8 |
| `image` | string |

```json
{ "product_name": "Wireless Headphones", "price": 2999, "rating": 4, "image": "headphones.jpg" }
```

**Response:**
- `200` — `"Successfully added our Product Admin!!"`
- `400` — `{"error": "<bind error>"}`
- `500` — `{"error": "Not Created"}`

---

### `GET /users/productview`
Source: `controllers/controllers.go:154`. Lists every product, no pagination.

**Response:** `200` — array of products:
```json
[
  { "Product_ID": "6a4640e37ba7f0d8f08ad544", "product_name": "Wireless Headphones", "price": 2999, "rating": 4, "image": "headphones.jpg" }
]
```
Note `Product_ID` (capitalized, no underscore-json-tag) — matches `models.Product`.

---

### `GET /users/search`
Source: `controllers/controllers.go:184`. Regex search on `product_name`.

**Query params:** `name` (required)

`GET /users/search?name=headphones`

**Response:**
- `200` — array of products (same shape as `productview`)
- `404` — `{"Error": "Invalid Search Index"}` if `name` is missing (note capital `Error` key — inconsistent with other endpoints)

---

### `GET /products/:id/image`
Source: `controllers/controllers.go` (`GetProductImage`). Looks up a product and `302`-redirects to its `image` URL, instead of exposing the raw (e.g. Cloudinary) URL directly.

This app doesn't handle image uploads at all — there's no `POST` endpoint for images. Product images are expected to already be hosted somewhere (Cloudinary, etc.); you upload them there yourself and pass the resulting URL as the `image` field on `POST /admin/addproduct`. This endpoint is purely `GET`: a stable link you can put in an `<img src>` that redirects to wherever the image actually lives.

`GET /products/<productID>/image`

**Response:**
- `302` — `Location: <the product's image URL>`, empty-ish HTML body (standard Go `http.Redirect` behavior)
- `400` — `{"error": "invalid product id"}` if the id isn't a valid ObjectID
- `404` — `{"error": "product not found"}` or `{"error": "no image set for this product"}`

---

## Protected endpoints
All require the `token` header described above. None of them actually scope data to the token's `Uid` claim — they trust whatever id you pass in the query string (see [Known issues](#known-issues)).

### `GET /addtocart`
Source: `controllers/cart.go:31`

**Query params:** `id` (product ObjectID hex), `userID` (user ObjectID hex)

`GET /addtocart?id=<productID>&userID=<userID>`

**Response:** `200` — `"Successfully Added to the cart"` · `400` (empty body) if a param is missing

---

### `GET /removeitem`
Source: `controllers/cart.go:62`

**Query params:** `id` (product ObjectID), `userID` (user ObjectID)

**Response:** `200` — `"Successfully removed from cart"`

---

### `GET /listcart`
Source: `controllers/cart.go:95`

**Query params:** `id` (user ObjectID)

**Response:** `200` — writes the cart total (number) followed by the cart items array as two separate JSON payloads on the same response (see [Known issues](#known-issues)) · `404` — `{"error": "invalid id"}` if `id` missing · `500` — `"not id found"`

---

### `POST /addaddress`
Source: `controllers/address.go:17`. Limited to 2 addresses per user.

**Query params:** `id` (user ObjectID)

**Body:**
```json
{ "house_name": "221B", "street_name": "Baker St", "city_name": "London", "pin_code": "NW16XE" }
```

**Response:** `200` with **empty body** on success (no confirmation message is written) · `404` — `{"error": "Invalid code"}` if `id` missing · `400` — `"Not Allowed "` if the user already has 2 addresses

---

### `PUT /edithomeaddress`
Source: `controllers/address.go:72`. Overwrites address index `0`.

**Query params:** `id` (user ObjectID)
**Body:** same shape as `addaddress`

**Response:** `200` — `"Successfully Updated the Home address"` · `404` — `{"Error": "Invalid"}` · `500` — `"Something Went Wrong"`

---

### `PUT /editworkaddress`
Source: `controllers/address.go:104`. Overwrites address index `1` — requires the user already has a 2nd address (added via `addaddress`).

**Query params:** `id` (user ObjectID)
**Body:** same shape as `addaddress`

**Response:** `200` — `"Successfully updated the Work Address"` · `404` — `{"Error": "Wrong id not provided"}` · `500` — `"something Went wrong"`

---

### `GET /deleteaddresses`
Source: `controllers/address.go:136`. **Deletes all addresses**, not one (`GET` used for a destructive op — see [Known issues](#known-issues)).

**Query params:** `id` (user ObjectID)

**Response:** `200` — `"Successfully Deleted!"` · `404` — `{"Error": "Invalid Search Index"}` or `"Wromg"`

---

### `GET /cartcheckout`
Source: `controllers/cart.go:138`. Moves the entire cart into a new order (`payment_method.cod = true`), then empties the cart.

**Query params:** `id` (user ObjectID)

**Response:** `200` — `"Successfully Placed the order"`

⚠️ If `id` is omitted, this handler calls `log.Panicln` and **the whole server process crashes** — `main.go` uses `gin.New()`, which has no panic-recovery middleware. See [Known issues](#known-issues).

---

### `GET /instantbuy`
Source: `controllers/cart.go:155`. Buys one product directly, bypassing the cart.

**Query params:** `userid`, `pid` (product ObjectID) — note the different param names vs. every other cart endpoint

`GET /instantbuy?userid=<userID>&pid=<productID>`

**Response:** `200` — `"Successully placed the order"` (typo, verbatim)

---

## Known issues

Documented as-observed, not as recommendations to fix blindly — flagging so they don't surprise you as a caller:

- **No panic recovery**: `main.go` uses `gin.New()` instead of `gin.Default()`, so there's no Recovery middleware. Several handlers call `log.Panic`/`panic` on bad input (`cartcheckout`, `addaddress`, `buyfromcart` internals) — hitting those paths kills the whole process, not just the request.
- **Auth check returns 500, not 401**: `middleware/middleware.go` responds `500` for a missing/invalid token instead of `401`.
- **`/admin/addproduct` isn't actually protected** — it's registered before the auth middleware, so no token is required despite the path.
- **No per-user authorization (IDOR)**: cart/address/order endpoints take the target user's id as a plain query param and never check it against the authenticated token's `Uid` claim. Any valid token can act on any user id.
- **`POST /users/signup`** doesn't `return` after the "email already exists" check, so it likely continues on to insert anyway — worth confirming before relying on that check.
- **`GET /deleteaddresses`** uses `GET` for a destructive operation and clears all addresses rather than one.
- **`GET /listcart`** can write two separate JSON bodies to one response (total, then items) inside a loop.
- **Inconsistent query param naming** across cart/address/order endpoints: `id`, `userID`, and `userid` are all used for "user id" depending on the endpoint.
- **Login returns the bcrypt password hash** in the response body.
