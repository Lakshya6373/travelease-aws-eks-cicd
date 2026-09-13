-- V1: Initial schema
-- Creates the three core tables with foreign keys and indexes.

CREATE TABLE IF NOT EXISTS destinations (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(200)   NOT NULL,
    country         VARCHAR(100)   NOT NULL,
    description     TEXT,
    price_per_night NUMERIC(10, 2) NOT NULL,
    image_url       VARCHAR(500),
    category        VARCHAR(50)    NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_destination_category ON destinations (category);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
    id            BIGSERIAL PRIMARY KEY,
    name          VARCHAR(200) NOT NULL,
    email         VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(20)  NOT NULL DEFAULT 'USER',
    CONSTRAINT uq_user_email UNIQUE (email)
);

CREATE INDEX IF NOT EXISTS idx_user_email ON users (email);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS bookings (
    id             BIGSERIAL PRIMARY KEY,
    user_id        BIGINT      NOT NULL REFERENCES users (id),
    destination_id BIGINT      NOT NULL REFERENCES destinations (id),
    check_in       DATE        NOT NULL,
    check_out      DATE        NOT NULL,
    guests         INTEGER     NOT NULL DEFAULT 1,
    status         VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    CONSTRAINT chk_booking_dates CHECK (check_out > check_in)
);

CREATE INDEX IF NOT EXISTS idx_booking_user ON bookings (user_id);
