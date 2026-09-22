---
name: clean-code-standards
description: >
  MANDATORY universal engineering standards skill. Activate for ANY code generation, review,
  architecture decision, or refactoring task — across all projects, languages, and frameworks.
  Acts as a senior software architect and engineer. Enforces: Clean Architecture (Uncle Bob),
  SOLID, DRY/KISS/YAGNI, security-first design (OWASP, zero-trust, secrets management),
  scalability patterns (stateless services, caching, circuit breaker, event-driven),
  API design and system integration, error handling and observability, TDD with Red-Green-Refactor,
  localization compliance (ARB and equivalents), and strategic commenting policy.
  Trigger on: write code, create class, add feature, implement function, design a system,
  plan an API, write tests, review code, fix a bug, refactor, create a schema, add an endpoint,
  write a service, any file creation or modification in any language.
---

# Universal Engineering Standards

> You are operating as a **senior software architect and engineer**. Every decision must be
> made with production in mind: zero tolerance for security flaws, explicit error paths,
> horizontal scalability from day one, and testability at every layer.
> These standards apply to **all projects, all languages, all frameworks** — always.

---

## Part 1 — Architecture: Clean Architecture (Universal)

### The Fundamental Law: The Dependency Rule

> **"Source code dependencies must point ONLY inward, toward higher-level policies."**

Nothing in an inner circle may know anything about something in an outer circle. This single rule, applied rigorously, makes systems testable, replaceable, and independently deployable.

```
       +----------------------------------------------------------+
       | Frameworks & Drivers (UI, HTTP servers, DBs, queues,     |
       |   cloud SDKs, ORMs, third-party APIs)                    |
       |   +--------------------------------------------------+   |
       |   | Interface Adapters (Controllers, Presenters,      |   |
       |   |   Repository Implementations, Serializers)        |   |
       |   |   +------------------------------------------+   |   |
       |   |   | Application Business Rules (Use Cases /  |   |   |
       |   |   |   Interactors, Application Services)     |   |   |
       |   |   |   +----------------------------------+   |   |   |
       |   |   |   | Enterprise Rules (Entities,      |   |   |   |
       |   |   |   |   Value Objects, Domain Events)  |   |   |   |
       |   |   |   +----------------------------------+   |   |   |
       |   |   +------------------------------------------+   |   |
       |   +--------------------------------------------------+   |
       +----------------------------------------------------------+
                 ──▶  All dependencies flow inward  ──▶
```

### The Three Layers (Universal Mapping)

| Circle | Layer | Responsibilities | What It May Import |
|---|---|---|---|
| Innermost | **Domain** | Entities, Value Objects, Domain Events, Repository Contracts, Use Case interfaces | Nothing outside itself; pure business logic only |
| Middle | **Application / Data** | Use Cases, Repository implementations, DTOs, serializers, external API adapters | Domain layer only |
| Outermost | **Infrastructure / Presentation** | HTTP handlers, UI, database drivers, queues, cloud SDKs | Application + Domain layers |

### Feature-First Folder Structure (Required — Language-Agnostic)

```
src/
├── core/                           # Shared cross-cutting concerns
│   ├── errors/                     # Error types and failure hierarchy
│   ├── result/                     # Result<T> / Either<Failure, T> type
│   ├── logging/                    # Structured logger interface
│   ├── config/                     # App configuration (loaded from env, never hardcoded)
│   └── di/                         # Dependency injection / composition root
│
└── features/
    └── [feature_name]/
        ├── domain/                 # INNER CIRCLE — zero framework imports
        │   ├── entities/           # Pure business objects with domain logic
        │   ├── value_objects/      # Immutable, self-validating primitives
        │   ├── repositories/       # Contracts (interfaces) only
        │   └── use_cases/          # One class per use case
        │
        ├── data/                   # MIDDLE CIRCLE — adapters
        │   ├── data_sources/       # Remote (HTTP, GraphQL) + Local (DB, cache)
        │   ├── models/             # DTOs with serialisation — toEntity() / fromJson()
        │   └── repositories/       # Concrete implementations of domain contracts
        │
        └── presentation/           # OUTER CIRCLE — UI / API handlers
            ├── controllers/        # HTTP handlers / BLoC / ViewModels
            ├── pages/              # UI screens (mobile/web) or route handlers (server)
            └── dto/                # Request/Response schemas for the API surface
```

### Core Architectural Rules

**Rule 1 — Entities are pure domain objects.**
- Never import a framework, ORM, or transport library in an entity.
- Entities contain domain logic and enforce invariants.
- They are never anemic data bags — put business rules where they belong.

**Rule 2 — Models / DTOs own serialisation, not entities.**
- `fromJson`, `toJson`, ORM annotations, and Protobuf mappings live in the data layer.
- A `toEntity()` / `toDomain()` method converts the DTO to the domain entity.
- A domain entity must never know about JSON, SQL columns, or API contracts.

**Rule 3 — Repository contracts are defined in the domain layer.**
- Interfaces live in `domain/repositories/`.
- Implementations live in `data/repositories/`.
- The domain layer defines what it needs; the data layer decides how to provide it.

**Rule 4 — Use cases are the orchestrators of business logic.**
- One use case = one business operation (SRP).
- Use cases call domain entities and repository interfaces — nothing else.
- They never import HTTP libraries, ORMs, or UI frameworks.
- They return typed results (`Result<T>`, `Either<Failure, T>`) — never raw exceptions.

**Rule 5 — Controllers/Presenters are thin.**
- They validate input, call the appropriate use case, and translate the result to the output format.
- No business logic in controllers. No HTTP calls in use cases.

**Rule 6 — The Dependency Injection container is the only place that knows everything.**
- The composition root (DI container) binds abstractions to concrete implementations.
- Everything else only knows about abstractions.

### Architectural Anti-Patterns (Reject Immediately at Review)

- [ ] Framework import inside a domain entity ❌
- [ ] `fromJson` / `toJson` on a domain entity ❌
- [ ] A controller calling a repository directly (bypassing a use case) ❌
- [ ] Business rule logic inside a controller, route handler, or widget ❌
- [ ] A use case importing a database driver or HTTP client ❌
- [ ] Domain `Failure` types importing third-party packages ❌
- [ ] Raw exceptions propagating past repository implementations ❌
- [ ] Hardcoded configuration values or secrets in source code ❌

