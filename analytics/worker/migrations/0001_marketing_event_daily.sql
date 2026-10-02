CREATE TABLE IF NOT EXISTS marketing_event_daily (
  day TEXT NOT NULL,
  country TEXT NOT NULL,
  region_code TEXT NOT NULL DEFAULT '',
  locale TEXT NOT NULL,
  client TEXT NOT NULL,
  device_class TEXT NOT NULL,
  page TEXT NOT NULL,
  experiment TEXT NOT NULL DEFAULT '',
  variant TEXT NOT NULL DEFAULT 'default',
  source TEXT NOT NULL DEFAULT 'other',
  medium TEXT NOT NULL DEFAULT 'other',
  campaign TEXT NOT NULL DEFAULT 'none',
  event TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (day, country, region_code, locale, client, device_class, page, experiment, variant, source, medium, campaign, event)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS marketing_event_daily_market
  ON marketing_event_daily (day, country, region_code, page, experiment, variant);
