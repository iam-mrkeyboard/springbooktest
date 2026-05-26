# SpringbokExpeditions - cPanel Deployment Guide

## Prerequisites
- cPanel with **Node.js Selector** (Node 18+)
- **MySQL Database Wizard** access
- SSH access to cPanel (recommended)

---

## Quick Start

```bash
# 1. Import database schema
mysql -u CPANEL_USER -p -h localhost CPANEL_DB_NAME < database/init-mysql.sql

# 2. Install deps (see npm fix below)
npm install --legacy-peer-deps

# 3. Build & start
npm run build
node dist/server/entry.mjs
```

---

## ⚠️ npm Install Error Fix

### The Problem

cPanel's Node.js App Manager runs `npm install` without arguments, which fails with:

```
npm error ERESOLVE unable to resolve dependency tree
npm error peer @effect/platform@"^0.79.4" from @effect/rpc-http@0.52.4
npm error Found: @effect/platform@0.96.1
```

This happens because StudioCMS depends on the **Effect** ecosystem, and different packages require conflicting versions of `@effect/platform`.

### Fix Option 1: cPanel GUI (Recommended)

1. cPanel → **Setup Node.js App** → Edit your app
2. In the **Environment Variables** section, add:

   | Variable | Value |
   |----------|-------|
   | `NPM_CONFIG_LEGACY_PEER_DEPS` | `true` |

3. Click **Run NPM Install** — this tells npm to use `--legacy-peer-deps` automatically

### Fix Option 2: cPanel SSH Terminal

cPanel locks `node` and `npm` inside its Node.js Selector paths. They're not globally available. Find and use them:

```bash
# Locate the Node.js binary (replace 24 with your version)
ls /opt/alt/alt-nodejs24/root/usr/bin/node

# Add to PATH and install
export PATH=/opt/alt/alt-nodejs24/root/usr/bin:$PATH
npm install --legacy-peer-deps
```

Then go to Node.js App Manager and **Start App**.

### Fix Option 3: Pre-install locally

Build `node_modules/` locally and include it in the ZIP upload:

```bash
npm install --legacy-peer-deps
zip -r deploy.zip . -x ".env" "*.db" ".astro/*" "dist/*" "src/*"
```

Upload the ZIP to cPanel, extract it, then run `npm run build` on cPanel.

### Why `--legacy-peer-deps` is safe here

This flag tells npm to ignore strict peer dependency version matching and use whatever's installed. For StudioCMS:
- All Effect packages are compatible despite version mismatch warnings
- The app runs correctly in production as verified on `test.springbokexpeditions.com`
- The alternative (`--force`) may install broken combinations

---

## Step 1: Create MySQL Database (cPanel MySQL Wizard)

1. Log in to cPanel → **MySQL Database Wizard**
2. Step 1: Create database name: `springbok_db`
3. Step 2: Create user: `springbok_user` + set password
4. Step 3: Grant **ALL PRIVILEGES**

**Note down (you'll need these):**
```
Database: username_springbok_db
User:     username_springbok_user
Password: your_secure_password
Host:     localhost
Port:     3306
```

---

## Step 2: Configure .env

Copy `.env.example` to `.env` and fill in your cPanel MySQL credentials:

```env
CMS_ENCRYPTION_KEY=CHANGE_ME_GENERATE_WITH_OPENSSL
ASTRO_SITE=https://your-domain.com

CMS_MYSQL_HOST=localhost
CMS_MYSQL_PORT=3306
CMS_MYSQL_DATABASE=username_springbok_db
CMS_MYSQL_USER=username_springbok_user
CMS_MYSQL_PASSWORD=your_secure_password
```

Generate encryption key:
```bash
openssl rand --base64 16
```

---

## Step 3: Verify studiocms.config.mjs

Make sure `dialect` is set to `'mysql'`:
```js
db: { dialect: 'mysql' }
```
This is already configured in the project — verify before deploying.

---

## Step 4: Upload Files to cPanel

Upload ALL project files (excluding `node_modules/` and `.db` files) to your cPanel directory, e.g. `/home/username/public_html/`.

Or use Git:
```bash
cd /home/username/public_html
git clone YOUR_REPO .
```

---

## Step 5: Import MySQL Schema

**IMPORTANT:** The StudioCMS CLI migration has a known bug with MySQL — it marks migrations as done but doesn't create the actual data tables. We import the schema directly:

```bash
cd /home/username/public_html
mysql -u username_springbok_user -p -h localhost username_springbok_db < database/init-mysql.sql
```

This creates all 19 StudioCMS tables including:
- `StudioCMSPageData` (page content)
- `StudioCMSUsersTable` (user accounts)
- `StudioCMSPageContent` (page body)
- `StudioCMSDynamicConfigSettings` (site settings)
- And 15 more...

---

## Step 6: Install Dependencies & Build

Via SSH:
```bash
cd /home/username/public_html
npm install --legacy-peer-deps
npm run build
```

Or via cPanel Node.js app: click **Run NPM Install** then run build command.

---

## Step 7: Create Node.js App

1. cPanel → **Setup Node.js App** → **Create Application**
2. Configure:
   - **Node.js version:** Latest (18+)
   - **Application mode:** Production  
   - **Application root:** `/home/username/public_html`
   - **Application URL:** your domain
   - **Application startup file:** `dist/server/entry.mjs`
3. Add environment variables (all from `.env` file)
4. Click **Create** → **Start App**

---

## Step 8: Verify

Visit your domain → you should see the SpringbokExpeditions homepage.

---

## StudioCMS Dashboard

After deployment:
- **Dashboard:** `https://your-domain.com/dashboard`
- **Login:** `https://your-domain.com/login`

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Table doesn't exist" | Re-run `database/init-mysql.sql` import |
| "Connection refused" | Check MySQL credentials in `.env` |
| 500 error on homepage | Check `cPanel → Node.js → App logs` |
| Build fails | Run `npm install --legacy-peer-deps` |
| Port conflict | cPanel auto-assigns port — use the one it gives you |

---

## Local vs Production

| | Local Dev | cPanel Prod |
|---|---|---|
| Database | SQLite (`studiocms.db`) | MySQL |
| Config dialect | `libsql` | `mysql` |
| Command | `npm run dev` | `node dist/server/entry.mjs` |
| Port | 4321 | cPanel-assigned |