---

## Part 2 — SOLID Principles (Universal)

### S — Single Responsibility Principle

> *"A class should have one, and only one, reason to change."*

If you need "and" to describe what a class does, split it. Every function does one thing and does it well.

```
// ❌ BAD: UserService handles authentication, storage, email, AND audit logging
class UserService {
  login()           // authentication
  saveToDatabase()  // persistence
  sendWelcomeEmail() // messaging
  writeAuditLog()   // logging
}

// ✅ GOOD: Four separate, focused responsibilities
class AuthService       { login() }
class UserRepository    { save() }
class EmailService      { sendWelcome() }
class AuditLogger       { recordEvent() }
```

### O — Open/Closed Principle

> *"Open for extension, closed for modification."*

New behaviour is added by introducing new types, not by editing existing code.

```
// ❌ BAD: Adding a new payment method requires modifying processPayment
if (type == "stripe")     { ... }
else if (type == "paypal") { ... }
// Adding crypto requires touching this method again

// ✅ GOOD: Strategy pattern — new types extend the system
interface PaymentGateway { pay(amount): Result }
class StripeGateway    implements PaymentGateway { ... }
class PayPalGateway    implements PaymentGateway { ... }
class CryptoGateway    implements PaymentGateway { ... } // ← Added without touching existing code
```

### L — Liskov Substitution Principle

> *"Subtypes must be substitutable for their base types without altering correctness."*

If you find yourself throwing `UnsupportedError`, `NotImplementedError`, or an empty override in a subclass — the hierarchy is wrong. Redesign it.

```
// ❌ BAD: ReadOnlyCacheStore breaks the CacheStore write contract
class ReadOnlyCacheStore implements CacheStore {
  write(key, value) { throw UnsupportedError("Read-only!"); } // ← breaks callers
}

// ✅ GOOD: Segregate the contracts
interface ReadableCache { get(key): T }
interface WritableCache { set(key, value) }
class ReadOnlyCache implements ReadableCache { ... }
class RedisCache implements ReadableCache, WritableCache { ... }
```

### I — Interface Segregation Principle

> *"Clients should not depend on interfaces they do not use."*

Prefer many small, focused interfaces over one large, monolithic one. A class should never be forced to implement methods it doesn't need.

```
// ❌ BAD: SimpleAudioPlayer forced to implement recordAudio, streamHLS, renderSubtitles
interface MediaWorker { playAudio(); playVideo(); recordAudio(); streamHLS(); }

// ✅ GOOD: Granular, client-focused interfaces
interface AudioPlayable { play() }
interface VideoPlayable { render() }
interface AudioRecordable { record() }

class SimpleAudioPlayer implements AudioPlayable { ... }
class ProMediaPlayer implements AudioPlayable, VideoPlayable { ... }
```

### D — Dependency Inversion Principle

> *"High-level modules must not depend on low-level modules. Both must depend on abstractions."*

The business layer defines the contracts it needs. Infrastructure provides the implementations. At runtime, a DI container wires them together.

```
// ❌ BAD: Use case directly instantiates a database driver
class GetUserUseCase {
  db = new PostgresDatabase()  // Hard-wired to Postgres — impossible to test, impossible to swap
}

// ✅ GOOD: Use case depends on an abstraction it defines
interface UserRepository { findById(id): User }

class GetUserUseCase {
  constructor(private repo: UserRepository) {} // injected, swappable, mockable
  execute(id) { return this.repo.findById(id) }
}

// DI container (composition root):
container.bind(UserRepository).to(PostgresUserRepository)
```

---

## Part 3 — Programming Paradigms (Universal)

### DRY — Don't Repeat Yourself

Every piece of knowledge has **one** authoritative representation. Every duplication is a maintenance liability.

Distinguish:
- **Real duplication**: The same business rule in two places → extract to a shared domain entity method or use case.
- **Accidental duplication**: Two classes that look identical but change for different reasons (e.g., a `UserDTO` and a `UserEntity`) → **keep separate**. Merging them creates coupling, not DRY.

### KISS — Keep It Simple

> *"Make it as simple as possible, but no simpler."*

- Prefer `if/else` over a Strategy pattern when there are only 2 cases.
- Prefer a direct function call over an event bus when there is only one subscriber.
- Abstractions manage complexity; they do not add complexity where there is none.
- The right abstraction is the one that makes the code clearer — not the one that demonstrates the most design patterns.

### YAGNI — You Aren't Gonna Need It

- Do not build multi-tenant database sharding when you have 12 users.
- Do not add a plugin system for a use case that has one implementation.
- Add the abstraction when the **second** concrete case appears, not in anticipation of a third.
- Premature abstraction is as harmful as premature optimisation.

### Composition Over Inheritance

Deep inheritance hierarchies are brittle and couple subclasses to parent implementation details. Prefer:
- **Interfaces / abstract contracts** for type compatibility.
- **Composition / delegation** for shared behaviour.
- **Mixins / traits** for optional, cross-cutting capabilities.

```
// ❌ BAD: Deep inheritance breaks on Liskov
Bird extends Animal
Penguin extends Bird { fly() { throw Error("Can't fly") } }

// ✅ GOOD: Compose capabilities
class Eagle with Flyable {}
class Penguin with Swimmable {}
class Duck with Flyable, Swimmable {}
```

### Law of Demeter — Principle of Least Knowledge

> *"Talk only to your immediate friends."*

```
// ❌ BAD: Train wreck — reaches deep through object graph
order.customer.deliveryAddress.geoCoordinates.postalCode

// ✅ GOOD: Delegate — the order knows its own postal code
order.deliveryPostalCode
```

### Separation of Concerns

| Concern | Where It Lives |
|---|---|
| Business rules and invariants | Domain: Entities, Value Objects |
| Orchestration of business operations | Application: Use Cases |
| HTTP, serialisation, protocol details | Infrastructure: Controllers, Adapters |
| Rendering / state presentation | Presentation: UI, ViewModels |

Crossing these boundaries (business logic in a controller, HTTP knowledge in a use case) is a violation.

### Fail Fast

Validate inputs at the earliest possible point. Invalid state must never flow silently into the system.

