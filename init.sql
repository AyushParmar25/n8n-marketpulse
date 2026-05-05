-- MarketPulse Intelligence Agent — Database Schema
-- Auto-runs on first PostgreSQL container start via docker-entrypoint-initdb.d

-- Table: market_articles
-- Stores per-article LLM sentiment analysis results
CREATE TABLE IF NOT EXISTS market_articles (
    id               SERIAL PRIMARY KEY,
    ticker           VARCHAR(20)   NOT NULL DEFAULT 'GENERAL',
    title            TEXT          NOT NULL,
    url              TEXT,
    published_at     TIMESTAMPTZ,
    source           VARCHAR(100),
    grok_sentiment   VARCHAR(20),     -- bullish / bearish / neutral
    grok_confidence  NUMERIC(4,3),    -- 0.000 to 1.000
    grok_summary     TEXT,
    grok_key_events  TEXT,
    grok_risk_keywords TEXT,
    grok_implication TEXT,
    processed_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Index for fast date-range queries
CREATE INDEX IF NOT EXISTS idx_market_articles_processed_at
    ON market_articles (processed_at DESC);

-- Index for per-ticker queries
CREATE INDEX IF NOT EXISTS idx_market_articles_ticker
    ON market_articles (ticker);

-- Index for sentiment queries
CREATE INDEX IF NOT EXISTS idx_market_articles_sentiment
    ON market_articles (grok_sentiment);


-- Table: daily_briefings
-- Stores the synthesised executive briefing produced each run
CREATE TABLE IF NOT EXISTS daily_briefings (
    id                SERIAL PRIMARY KEY,
    briefing_date     DATE          NOT NULL DEFAULT CURRENT_DATE,
    overall_sentiment VARCHAR(20),
    executive_summary TEXT,
    articles_analyzed INTEGER       DEFAULT 0,
    email_sent        BOOLEAN       DEFAULT FALSE,
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Index for fast date lookups
CREATE INDEX IF NOT EXISTS idx_daily_briefings_date
    ON daily_briefings (briefing_date DESC);


-- Convenience view: sentiment counts per day
CREATE OR REPLACE VIEW daily_sentiment_summary AS
SELECT
    DATE(processed_at)                                              AS date,
    COUNT(*)                                                        AS total,
    COUNT(CASE WHEN grok_sentiment = 'bullish'  THEN 1 END)        AS bullish,
    COUNT(CASE WHEN grok_sentiment = 'bearish'  THEN 1 END)        AS bearish,
    COUNT(CASE WHEN grok_sentiment = 'neutral'  THEN 1 END)        AS neutral,
    ROUND(AVG(grok_confidence)::NUMERIC, 3)                        AS avg_confidence
FROM market_articles
GROUP BY DATE(processed_at)
ORDER BY date DESC;
