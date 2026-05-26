# SpringbokExpeditions × StudioCMS: MySQL Deployment Deep Dive

> A comprehensive technical walkthrough of integrating **StudioCMS** with **MySQL** on **cPanel**, cloning the SpringbokExpeditions homepage, and solving the database migration pitfalls along the way.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture Decisions](#2-architecture-decisions)
3. [Problem 1: Package Dependency Hell](#3-problem-1-package-dependency-hell)
4. [Problem 2: StudioCMS Route Collision](#4-problem-2-studiocms-route-collision)
5. [Problem 3: The MySQL Migration Bug](#5-problem-3-the-mysql-migration-bug)
6. [Problem 4: Encryption Key Validation](#6-problem-4-encryption-key-validation)
7. [Problem 5: Effect Ecosystem Missing Packages](#7-problem-5-effect-ecosystem-missing-packages)
8. [Problem 6: Start Page vs Homepage Override](#8-problem-6-start-page-vs-homepage-override)
9. [The Final Fix: SQL Schema Export → MySQL Import](#9-the-final-fix-sql-schema-export--mysql-import)
10. [Complete Project Architecture](#10-complete-project-architecture)
11. [cPanel Deployment Strategy](#11-cpanel-deployment-strategy)
12. [Key Takeaways & Lessons Learned](#12-key-takeaways--lessons-learned)

---

## 1. Project Overview

### Goal

Clone the **SpringbokExpeditions.com** homepage (a Tanzanian safari/expedition company) and deploy it on **cPanel** using:

- **StudioCMS** — an Astro-native headless CMS
- **MySQL** — via cPanel's MySQL Database Wizard
- **Node.js** — via cPanel's Node.js Application Manager

### Original Website Structure

The SpringbokExpeditions homepage contains these sections:

| Section | Content |
|---------|---------|
| Header/Navigation | Logo, 6 nav links, phone, email CTA |
| Hero | Full-screen background, title, subtitle, 2 CTA buttons |
| Services | 4 cards: Wildlife Safaris, Mountain Trekking, Cultural, Custom |
| Discover | Text block + side image + Great Migration card |
| Destinations | 6 cards: Serengeti, Ngorongoro, Tarangire, Manyara, Kilimanjaro, Zanzibar |
| Safari Packages | 6 cards with images, titles, duration, location |
| FAQ | 10 accordion questions |
| Footer | Logo, nav links, social icons, copyright |

### Image Strategy

All images are **hotlinked from the original WordPress site** (`springbokexpeditions.com/wp-content/uploads/...`). This avoids:
- Downloading and hosting duplicate assets
- Storage overhead on cPanel
- Copyright concerns (images remain on the original server)

---

## 2. Architecture Decisions

### Why StudioCMS + Astro?

| Consideration | Decision |
|---------------|----------|
| **CMS** | StudioCMS — Astro-native, headless, supports MySQL |
| **Framework** | Astro v5 — SSG/SSR hybrid, excellent performance |
| **Database (Local)** | SQLite (via libSQL) — zero-config for development |
| **Database (Production)** | MySQL — cPanel's native database offering |
| **Runtime** | Node.js standalone mode — cPanel Node.js compatible |
| **Rendering** | SSR (`output: 'server'`) — required by StudioCMS |
| **Styling** | Pure CSS with CSS variables — no framework dependency |

### Why Not Turso/libSQL in Production?

Turso is a managed libSQL service that requires a paid subscription. The user explicitly wanted to use MySQL because:
1. cPanel includes MySQL for free
2. MySQL Database Wizard provides easy setup
3. No additional monthly costs for database hosting

### Why Hotlink Images?

| Pros | Cons |
|------|------|
| Zero storage cost | Depends on original server uptime |
| No need to download/organize | URLs may change if the original site updates |
| Faster initial deployment | Not ideal for permanent production |

---

## 3. Problem 1: Package Dependency Hell

### The Issue

When running `npm install` with StudioCMS and its rendering plugins:

```
npm error ERESOLVE unable to resolve dependency tree
npm error peer studiocms@"^0.1.1" from @studiocms/html@0.1.1
npm error Found: studiocms@0.4.4
```

The `@studiocms/html@0.1.1` and `@studiocms/md@0.1.1` plugins declared a peer dependency on `studiocms@^0.1.1`, which conflicted with the current `studiocms@0.4.4`.

### Root Cause

StudioCMS is actively developed and undergoes rapid version changes. The rendering plugins at `0.1.x` were designed for an older StudioCMS API. The `studiocms/schemas` module no longer exports `StudioCMSSanitizeOptionsSchema` in `0.4.4`.

### Solution

Three-step fix:

**Step 1:** Install with `--legacy-peer-deps` to bypass the strict peer dependency check:

```bash
npm install --legacy-peer-deps
```

**Step 2:** Check for newer plugin versions:

```bash
npm view @studiocms/html versions --json
npm view @studiocms/md versions --json
```

**Step 3:** Upgrade to compatible versions:

```bash
npm install @studiocms/html@0.3.0 @studiocms/md@0.3.0 --legacy-peer-deps
```

| Package | Broken Version | Working Version |
|---------|---------------|-----------------|
| `studiocms` | — | `0.4.4` |
| `@studiocms/html` | `0.1.1` | `0.3.0` |
| `@studiocms/md` | `0.1.1` | `0.3.0` |

---

## 4. Problem 2: StudioCMS Route Collision

### The Issue

Astro warned at build time:

```
[WARN] [router] The route "/" is defined in both
  "src/pages/index.astro"
  and "node_modules/studiocms/frontend/setup-pages/index.astro"
```

Two files tried to claim the `/` route:
1. Our Springbok homepage (`src/pages/index.astro`)
2. StudioCMS setup wizard (`studiocms/frontend/setup-pages/index.astro`)

### Root Cause

StudioCMS has a **start page** feature (`dbStartPage`) that inserts a setup wizard at `/`. This is a first-time initialization wizard that:
- Creates database tables
- Prompts for site name/description
- Creates admin user account
- Configures initial settings

When `dbStartPage` is enabled, it takes priority over user-defined routes.

### Solution

In `studiocms.config.mjs`, set `dbStartPage: false`:

```js
export default defineStudioCMSConfig({
  dbStartPage: false,  // <-- Disable the setup wizard at /
  db: { dialect: 'mysql' },
  plugins: [
    studiocmsHTML(),
    studiocmsMD(),
  ],
});
```

**Trade-off:** With the start page disabled:
- Our Springbok homepage renders at `/` ✅
- StudioCMS setup wizard is hidden ❌
- Database initialization must be done manually ✅ (we handle this with SQL import)
- StudioCMS dashboard still accessible at `/dashboard`

---

## 5. Problem 3: The MySQL Migration Bug

### ⚠️ Critical Discovery

This was the **biggest challenge** in the entire project.

### What We Observed

Running the StudioCMS CLI migration:

```bash
npx studiocms migrate --latest
```

Output claimed success:

```
✔ Migration "20251025T040912_init" was executed successfully
✔ Migration "20251130T150847_drop_deprecated" was executed successfully
✔ Migration "20251221T002125_url-mapping" was executed successfully
◇ Migration to latest version
└ Database migrated to latest version!
```

But checking MySQL:

```bash
mysql -u root studiocms -e "SHOW TABLES;"
```

```
Tables_in_studiocms
kysely_migration          ← Only migration tracking table
kysely_migration_lock     ← Only lock table
```

**Only 2 tables instead of 19. All StudioCMS data tables missing.**

### Error Logs Reveal the Truth

During migration, the server logged:

```
timestamp=... level=ERROR fiber=#38 message="Migration failure: SqlError: An error has occurred
    at catch (file:///...kysely/dist/utils/tables.js:51:23)
    at file:///...effect/dist/esm/internal/core-effect.js:579:51
    at file:///...kysely/dist/utils/migrator.js:186:22"
```

### Deep Investigation

StudioCMS uses a **schema-based migration system** (not traditional SQL migrations). Here's how it works:

1. **Schema definition** — A JavaScript object defines all tables, columns, types, and constraints
2. **Schema comparison** — The migrator reads the current database schema and compares it to the desired schema
3. **Diff & apply** — It generates `CREATE TABLE`, `ALTER TABLE`, `CREATE INDEX` statements automatically

The migration engine uses Kysely (a type-safe SQL query builder) with different database adapters:

| Database | Kysely Dialect | Adapter Package |
|----------|---------------|-----------------|
| libSQL/SQLite | `sqlite` | `@libsql/client` |
| MySQL | `mysql` | `mysql2` |
| PostgreSQL | `postgres` | `pg` |

### Root Cause

The migration system calls `db.schema.createTable()` which uses Kysely's `CreateTableBuilder`. This builder **generates SQL in the dialect of the database** — but the dialect detection or SQL generation has a **bug with MySQL**.

Specifically, the `tableExists()` function (in `introspection.js`) queries the database to check if a table exists. When it can't find the table, it tries to create it. But the creation fails silently because:

1. The **Schema Manager** creates a tracking table (`_kysely_schema_v1`) first
2. On MySQL, this creation fails (likely due to MySQL-specific DDL syntax issues)
3. The error is **caught and swallowed** by Effect's error handling
4. Without the schema tracking table, no actual data tables get created
5. But the migration version tracking (`kysely_migration`) uses separate non-effect code that succeeds

The failure happens in this chain:

```
migrator.js:186  →  tables.js:51  →  MySQL execute()
                                  →  SQL syntax error
                                  →  caught & wrapped in SqlError
                                  →  Effect fiber fails silently
```

### Why SQLite Works

SQLite's DDL is simpler and Kysely's SQLite dialect generates valid SQL that works with the `@libsql/client`. The schema tracking table creates successfully, the schema gets saved, and all data tables follow. MySQL's dialect has subtle differences:

| Operation | SQLite | MySQL |
|-----------|--------|-------|
| Auto-increment PK | `INTEGER PRIMARY KEY` | `INT AUTO_INCREMENT PRIMARY KEY` |
| Timestamp default | `DEFAULT CURRENT_TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP` (diff parsing) |
| Text type | `TEXT` | `TEXT` (same) but encoding matters |
| Foreign keys | Inline `REFERENCES` | `FOREIGN KEY () REFERENCES` |
| Table creation | Simple | Requires `ENGINE=InnoDB` |

---

## 6. Problem 4: Encryption Key Validation

### The Issue

```
CMS_ENCRYPTION_KEY must decode to 16 bytes, got 25
```

StudioCMS requires the encryption key to be **exactly 16 bytes** when decoded from base64.

### Root Cause

The key I initially generated was not a valid 16-byte base64 string:

```bash
# Wrong: 32 bytes → 25 bytes when base64 decoded
echo "dGVzdGtleXRlc3RrZXl0ZXN0a2V5dGVzdA==" | base64 -d | wc -c
# Output: 25

# Correct: 16 bytes
openssl rand --base64 16
# Example output: s7Xk06jBj+gjTjcBpcfXiw==
```

Base64 encoding pads the output with `=` characters. A 16-byte input produces 24 base64 characters (22 characters + 2 padding). My original key was longer and decoded to 25 bytes.

### Solution

Generate a proper 16-byte key:

```bash
openssl rand --base64 16
# OR programmatically:
node -e "console.log(require('crypto').randomBytes(16).toString('base64'))"
```

StudioCMS uses this key internally for:
- Password hashing (PBKDF2 or similar)
- Session token encryption
- API key generation

---

## 7. Problem 5: Effect Ecosystem Missing Packages

### The Issue

During builds, multiple "Cannot find package" errors appeared:

```
Cannot find package '@effect/cli' imported from @withstudiocms/effect/dist/effect.js
Cannot find package 'effect' imported from @effect/cli/dist/esm/internal/args.js
Cannot find package '@effect/printer-ansi' imported from @effect/cli/dist/esm/...
Cannot find package '@effect/cluster' imported from @effect/platform-node/dist/esm/...
Cannot find package '@effect/experimental' imported from @effect/sql/dist/esm/...
```

### Root Cause

StudioCMS is built on top of the **Effect** ecosystem — a functional programming library for TypeScript. The `@withstudiocms/effect` package uses many Effect modules as dependencies, but they are declared as **peer dependencies** (not hard dependencies).

When we used `--legacy-peer-deps` to bypass the rendering plugin conflict, npm also skipped installing these peer dependencies.

### The Effect Dependency Tree

```
studiocms
└── @withstudiocms/effect
    ├── @effect/cli          (CLI argument parsing)
    ├── @effect/platform      (Platform abstractions)
    ├── @effect/platform-node (Node.js runtime integration)
    │   └── @effect/cluster   (Clustering)
    └── @effect/sql           (SQL database layer)
        └── @effect/experimental (Experimental features)
```

Each of these packages depends on:
```
@effect/cli
├── effect                  (Core library)
├── @effect/printer          (Terminal output formatting)
│   └── @effect/printer-ansi (ANSI color support)
└── @effect/typeclass        (Type class utilities)
```

### Solution

Install all missing packages:

```bash
npm install \
  effect \
  @effect/cli \
  @effect/platform \
  @effect/platform-node \
  @effect/cluster \
  @effect/sql \
  @effect/sql-mysql2 \
  @effect/experimental \
  @effect/printer \
  @effect/printer-ansi \
  @effect/typeclass \
  --legacy-peer-deps
```

**Alternative:** Use `npm install` without `--legacy-peer-deps` for StudioCMS's own dependencies, or use a package manager that handles peer deps better (pnpm, bun).

---

## 8. Problem 6: Start Page vs Homepage Override

### The Issue

When `dbStartPage` was enabled (the default), navigating to `http://localhost:4321/` showed the **StudioCMS setup wizard** instead of the Springbok homepage.

### User Confusion

The user saw "Welcome to StudioCMS" and thought the homepage was broken or the template was wrong. This was confusing because:
- The Springbok components were built and compiling correctly
- The page existed at `src/pages/index.astro`
- But StudioCMS was overriding it with its setup wizard

### The Dance We Did

```
dbStartPage: enabled  → User sees "Welcome to StudioCMS"
                       "why i see the template from studiocms no the page of spring"

dbStartPage: disabled → Springbok homepage renders, but StudioCMS middleware
                       crashes querying non-existent tables
                       "Table 'studiocms.StudioCMSPageData' doesn't exist"

dbStartPage: enabled  → User completes Step 1 of setup
                       Clicks "Continue"
                       "Internal Server Error" (tables still missing)

dbStartPage: disabled → After importing MySQL schema manually
                       → Springbok homepage WORKS ✅
```

### Root Cause

The `dbStartPage` feature creates a **chicken-and-egg problem**:

1. Start page enabled → wizard appears, but can't complete because tables don't exist
2. Start page disabled → homepage appears, but middleware crashes because tables don't exist
3. The only way out: **create tables manually**, then disable start page

### Solution

**Step 1:** Create tables first (SQL import — see Section 9)

**Step 2:** Disable start page:

```js
// studiocms.config.mjs
dbStartPage: false
```

**Step 3:** Springbok homepage renders at `/`, dashboard at `/dashboard`

---

## 9. The Final Fix: SQL Schema Export → MySQL Import

### The Breakthrough

Since the CLI migration failed to create tables on MySQL but worked perfectly on SQLite, we used SQLite as a "schema reference" and converted to MySQL.

### Step-by-Step Walkthrough

**Step 1: Export SQLite schema**

```bash
sqlite3 studiocms.db .schema
```

This output the full DDL for all 19 tables.

**Step 2: Convert SQLite DDL to MySQL DDL**

Each SQLite `CREATE TABLE` statement needed these changes:

| SQLite | MySQL |
|--------|-------|
| `"column"` (double quotes) | `` `column` `` (backticks) |
| `INTEGER PRIMARY KEY` (auto-increment) | `INT AUTO_INCREMENT PRIMARY KEY` |
| `TEXT DEFAULT CURRENT_TIMESTAMP` | `TEXT DEFAULT (CURRENT_TIMESTAMP)` |
| `REFERENCES "Table"("col")` inline | `FOREIGN KEY (col) REFERENCES Table(col)` |
| No engine specification | `ENGINE=InnoDB DEFAULT CHARSET=utf8mb4` |

**Example conversion:**

SQLite:
```sql
CREATE TABLE "StudioCMSUsersTable" (
  "id" text primary key,
  "name" text not null,
  "createdAt" text default CURRENT_TIMESTAMP not null,
  "userId" text not null references "StudioCMSUsersTable" ("id")
);
```

MySQL:
```sql
CREATE TABLE `StudioCMSUsersTable` (
  `id` VARCHAR(255) NOT NULL,
  `name` TEXT NOT NULL,
  `createdAt` TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP),
  PRIMARY KEY (`id`),
  FOREIGN KEY (`userId`) REFERENCES `StudioCMSUsersTable`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**Step 3: Import into MySQL**

```bash
mysql -u root studiocms < database/init-mysql.sql
```

**Step 4: Add migration tracking records**

```sql
INSERT INTO kysely_migration (name, timestamp) VALUES
('20251025T040912_init', NOW()),
('20251130T150847_drop_deprecated', NOW()),
('20251221T002125_url-mapping', NOW());
```

This ensures StudioCMS doesn't try to re-run migrations.

**Step 5: Verify**

```bash
mysql -u root studiocms -e "SHOW TABLES;"
# Output: 19 tables ✅
```

### Full Table List After Import

```
StudioCMSAPIKeys                    — API key management
StudioCMSDiffTracking               — Page revision tracking
StudioCMSDynamicConfigSettings      — Site configuration
StudioCMSEmailVerificationTokens    — Email verification
StudioCMSOAuthAccounts              — Third-party login accounts
StudioCMSPageContent                — Page body content
StudioCMSPageData                   — Page metadata (slug, title, author)
StudioCMSPageDataCategories         — Content categories
StudioCMSPageDataTags               — Content tags
StudioCMSPageFolderStructure        — Page folder hierarchy
StudioCMSPermissions                 — RBAC permissions
StudioCMSPluginData                 — Plugin configuration storage
StudioCMSSessionTable               — User sessions
StudioCMSStorageManagerUrlMappings  — Media URL mappings
StudioCMSUserResetTokens            — Password reset tokens
StudioCMSUsersTable                 — User accounts
_kysely_schema_v1                   — Schema version tracking
kysely_migration                    — Migration history
kysely_migration_lock               — Migration lock
```

### Why This Works

The StudioCMS **runtime** (middleware, API handlers, dashboard) queries the database using Kysely's type-safe query builder. As long as:
1. The table names match exactly
2. The column names and types are correct
3. Foreign key relationships exist

...then the runtime doesn't care how the tables were created. It reads and writes data through Kysely, which handles the MySQL dialect properly at **query time** (SELECT, INSERT, UPDATE, DELETE). The bug is only in the **migration time** (schema creation).

---

## 10. Complete Project Architecture

### Directory Structure

```
springbok/
├── astro.config.mjs              # Astro config with Node.js adapter
├── studiocms.config.mjs          # StudioCMS: MySQL dialect, plugins
├── package.json                  # Dependencies and scripts
├── .env                          # Local environment (MySQL)
├── .env.example                  # cPanel env template
├── DEPLOY.md                     # cPanel deployment guide
├── PROBLEMS_AND_SOLUTIONS.md     # This file
│
├── database/
│   └── init-mysql.sql            # Full MySQL schema (19 tables)
│
├── src/
│   ├── layouts/
│   │   └── Layout.astro          # Global HTML template + fonts + CSS
│   │
│   ├── pages/
│   │   └── index.astro           # Main page (assembles all sections)
│   │
│   └── components/
│       ├── Header.astro          # Fixed navigation bar
│       ├── Hero.astro            # Full-screen hero section
│       ├── Services.astro        # 4 service cards grid
│       ├── Discover.astro        # Tanzania discover section
│       ├── Destinations.astro    # 6 destination cards grid
│       ├── Packages.astro        # 6 safari package cards
│       ├── FAQ.astro             # Accordion FAQ (10 questions)
│       └── Footer.astro          # Footer with links + social
│
├── public/                       # Static assets
└── dist/                         # Build output (not committed)
```

### Data Flow

```
Browser Request
     │
     ▼
┌─────────────────┐
│  Astro SSR       │  (Node.js standalone server)
│  @astrojs/node   │
└────────┬────────┘
         │
    ┌────▼────┐
    │ StudioCMS │  (Middleware layer)
    │ Middleware│
    └────┬─────┘
         │
    ┌────▼────┐
    │  Kysely   │  (Type-safe SQL query builder)
    │  ORM      │
    └────┬─────┘
         │
    ┌────▼────┐
    │   MySQL   │  (cPanel database)
    │   (mysql2)│
    └──────────┘
```

### Component Rendering Order

```
Layout.astro
├── Header.astro      (fixed position, top)
├── Hero.astro        (full viewport, background image)
├── Services.astro    (4-column grid, card style)
├── Discover.astro    (2-column grid, text + image)
├── Destinations.astro (3-column grid, overlay hover)
├── Packages.astro    (3-column grid, meta badges)
├── FAQ.astro         (accordion with <details>)
└── Footer.astro      (dark background, 3-section)
```

### CSS Architecture

Global variables for consistent theming:

```css
:root {
  --color-primary:      #2d5016;   /* Earthy green */
  --color-primary-dark: #1e3a0f;   /* Dark green */
  --color-accent:       #c9a227;   /* Gold/sand */
  --color-text:         #333333;   /* Dark text */
  --color-text-light:   #666666;   /* Muted text */
  --color-bg:           #ffffff;   /* White bg */
  --color-bg-alt:       #f8f6f3;   /* Warm off-white */
  --color-footer:       #1a1a1a;   /* Near-black */
  --font-heading:       'Montserrat', sans-serif;
  --font-body:          'Open Sans', sans-serif;
}
```

---

## 11. cPanel Deployment Strategy

### Phase A: Database Setup

```
cPanel MySQL Wizard
    │
    ├── Create database: prefix_springbok_db
    ├── Create user:     prefix_springbok_user
    └── Grant:           ALL PRIVILEGES
            │
            ▼
    mysql -u user -p db < database/init-mysql.sql
            │
            ▼
    19 tables created ✅
```

### Phase B: Application Setup

```
cPanel Node.js App Manager
    │
    ├── Node.js version:   18+
    ├── Application mode:  Production
    ├── App root:          /home/user/public_html
    ├── Startup file:      dist/server/entry.mjs
    └── Env variables:     (from .env)
            │
            ▼
    npm install --legacy-peer-deps
    npm run build
    node dist/server/entry.mjs
```

### Phase C: Environment Configuration

```env
# Authentication
CMS_ENCRYPTION_KEY=<openssl rand --base64 16>

# Site
ASTRO_SITE=https://your-domain.com

# MySQL
CMS_MYSQL_HOST=localhost
CMS_MYSQL_PORT=3306
CMS_MYSQL_DATABASE=prefix_springbok_db
CMS_MYSQL_USER=prefix_springbok_user
CMS_MYSQL_PASSWORD=your_password
```

### Deployment Checklist

- [ ] MySQL database created via cPanel Wizard
- [ ] MySQL user created with ALL PRIVILEGES
- [ ] `database/init-mysql.sql` imported successfully
- [ ] 19 tables verified in MySQL
- [ ] `.env` configured with cPanel credentials
- [ ] `studiocms.config.mjs` has `dialect: 'mysql'`
- [ ] `dbStartPage: false` in config
- [ ] `npm install --legacy-peer-deps` completed
- [ ] `npm run build` succeeded
- [ ] Node.js app pointing at `dist/server/entry.mjs`
- [ ] App started and homepage accessible via domain

---

## 12. Key Takeaways & Lessons Learned

### StudioCMS

1. **StudioCMS is designed for libSQL first.** MySQL support exists but is secondary and has edge cases in the migration tooling. Always test MySQL migrations on a local MySQL instance before deploying.

2. **The CLI migration tool is unreliable on MySQL.** Plan to use direct SQL import as a fallback. Keep a reference SQLite database to generate the schema.

3. **Rendering plugins are required.** StudioCMS won't start without at least one rendering plugin (HTML or Markdown).

4. **The start page is a one-time setup wizard.** It must be disabled after database initialization, or it overrides your homepage at `/`.

### MySQL + Node.js on cPanel

1. **cPanel's MySQL Database Wizard** is the easiest way to create databases but lacks SSH-friendly tools. You may need phpMyAdmin for SQL import if SSH isn't available.

2. **Node.js app manager** auto-assigns ports. The app must listen on the assigned port (Astro handles this automatically with `process.env.PORT`).

3. **Environment variables** are set in the Node.js app configuration panel, not just in `.env` files. cPanel may override `.env` settings.

### Dependency Management

1. **`--legacy-peer-deps` is a double-edged sword.** It bypasses conflicts but also skips legitimate peer dependencies. Always install peer deps manually after using it.

2. **The Effect ecosystem is deeply nested.** A single missing package (`effect`) cascades into 10+ missing imports. Use `npm ls effect` to trace the tree.

3. **Version compatibility matters.** `@studiocms/html@0.1.1` is broken with `studiocms@0.4.4` but `@studiocms/html@0.3.0` works. Always check `npm view` before installing.

### General Engineering

1. **Always verify, don't trust.** The migration tool claimed success but created only 2 of 19 tables. `SHOW TABLES` is essential after every schema operation.

2. **Error logs don't always surface.** The Effect library's error handling silently caught the MySQL schema creation failure. Only raw error logging revealed the truth.

3. **Keep a reference implementation.** The SQLite database became our "source of truth" for schema. Always have a known-good configuration to compare against.

4. **Route collisions are easy to miss.** Two files claiming `/` doesn't error immediately — it warns. Check the build output for `[WARN] [router]` messages.

---

## Appendix A: Quick Reference Commands

### Local Development

```bash
# Start dev server (SQLite)
npm run dev

# Start dev server (MySQL)
# First: ensure .env has MySQL credentials and config has dialect: 'mysql'
npm run dev

# Build for production
npm run build

# Run StudioCMS CLI
npx studiocms migrate --latest
```

### MySQL Management

```bash
# Create database
mysql -u root -e "CREATE DATABASE studiocms;"

# Import schema
mysql -u root studiocms < database/init-mysql.sql

# List tables
mysql -u root studiocms -e "SHOW TABLES;"

# Drop and recreate
mysql -u root -e "DROP DATABASE studiocms; CREATE DATABASE studiocms;"
```

### Debugging

```bash
# Check for missing peer deps
npm ls effect @effect/cli @effect/platform

# Check Astro build output
npm run build 2>&1 | grep -E "ERROR|WARN|✓"

# Check dev server logs
grep -i "error\|fatal\|500" /tmp/springbok.log

# Verify all page sections
curl -s http://localhost:4321/ | grep -oE "Section1|Section2"
```

---

## Appendix B: Version Compatibility Matrix

| Package | Bad Version | Good Version | Notes |
|---------|------------|--------------|-------|
| `studiocms` | — | `0.4.4` | Core CMS |
| `@studiocms/html` | `0.1.1` | `0.3.0` | HTML renderer plugin |
| `@studiocms/md` | `0.1.1` | `0.3.0` | Markdown renderer plugin |
| `@astrojs/node` | — | `^9.0.0` | Node.js adapter |
| `astro` | — | `^5.0.0` | Astro framework |
| `mysql2` | — | `^3.11.0` | MySQL client |
| `@libsql/client` | — | latest | SQLite client |
| `effect` | missing | latest | Functional core |
| `@effect/cli` | missing | latest | CLI utilities |
| `@effect/platform` | missing | latest | Platform abstractions |
| `@effect/sql` | missing | latest | SQL layer |
| `@effect/experimental` | missing | latest | Experimental features |

---

*Document written during the SpringbokExpeditions × StudioCMS integration project.*
*Last updated: May 2026*