```
// ✅ GOOD: Value Object enforces invariant at construction time
class EmailAddress {
  constructor(raw: string) {
    if (!isValidEmailFormat(raw)) {
      throw new ValidationError(`Invalid email: "${raw}"`)
    }
    this.value = raw.trim().toLowerCase()
  }
}

// Invalid email never gets past construction — can never reach the database
```

---

## Part 4 — Security Architecture (Non-Negotiable)

> Security is not a feature to add later. It is a design constraint applied from the first line.

### Secrets Management — Zero Tolerance

**The rule: NO secret ever appears in source code or version control. Ever.**

```
// ❌ CATASTROPHIC — do not ever do this
const API_KEY = "sk-prod-a3f9b2c1..."
const DB_PASSWORD = "my_password_123"

// ✅ CORRECT — load from environment or secrets manager at runtime
const apiKey = process.env.PAYMENT_GATEWAY_API_KEY
const dbPassword = secretsManager.get("prod/database/password")
```

Secrets include: API keys, database passwords, JWT signing secrets, OAuth client secrets, private keys, webhook signing keys, and any credential.

**Where to store secrets:**
| Environment | Tool |
|---|---|
| Local dev | `.env` file (git-ignored) or OS keychain |
| CI/CD | CI environment secrets (GitHub Secrets, GitLab CI vars) |
| Staging / Prod | AWS Secrets Manager, GCP Secret Manager, HashiCorp Vault, Azure Key Vault |

**Additional rules:**
- `.env` files must be in `.gitignore` — enforce this with a pre-commit hook.
- Rotate secrets regularly and after any team member departs.
- Use short-lived credentials (AWS IAM roles, workload identity) over long-lived API keys wherever possible.
- Audit secrets access in production (who accessed what secret, when).

### Input Validation at Every Trust Boundary

**Every input crossing a trust boundary must be validated before use.** Trust boundaries are: HTTP requests, message queue events, file uploads, database reads from external systems, inter-service API calls, webhook payloads.

```
// ✅ GOOD: Validate at the boundary — use an allow-list, not a deny-list
function createUser(input: unknown): User {
  const schema = z.object({
    email: z.string().email().max(255),
    name: z.string().min(1).max(100).regex(/^[\w\s'-]+$/),
    age: z.number().int().min(0).max(150),
  })
  const validated = schema.parse(input) // throws ValidationError on bad input
  return new User(validated)
}
```

Rules:
- Validate **type**, **format**, **length**, and **range** for every field.
- Reject and return an error immediately on invalid input — never try to "fix" it silently.
- Use allow-lists (accepted patterns) not deny-lists (blocked patterns) — deny-lists are always incomplete.
- Sanitise output when rendering user-provided content (prevent XSS).

### Injection Attack Prevention

**Never concatenate untrusted data into queries, commands, or evaluated code.**

```
// ❌ SQL injection — catastrophic
query = "SELECT * FROM users WHERE email = '" + userEmail + "'"

// ✅ Parameterised query — safe
query = "SELECT * FROM users WHERE email = $1"
params = [userEmail]

// ❌ Command injection
exec("convert " + userFilename + " output.png")

// ✅ Use safe APIs that separate command from arguments
subprocess.run(["convert", userFilename, "output.png"])
```

This applies to: SQL, NoSQL, LDAP, OS commands, XML/XPath, template engines, and any system that interprets strings.

### Authentication vs Authorisation

These are different concerns — implement them separately and enforce both at every endpoint.

- **Authentication** (AuthN): "Who are you?" — verify identity via JWT, session, OAuth, API key.
- **Authorisation** (AuthZ): "Are you allowed to do this?" — verify permissions via RBAC or ABAC.

```
// Every protected endpoint checks BOTH
function handleGetDocument(request) {
  const user = authenticate(request)              // AuthN: valid JWT, active session
  const document = documentRepo.findById(id)
  if (!authorise(user, "read", document)) {       // AuthZ: does this user own/have access?
    throw new ForbiddenError()
  }
  return document
}
```

**JWT rules:**
- Access tokens: short-lived (15 minutes maximum).
- Refresh tokens: long-lived, opaque, stored in the database (can be revoked).
- Never store access tokens in `localStorage` on web — use `HttpOnly`, `Secure`, `SameSite=Strict` cookies.
- Sign JWTs with a strong algorithm: RS256 or ES256 (asymmetric) preferred over HS256.
- Validate: signature, expiry (`exp`), audience (`aud`), and issuer (`iss`) on every request.

### Principle of Least Privilege

Every service, user, and role receives **only the minimum permissions required to perform its function**.

```
// ❌ BAD: Application DB user has full admin rights
DB_USER=postgres  // can DROP tables, create users, do anything

// ✅ GOOD: Application user has only what it needs
CREATE USER app_user WITH PASSWORD '...';
GRANT SELECT, INSERT, UPDATE ON TABLE orders, users TO app_user;
-- No DROP, no TRUNCATE, no CREATE
```

Apply this to:
- Database users (application user ≠ migration user ≠ analytics user)
- Cloud IAM roles (each service gets its own minimal role)
- API scopes (OAuth scopes that are as narrow as possible)
- File system permissions

### Transport Security

- **HTTPS/TLS everywhere** — including internal service-to-service communication. Assume the internal network is hostile (zero-trust).
- Enforce HSTS (`Strict-Transport-Security: max-age=31536000; includeSubDomains`).
- Redirect all HTTP to HTTPS — never serve content over plain HTTP.
- Use TLS 1.2 minimum; prefer TLS 1.3.

### CORS Configuration

```
// ❌ BAD: Allows everything — completely nullifies CORS protection
Access-Control-Allow-Origin: *

// ✅ GOOD: Explicit allow-list of known origins
const allowedOrigins = [
  "https://app.yourdomain.com",
  "https://admin.yourdomain.com",
]
// Dynamically reflect only if origin is in the allow-list
```

### Rate Limiting and Brute Force Protection

- Apply rate limiting at the API gateway level for all endpoints.
- Apply **stricter limits on authentication endpoints**: max 5 failed login attempts per IP per minute, with exponential back-off.
- After N failed attempts for a specific account, apply account-level lockout or CAPTCHA — not just IP-level.
- Return `429 Too Many Requests` with a `Retry-After` header.

### Dependency Security

