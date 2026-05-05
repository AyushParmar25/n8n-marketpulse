# Workflow Setup Guide

Step-by-step instructions for configuring the MarketPulse workflow after importing it into N8N.

---

## Prerequisites

- Stack is running: `docker compose up -d`
- N8N is accessible at `http://localhost:5678`
- You have a free [Groq API key](https://console.groq.com) (no credit card needed)
- You have Gmail OAuth2 credentials from [Google Cloud Console](https://console.cloud.google.com)

---

## Step 1 — Import the Workflow

1. Open N8N at `http://localhost:5678`
2. Log in with `admin` / `admin123`
3. Go to **Workflows** → **Add workflow** → **Import from file**
4. Upload `marketpulse_workflow.json` from this folder
5. Click **Save**

---

## Step 2 — Create Credentials

Go to **Settings** → **Credentials** → **Add credential** for each of the following.

### 2a. Groq API Key (Header Auth)

| Field | Value |
|-------|-------|
| Credential type | Header Auth |
| Name | `Authorization` |
| Value | `Bearer YOUR_GROQ_API_KEY` |

> Replace `YOUR_GROQ_API_KEY` with your key from [console.groq.com](https://console.groq.com).
> Type the `Bearer ` prefix manually — do not paste from a document to avoid invisible characters.

### 2b. PostgreSQL

| Field | Value |
|-------|-------|
| Host | `postgres` |
| Port | `5432` |
| Database | `n8ndb` |
| Username | `n8nuser` |
| Password | `n8npass123` |
| SSL | Disabled |

> Use `postgres` (the Docker service name) as the host, not `localhost`.

### 2c. Gmail OAuth2

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project (or use an existing one)
3. Enable the **Gmail API** (APIs & Services → Library)
4. Go to **APIs & Services** → **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**
5. Application type: **Web application**
6. Add authorised redirect URI: `http://localhost:5678/rest/oauth2-credential/callback`
7. Copy the **Client ID** and **Client Secret**
8. In N8N, create a Gmail OAuth2 credential and paste those values
9. Click **Connect** and authorise with your Gmail account

> Recommended OAuth scopes: `https://www.googleapis.com/auth/gmail.send` and `https://www.googleapis.com/auth/userinfo.email` — no read or delete access needed.

---

## Step 3 — Wire Credentials to Nodes

After creating credentials, open the workflow and attach them:

| Node | Credential to attach |
|------|---------------------|
| HTTP Request (per-article Groq) | Header Auth (Groq API Key) |
| Grok Executive Briefing (HTTP Request) | Header Auth (Groq API Key) |
| Execute SQL (INSERT) | PostgreSQL |
| Aggregate Today's Data (PostgreSQL) | PostgreSQL |
| Save Briefing (PostgreSQL) | PostgreSQL |
| Send a message (Gmail) | Gmail OAuth2 |

---

## Step 4 — Configure the Gmail Send Node

Open the **Send a message** node and set:

- **Operation**: Send
- **To**: your email address (e.g. `yourname@gmail.com`)
- **Subject**: `MarketPulse Daily Briefing — {{ $now.toFormat('dd MMM yyyy') }}`
- **Email Type**: HTML
- **Message**: *(connected from Build HTML Email node — should already be wired)*

---

## Step 5 — Test Manually

1. Click **Execute Workflow** (the play button at the top)
2. Watch each node turn green
3. Check your inbox — the briefing email should arrive within 30–60 seconds
4. Verify data in PostgreSQL:

```sql
SELECT * FROM market_articles ORDER BY processed_at DESC LIMIT 10;
SELECT * FROM daily_briefings ORDER BY created_at DESC LIMIT 5;
```

Connect to the database with any PostgreSQL client (e.g. DBeaver, TablePlus, or psql):
- Host: `localhost`, Port: `5432`, DB: `n8ndb`, User: `n8nuser`, Password: `n8npass123`

---

## Step 6 — Activate for Daily Automation

1. Toggle the workflow to **Active** (top-right switch)
2. The Schedule Trigger is set to **7:30 AM on weekdays (Mon–Fri)**
3. To change the schedule, open the **Schedule Trigger** node and adjust the cron expression

> Default cron: `30 7 * * 1-5` (7:30 AM, Monday to Friday, Europe/Berlin timezone)

---

## Node-by-Node Reference

| # | Node | Type | Purpose |
|---|------|------|---------|
| 1 | Schedule Trigger | Trigger | Fires at 7:30 AM weekdays |
| 2 | RSS Read | RSS Feed | Fetches Yahoo Finance top finance stories |
| 3 | Code: Extract Articles | Code | Selects top 10 articles, normalises fields |
| 4 | Wait | Wait | 3-second delay between Groq API calls |
| 5 | HTTP Request | HTTP | Per-article LLM sentiment extraction (Groq) |
| 6 | Code in JavaScript1 | Code | Parses JSON response, merges with article data |
| 7 | Execute SQL | PostgreSQL | Inserts each article analysis row |
| 8 | Aggregate Today's Data | PostgreSQL | Counts bullish/bearish/neutral for today |
| 9 | Prepare Prompt | Code | Sanitises aggregate data, builds briefing prompt |
| 10 | Grok Executive Briefing | HTTP | Synthesises daily briefing text via Groq |
| 11 | Save Briefing | PostgreSQL | Persists daily briefing to `daily_briefings` |
| 12 | Build HTML Email | Code | Renders styled HTML email |
| 13 | Send a message | Gmail | Delivers briefing to your inbox |

---

## Troubleshooting

**RSS Read returns no items**
- The Yahoo Finance RSS URL sometimes requires a fresh Docker restart. Run `docker compose restart n8n`.
- Confirm URL is `https://finance.yahoo.com/rss/topfinstories` (no trailing slash).

**401 Unauthorized from Groq**
- Re-check that the Header Auth value is exactly `Bearer YOUR_KEY` with a space after `Bearer`.
- Type the value manually rather than pasting from a formatted document.

**PostgreSQL connection refused**
- Use `postgres` as the host (Docker service name), not `localhost`.
- Confirm the containers are healthy: `docker compose ps`.

**Gmail OAuth redirect mismatch**
- The redirect URI in Google Cloud Console must be exactly: `http://localhost:5678/rest/oauth2-credential/callback`

**Bad control character in JSON body**
- If you edit the Groq HTTP Request node body, ensure no newlines appear inside string values.
- The Prepare Prompt code node sanitises the `article_digest` field before it reaches the LLM.