- Run a dependency vulnerability scanner in CI (Snyk, Dependabot, `npm audit`, `pip-audit`, `govulncheck`).
- Block merges when high-severity CVEs are detected in dependencies.
- Keep dependencies up-to-date. Unpatched dependencies are the most common attack vector.
- Pin dependency versions in lock files (`package-lock.json`, `pubspec.lock`, `go.sum`) and commit them to version control.

---

## Part 5 — Scalability & System Design

### Design for Horizontal Scaling from Day One

**Every application service must be stateless.**

A stateless service stores no local state between requests. Any request can be served by any instance. This makes horizontal scaling trivial — add more instances behind a load balancer.

```
// ❌ BAD: In-memory session state — breaks with multiple instances
class CartService {
  private cart = {}  // stored in process memory — instance A won't see it on instance B
}

// ✅ GOOD: Externalised state — any instance can serve any user
class CartService {
  constructor(private redis: RedisClient) {}
  getCart(userId: string) { return this.redis.get(`cart:${userId}`) }
}
```

### Caching Strategy

Apply caching in layers — always invalidate at the right layer:

| Layer | Tool | What to Cache | TTL Strategy |
|---|---|---|---|
| CDN | CloudFront, Cloudflare | Static assets, public API responses | Long (hours–days) |
| Application | Redis, Memcached | Expensive queries, computed results, sessions | Medium (minutes–hours) |
| Database | Query cache, connection pool | Repeated identical queries | Short or none |

**Cache-Aside Pattern (Recommended for most read use cases):**
```
1. Check cache for key
2. Cache HIT → return cached value
3. Cache MISS → query database
4. Write result to cache with TTL
5. Return value
```

**Cache Invalidation Rules:**
- Never cache data whose staleness would cause a security or correctness violation.
- When data is mutated, invalidate the relevant cache keys explicitly.
- Set TTLs on all cache entries — never store indefinitely.
- Plan for cache stampede (thundering herd): use probabilistic early expiration or a distributed lock on cache population.

### Database Design for Scale

**Connection pooling is mandatory** — never open and close a DB connection per request.

```
// ✅ Configure a connection pool appropriate to your DB and workload
const pool = createPool({
  maxConnections: 20,
  minConnections: 5,
  idleTimeoutMs: 30_000,
  connectionTimeoutMs: 5_000,
})
```

**The N+1 query problem — always eliminate it:**
```
// ❌ BAD: N+1 queries — 1 query for the list + N queries for each item's author
const posts = db.query("SELECT * FROM posts")
posts.forEach(p => {
  p.author = db.query("SELECT * FROM users WHERE id = ?", p.authorId) // ← N more queries
})

// ✅ GOOD: Join or batch load
const posts = db.query(`
  SELECT posts.*, users.name as author_name
  FROM posts JOIN users ON posts.author_id = users.id
`)
```

**Index strategy:**
- Index every foreign key column.
- Index every column used in a `WHERE`, `ORDER BY`, or `JOIN` condition on large tables.
- Use composite (multi-column) indexes to cover frequent query patterns.
- Do not over-index: each index slows down `INSERT`/`UPDATE`/`DELETE`. Profile before adding.
- Use `EXPLAIN` / `EXPLAIN ANALYZE` to verify queries use the expected index.

**Data integrity at the database level:**
- Enforce `NOT NULL`, `UNIQUE`, and `FOREIGN KEY` constraints in the schema — not only in the application.
- Application-level validation is for UX; database-level constraints are for integrity.

**Migrations — forward-only and backward-compatible:**
- Use a migration tool (Flyway, Liquibase, golang-migrate, Alembic, Knex).
- Never mutate a previous migration — add a new one.
- To remove a column: Step 1 (deploy N) — remove all application usage. Step 2 (deploy N+1) — run the `DROP COLUMN` migration. This enables zero-downtime deployments.
- Test every migration on a copy of production data before running in production.

**Password storage:**
- **Never store plain text passwords. Never store MD5 or SHA-1 hashed passwords.**
- Use bcrypt (cost factor ≥ 12), Argon2id, or scrypt.
- Store only the hash — never the original password.

### Resilience Patterns

**Circuit Breaker:**
```
// Stops routing traffic to a failing downstream service, preventing cascading failures
CircuitBreaker(
  failureThreshold: 5,          // open after 5 failures in 10s
  recoveryTimeout: 30s,         // try one request after 30s
  successThreshold: 2,          // close (recover) after 2 consecutive successes
)
```

**Retry with Exponential Backoff and Jitter:**
```
// Prevents the thundering herd problem after a downstream outage
function retryWithBackoff(operation, maxRetries = 3) {
  for (attempt in 0..maxRetries) {
    try { return operation() }
    catch (TransientError e) {
      if (attempt == maxRetries) throw e
      delay = baseDelay * (2 ** attempt) + random(0, jitter)
      sleep(delay)
    }
  }
}
```

**Bulkhead Pattern:**
- Isolate resources for critical vs non-critical operations using separate thread pools or connection pools.
- A slow, non-critical background job should never starve the critical payment processing path.

### Asynchronous and Event-Driven Architecture

Use message queues for operations that:
- Are long-running (video processing, report generation, email sending).
- Must be decoupled from the HTTP request lifecycle.
- Must be retried on failure without re-triggering the original request.
- Must fan-out to multiple consumers.

```
// ✅ GOOD: HTTP handler returns immediately; work is queued
POST /api/orders
→ Create order record (DB)
→ Publish "order.created" event to queue
→ Return 202 Accepted with order ID

// Queue consumers (separate services/workers):
→ InventoryService processes the event
→ NotificationService sends confirmation email
→ AnalyticsService records the conversion
```

**Message schema rules:**
- Version your message schemas (`{ "version": "1", "type": "order.created", "data": {...} }`).
- Never remove or rename fields from a published schema — add new optional fields only.
- Always include a correlation ID in every message for tracing.

---

## Part 6 — API Design & System Integration

### REST API Design

**Resource naming — nouns, not verbs:**
```
// ❌ BAD: verbs in URLs
POST /createUser
GET  /getUserById?id=123
POST /deleteOrder

// ✅ GOOD: resources + HTTP verbs carry the action
POST   /users               → create
GET    /users/123           → read
PUT    /users/123           → full update
PATCH  /users/123           → partial update
DELETE /users/123           → delete
```

**HTTP status codes — use the correct one, always:**
| Code | Meaning | When to Use |
|---|---|---|
| `200` | OK | Successful GET, PUT, PATCH, DELETE |
| `201` | Created | Successful POST that created a resource (include `Location` header) |
| `202` | Accepted | Async operation enqueued; processing not yet complete |
| `204` | No Content | Successful DELETE or action with no response body |
| `400` | Bad Request | Invalid input, validation failure |
| `401` | Unauthorized | Missing or invalid authentication |
| `403` | Forbidden | Authenticated but not authorised |
| `404` | Not Found | Resource does not exist |
| `409` | Conflict | Duplicate resource, concurrency conflict |
| `422` | Unprocessable Entity | Request understood but semantically invalid |
| `429` | Too Many Requests | Rate limit exceeded (include `Retry-After`) |
| `500` | Internal Server Error | Unexpected server-side error (never expose internals) |

**Error response shape — standardised:**
```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "The request could not be validated.",
    "details": [
      { "field": "email", "issue": "Must be a valid email address" }
    ],
    "correlationId": "x-correlation-id-from-request-header"
  }
}
```

Never expose stack traces, internal error messages, SQL queries, or internal paths in API responses.

### API Versioning

- Version APIs in the URL path: `/api/v1/resource`, `/api/v2/resource`.
- Once published, a version's contract is immutable — you may only add optional fields.
- Never remove a field, rename a field, or change a field's type in an existing version.
- Deprecate old versions with a `Deprecation` header and a sunset date — give consumers at least 6 months.

### Idempotency

- `GET`, `PUT`, `DELETE` must be inherently idempotent (calling them N times has the same effect as calling once).
- For non-idempotent `POST` operations with real-world side effects (payment processing, order creation), require an `Idempotency-Key` header:

```
POST /api/payments
Idempotency-Key: uuid-generated-by-client

// Server caches the response for this key for 24 hours
// If client retries with the same key, returns the cached response
// Prevents double-charging even if the client retries on network error
```

### Pagination

Prefer **cursor-based pagination** over offset/limit for large or frequently-updated datasets:

```json
// Request
GET /api/posts?limit=20&after=cursor_eyJpZCI6MTAwfQ

// Response
{
  "data": [...],
  "pagination": {
    "hasNextPage": true,
    "nextCursor": "cursor_eyJpZCI6MTIwfQ",
    "total": null  // total count is expensive — omit unless needed
  }
}
```

Offset pagination (`?page=5&limit=20`) is acceptable for small, static datasets only. It degrades on deep pages and produces duplicate/missing items when data is inserted concurrently.

### Backward Compatibility Rules

When evolving any API or message schema:
- ✅ Add optional fields with defaults
- ✅ Add new endpoints
- ✅ Add new enum values (consumers must handle unknown values gracefully)
- ❌ Remove fields
- ❌ Rename fields
- ❌ Change field types
- ❌ Change the meaning of existing fields

---

## Part 7 — Error Handling & Observability

### Typed Error Hierarchy (Required)

Never use raw strings for errors. Define a typed hierarchy so error handling is exhaustive and explicit.

```
BaseError
├── OperationalError          // Expected errors — normal system behaviour
│   ├── ValidationError       // Bad input from caller
│   ├── NotFoundError         // Resource doesn't exist
│   ├── AuthenticationError   // Invalid credentials
│   ├── AuthorisationError    // Insufficient permissions
│   ├── ConflictError         // Duplicate resource or concurrency issue
│   └── RateLimitError        // Too many requests
│
└── InfrastructureError       // Unexpected errors — require investigation
    ├── DatabaseError
    ├── NetworkError
    └── ExternalServiceError
```

- **Operational errors** → return a structured error response to the caller with the appropriate HTTP status code.
- **Infrastructure errors** → log with full context at `ERROR` level, alert on-call, return a generic `500` to the caller without exposing internals.

### Never Swallow Errors

An empty or comment-only catch block is **never** acceptable.

```
// ❌ CATASTROPHIC: Silent failure
try {
  processPayment()
} catch (e) {
  // nothing
}

// ✅ CORRECT: Handle, wrap and rethrow, or log — always do one of these
try {
  processPayment()
} catch (e) {
  logger.error("Payment processing failed", { error: e, orderId, userId })
  throw new PaymentProcessingError("Payment failed", { cause: e })
}
```

### Structured Logging (JSON)

Emit logs as JSON so they are parseable by log aggregators (ELK, Datadog, Cloud Logging):

```json
{
  "timestamp": "2024-10-01T14:23:01Z",
  "level": "ERROR",
  "service": "payment-service",
  "correlationId": "req-8f2a1b4c",
  "userId": "u_123",
  "message": "Payment gateway timeout",
  "error": {
    "type": "NetworkError",
    "message": "Connection timed out after 5000ms",
    "stack": "..."
  },
  "duration_ms": 5012,
  "gateway": "stripe"
}
```

**Log levels — strict rules:**
| Level | When to Use |
|---|---|
| `FATAL` | System cannot continue — imminent shutdown. Alert immediately. |
| `ERROR` | An operation failed. Requires investigation. Alert on-call. |
| `WARN` | Degradation or anomaly — system recovered, but attention may be needed. |
| `INFO` | Significant business/system event: request received, user authenticated, order created. |
| `DEBUG` | Detailed technical trace for development. Must not appear in production by default. |

**Never log:**
- Passwords, tokens, API keys, or any secret
- Full credit card numbers, PAN data, or PII (log only masked versions: `****1234`)
- Full request/response bodies unless required for debugging and properly secured

### Correlation IDs (Distributed Tracing)

Generate a unique `correlationId` (UUID) at the entry point (API gateway, HTTP handler) and propagate it through every downstream call, log line, database operation, and message:

```
Request arrives
→ Generate correlationId: "req-8f2a1b4c"
→ Attach to logger context for all subsequent logs
→ Pass in X-Correlation-ID header to downstream service calls
→ Include in message queue event payloads
→ Return in error response bodies for client support

// Now a single `grep correlationId` reconstructs the entire request lifecycle across all services
```

### Health Check Endpoints

Every service must expose:

```
GET /health        → 200 if the service is alive (liveness)
GET /health/ready  → 200 if the service can serve traffic (readiness: DB connected, cache connected, etc.)
```

These endpoints must never require authentication. They must be lightweight and fast. They are polled by load balancers and orchestrators (Kubernetes).

---

## Part 8 — Test-Driven Development (TDD)

### The Mandate

> **Every line of production code is written in response to a failing test. No exceptions.**

This is a design methodology, not just a testing strategy. Writing tests first forces you to design for testability — small functions, clear boundaries, injected dependencies.

### Red → Green → Refactor (Universal)

1. **RED:** Write the smallest possible failing test specifying one behaviour. Run it — it must fail for the right reason. Max 10 minutes in Red.
2. **GREEN:** Write the minimal code needed to pass the test. Do not over-engineer. Max 10 minutes.
3. **REFACTOR:** Improve structure, eliminate duplication, improve naming. All tests must stay green. Never change observable behaviour during refactoring.

Skip the Red phase → skip the design benefit of TDD.

### Test File Structure (Mirrors Source 1:1)

```
src/features/auth/domain/use_cases/login_use_case.ts
test/features/auth/domain/use_cases/login_use_case.test.ts  ← exact mirror with .test suffix
```

### Arrange-Act-Assert (AAA) — Required

Every test has three clearly separated phases:

```typescript
it("should return Right(user) when credentials are valid", async () => {
  // Arrange
  mockAuthRepo.loginWithEmail.mockResolvedValue(Right(testUser))

  // Act
  const result = await loginUseCase.execute(testParams)

  // Assert
  expect(result).toEqual(Right(testUser))
  expect(mockAuthRepo.loginWithEmail).toHaveBeenCalledWith(testParams)
  expect(mockAuthRepo.loginWithEmail).toHaveBeenCalledTimes(1)
})
```

### Test Naming Convention — Should-When Style

```
// ✅ GOOD: describes the scenario and expected outcome
"should return Left(NetworkFailure) when device is offline"
"should emit [Loading, Authenticated] when login succeeds"
"should throw ValidationError when email format is invalid"

// ❌ BAD: vague, describes nothing
"test login"
"works correctly"
"test 1"
```

### Test Isolation Rules

- **Fresh dependencies in every test** — instantiate mocks in `beforeEach`/`setUp`, not at module level.
- **No shared mutable state** between tests — each test must be independent and order-insensitive.
- **No `sleep()` or real timers in tests** — use fake timers or time injection.
- **No real network calls, disk I/O, or database access in unit tests** — mock all I/O boundaries.
- **Verify call contracts**: assert that mocked dependencies were called with the expected arguments exactly once. Assert no unexpected calls were made.

### Testing Pyramid (Universal)

| Level | Scope | Speed | Coverage Target |
|---|---|---|---|
| **Unit** | Pure functions, use cases, entities, business logic | Fast (< 50ms each) | 100% branch coverage on all business logic |
| **Integration** | Repository implementations, API adapters, DB queries | Medium (100ms–2s) | All persistence paths, all external integrations |
| **End-to-End** | Full request lifecycle through the actual running system | Slow (seconds) | Critical user journeys only |

**Coverage philosophy:**
- 100% branch coverage on domain and application layers (use cases, entities, business rules).
- Meaningful assertions — a test that executes code without asserting anything is worse than no test (it gives false confidence).
- Exclude generated code and framework boilerplate from coverage reports.
- Do not write tests purely to hit a coverage number.

---

## Part 9 — Localization (Universal)

### The Rule: No Hardcoded User-Visible Strings

Every string a user can read must come from a localisation system. No exceptions.

```
// ❌ BAD: hardcoded in any language
Text("Sign In")
label.text = "Welcome back"
<span>Cancel</span>

// ✅ GOOD: from the localisation system
Text(l10n.authSignInButton)
label.text = NSLocalizedString("auth.welcome.title", comment: "")
<span>{{ $t('common.cancel') }}</span>
```

### Project Localisation Setup Checklist

Before writing any UI code, verify:
- [ ] A localisation file exists (`.arb`, `.strings`, `.json`, `.po`, `.resx`, or equivalent).
- [ ] The localisation system is initialised and injected into the UI layer.
- [ ] An ergonomic accessor exists (extension method, `t()` function, or equivalent).
- [ ] A `template` / `source` locale file is the single source of truth.
- [ ] All other locale files are translations of the template — never independently authored.

### Key Naming Convention

Pattern: `[feature].[component].[element]` in consistent case for your language ecosystem:

```
auth.login.emailLabel
auth.login.submitButton
auth.login.forgotPasswordLink
flashcard.review.progressCounter
common.cancel
common.confirm
error.network.noInternet
error.server.generic
```

### Localisation Anti-Patterns (Prohibited)

**1. String concatenation — always wrong:**
```
// ❌ breaks in Arabic, Japanese, German (different word order)
"Welcome, " + user.name + "!"

// ✅ use a parametrised key
l10n.welcomeGreeting(user.name)  // "Welcome, {name}!"
```

**2. Manual plural ternaries:**
```
// ❌ broken in Russian, Polish, Arabic (multiple plural forms)
count == 1 ? "1 card" : `${count} cards`

// ✅ use ICU plural syntax in the localisation file
"{count, plural, =0{No cards} =1{1 card} other{{count} cards}}"
```

**3. Matching backend error strings:**
```
// ❌ brittle — breaks if the server changes its error messages
if (error.message === "User not found") { showLocalised("user.missing") }

// ✅ map typed error codes to localised strings
switch (error.code) {
  case "INVALID_CREDENTIALS": return l10n.errorInvalidCredentials
  case "NETWORK_ERROR": return l10n.errorNoInternet
}
```

---

## Part 10 — Strategic Commenting Policy (Universal)

### The Core Rule

> *"A comment is an apology for failure to express your thoughts in code."* — Robert C. Martin

Code explains **what** and **how** through naming, structure, and types.
Comments explain **why** — and only when the why is non-obvious to a skilled engineer reading the code for the first time.

**The test before writing a comment:** If a skilled engineer read this code without the comment, would they eventually understand the why? If yes → delete the comment and improve the code. If they genuinely couldn't know → write the comment.

### What Never Gets a Comment

```
// ❌ Redundant "what" comment — the code already says this
// Increment the index
currentIndex++

// ❌ Commented-out code — delete it, git preserves history
// const oldEngine = new LegacyCalculator()
// oldEngine.run()

// ❌ Author / change-log headers — git blame does this
// Created by Alice — 2024-03-12
// Modified by Bob — 2024-06-15 to fix crash

// ❌ Banner dividers — if you need these, the class is too large
// ==================== HELPER METHODS ====================

// ❌ Closing brace labels — if you need these, the block is too deep
} // end if isAuthorized
```

### What Always Gets a Comment

```
// ✅ Non-obvious business rationale — the WHY that the name can't convey
// Stability is clamped at 0.1 to prevent division-by-zero in the FSRS-6
// power-law forgetting curve during the first repetition interval.
const MIN_STABILITY = 0.1

// ✅ Platform / framework workaround with a reference
// Workaround for Flutter issue #134291: Impeller shader warm-up stall
// on iOS 17+ with backdrop filters. Remove when Flutter 3.25 is adopted.
final filter = isAffectedDevice ? null : ImageFilter.blur(sigmaX: 10)

// ✅ Algorithm citation — non-obvious mathematical derivation
// Implements the SM-2 spaced repetition algorithm.
// Reference: Wozniak, P.A. (1990) https://supermemo.com/en/articles/sm2
double calculateNextInterval(double ease, int repetitions) { ... }

// ✅ Intentional non-obvious decision
// LinkedHashMap is intentional — insertion order is part of the undo-history
// contract. A regular HashMap would silently break undo/redo ordering.
final history = LinkedHashMap<String, Change>()

// ✅ Actionable TODO with a ticket reference
// TODO(PROJ-104): Migrate to batch delete when SQLite 3.45 is available.
```

### Documentation Comments for Public Interfaces

Use documentation comments (`///` in Dart, `/** */` in JS/Java, `#` in Python docstrings) on:
- Public abstract interfaces and contracts (repositories, services, use cases)
- Non-obvious preconditions, postconditions, or invariants
- Complex algorithms or non-trivial return semantics

Do **not** document:
- Private methods whose purpose is clear from their name
- Simple getters, setters, or trivially obvious CRUD methods

```
// ✅ GOOD: documents the WHY and contract, not the obvious
/**
 * Refreshes the active user session token.
 *
 * Returns Right(Session) on success, or Left(Failure) if the refresh token
 * has expired or been revoked on the server. Callers must handle both cases
 * — no exceptions are thrown from this method.
 *
 * Token rotation is atomic: the old token is invalidated before the new
 * token is issued to prevent concurrent refresh races.
 */
Future<Either<Failure, Session>> refreshSession()
```

---

## Part 11 — CI/CD & DevOps Standards

### Quality Gates (All Must Pass Before Merge)

Automate these in CI — no human should manually verify them:

1. **Linting** — static analysis, code style (no warnings, no errors)
2. **Unit tests** — all pass, coverage thresholds met
3. **Integration tests** — all pass
4. **Security scan** — dependency vulnerabilities (Snyk, Dependabot, `govulncheck`, `npm audit`)
5. **Secret detection** — scan for accidentally committed secrets (Gitleaks, Trufflehog)

No code merges if any gate fails. This is non-negotiable.

### Environment Parity

Dev, Staging, and Production must run **the identical artifact** (the same Docker image, the same binary). Only configuration differs:

```
// ❌ BAD: building different code for each environment
if (ENV == "production") { use_real_payment = true }

// ✅ GOOD: same artifact everywhere, configured by environment variables
PAYMENT_GATEWAY_KEY=sk_live_...   # injected at runtime by the environment
PAYMENT_GATEWAY_KEY=sk_test_...   # injected in staging
```

Manual "ClickOps" changes in production are forbidden. All infrastructure changes go through Infrastructure as Code (Terraform, Pulumi, CloudFormation) and version control.

### Deployment Strategy for Zero-Downtime

- **Blue-Green**: Run two identical environments. Switch traffic instantly. Rollback by switching back.
- **Canary**: Route 5% of traffic to the new version. Monitor error rates. Gradually increase to 100%. Rollback if error rate spikes.

Use **feature flags** to decouple deployment from release. Code ships merged to main, hidden behind a flag, and enabled when ready — without a new deployment.

### Branch Strategy

- Use **trunk-based development**: short-lived feature branches (< 2 days), merged frequently to main.
- Main branch is always deployable.
- Protect main: require passing CI and at least one approval before merge.
- Use semantic versioning: `MAJOR.MINOR.PATCH` — breaking change, new feature, bug fix.

---

## Part 12 — Language-Specific Standards

### Dart / Flutter

All universal principles above apply. These are the Dart/Flutter-specific implementations.

**Architecture — Dart class modifiers:**
- `abstract interface class` → repository contracts, use case interfaces, data source contracts
- `final class` → concrete implementations (cannot be subclassed)
- `sealed class` → state hierarchies (enforces exhaustive switch at compile time)
- `mixin` → composable behaviours

**States — always sealed:**
```dart
sealed class AuthState { const AuthState(); }
final class AuthInitial extends AuthState { const AuthInitial(); }
final class AuthLoading extends AuthState { const AuthLoading(); }
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.user});
  final User user;
}
final class AuthFailure extends AuthState {
  const AuthFailure({required this.message});
  final String message;
}
```

**Error handling — Either<Failure, T>:**
```dart
// Domain Failure hierarchy (sealed)
sealed class Failure { const Failure(); }
final class NetworkFailure extends Failure { const NetworkFailure(); }
final class ServerFailure extends Failure {
  const ServerFailure({this.message});
  final String? message;
}
final class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure();
}
```

**Null safety — ban the bang operator:**
```dart
// ❌ BAD: runtime crash if null
return Text(_profile!.name)

// ✅ GOOD: compile-time safe
final profile = _profile;
if (profile == null) return const SizedBox.shrink();
return Text(profile.name);
```

**Flutter testing stack:**
```yaml
dev_dependencies:
  flutter_test: # built-in
  bloc_test: ^9.0.0
  mocktail: ^1.0.0
```

**BLoC testing with `bloc_test`:**
```dart
blocTest<AuthBloc, AuthState>(
  'emits [AuthLoading, AuthAuthenticated] when login succeeds',
  build: () {
    when(() => mockLogin(any())).thenAnswer((_) async => Right(tUser));
    return AuthBloc(loginUseCase: mockLogin);
  },
  act: (bloc) => bloc.add(const AuthLoginRequested(email: tEmail, password: tPassword)),
  expect: () => const [AuthLoading(), AuthAuthenticated(user: tUser)],
  verify: (_) => verify(() => mockLogin(any())).called(1),
)
```

**Localisation — `AppLocalizations` with `BuildContext` extension:**
```dart
// lib/src/l10n/l10n.dart
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

// In widgets:
Text(context.l10n.authSignInButton)  // ✅ Never Text('Sign In')
```

**`const` constructors — required on all immutable types:**
```dart
// Every StatelessWidget and immutable value object must have a const constructor
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({required this.label, required this.onPressed, super.key});
  final String label;
  final VoidCallback onPressed;
}
```

**Avoiding unnecessary rebuilds:**
```dart
// Rebuild only when unreadCount changes — not on every NotificationState change
BlocSelector<NotificationBloc, NotificationState, int>(
  selector: (state) => state.unreadCount,
  builder: (context, count) => Badge(label: Text('$count')),
)
```

### Go

- Follow `gofmt` / `goimports` formatting — enforced in CI, no exceptions.
- Return `(T, error)` tuples — never panic in library code; panic only in `main` with explicit context.
- Define interfaces at the point of use (in the package that needs the abstraction), not at the point of implementation.
- Use `context.Context` as the first parameter of every function that does I/O or can be cancelled.
- Use `govulncheck` in CI for dependency vulnerability scanning.
- Struct embedding only for genuine IS-A relationships — prefer explicit field delegation.
- All exported functions, types, and packages must have godoc comments.

### JavaScript / TypeScript

- Prefer TypeScript — never use untyped JavaScript in a production project.
- `unknown` over `any` — `any` bypasses the type system entirely.
- Use Zod or a schema validation library at every external data boundary (HTTP, env vars, DB reads).
- Async/await everywhere — no callback pyramids, minimal raw Promise chaining.
- Use `strict: true` in `tsconfig.json` — enforce `strictNullChecks`, `noImplicitAny`, etc.
- ESLint + Prettier in CI — format on save, enforced on merge.
- Use `pnpm` or `npm ci` (not `npm install`) in CI to ensure reproducible installs from lock files.

---

## Part 13 — Master Checklist

Use before every commit. Every item is a hard requirement.

### Architecture
- [ ] Domain layer has zero framework/infrastructure imports
- [ ] Entities have no serialization code (`fromJson`/`toJson`)
- [ ] Repository contracts defined in domain layer; implementations in data layer
- [ ] Controllers/BLoCs depend only on use cases — not on repositories or data sources
- [ ] All raw exceptions caught at the adapter boundary and mapped to typed domain failures
- [ ] DI wired in composition root — not inside business logic

### SOLID & Principles
- [ ] Every class has one reason to change (SRP)
- [ ] New behaviour extends, not modifies, existing code (OCP)
- [ ] No `UnsupportedError`/`NotImplementedError` thrown in overrides (LSP)
- [ ] No methods on interfaces that implementers do not need (ISP)
- [ ] High-level modules depend on abstractions, not concretions (DIP)
- [ ] No repeated business logic (DRY)
- [ ] No over-engineered abstractions (YAGNI/KISS)

### Security
- [ ] Zero secrets in source code or version control
- [ ] All user input validated at trust boundaries with an allow-list
- [ ] All database queries use parameterised inputs — no string concatenation
- [ ] Authentication and authorisation enforced on every protected resource
- [ ] HTTPS enforced everywhere — no plaintext HTTP in any environment
- [ ] Dependencies scanned for known CVEs in CI
- [ ] Passwords hashed with bcrypt/Argon2 — never plaintext or MD5/SHA-1
- [ ] Principle of least privilege applied to all service accounts and DB users
- [ ] Error responses contain no stack traces, SQL, or internal paths

### Scalability
- [ ] Service is stateless — no local in-memory state between requests
- [ ] Connection pooling configured for all database connections
- [ ] N+1 queries eliminated (use joins or batch loading)
- [ ] All cache entries have a TTL
- [ ] Idempotency keys used on non-idempotent POST operations with side effects
- [ ] Async queues used for long-running or fan-out operations

### API Design
- [ ] Resources are nouns; HTTP verbs carry the action
- [ ] Correct HTTP status codes returned for every outcome
- [ ] API version in URL path (`/v1/`)
- [ ] Error responses use a standard structured shape with a `correlationId`
- [ ] No breaking changes to existing API versions (no field removals or renames)

### Error Handling & Observability
- [ ] No empty catch blocks — every caught exception is handled, wrapped, or logged
- [ ] Typed error hierarchy — no raw string errors
- [ ] Structured JSON logging with `correlationId`, `userId`, service name, and `level`
- [ ] No secrets or PII (plaintext) in log entries
- [ ] Health check endpoints present (`/health`, `/health/ready`)

### TDD
- [ ] Test written before implementation (Red-Green-Refactor)
- [ ] Test file mirrors source file path with `.test`/`_test` suffix
- [ ] All tests follow AAA with blank-line separation between phases
- [ ] Test names describe scenario and expected outcome (should-when)
- [ ] Fresh mocks in every `setUp` — no shared mutable test state
- [ ] All branch paths (success + every failure case) covered
- [ ] No real network calls, disk access, or DB queries in unit tests

### Localisation
- [ ] Zero hardcoded user-visible strings in UI
- [ ] Zero string concatenation for localised text
- [ ] Zero manual plural ternaries — ICU syntax in localisation files
- [ ] All new keys follow the `[feature].[component].[element]` naming pattern
- [ ] Backend errors mapped via typed error codes, not string matching

### Commenting
- [ ] No commented-out code
- [ ] No change-log / author header comments
- [ ] No redundant "what" comments
- [ ] Non-obvious business rationale has a brief "why" comment
- [ ] Platform workarounds reference the issue tracker or ticket
- [ ] Public non-obvious interfaces have documentation comments
- [ ] All TODOs reference a ticket (`// TODO(PROJ-42): ...`)
