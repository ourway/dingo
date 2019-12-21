-- tables.sql
--
--   ___              _                   _
--  / __\_ _ _ __ ___| |__   ___  ___  __| |
-- / _\/ _` | '__/ __| '_ \ / _ \/ _ \/ _` |
--/ / | (_| | |  \__ \ | | |  __/  __/ (_| |
--\/   \__,_|_|  |___/_| |_|\___|\___|\__,_|
--
--Just remember: Each comment is like an apology!
--Clean code is much better than Cleaner comment
-- English Learning tables sql file.
-- uuid-ossp extenstion for creation uuid4
-- https://www.postgresql.org/docs/devel/static/uuid-ossp.html

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Groups
-- Desc:
--      Each group is role.  for example admin role (a user must
--      be in admin group to access to admin permissions)
-- files may be on S3 storage.  Etag is what returned by file server

CREATE TABLE files (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    etag text UNIQUE,
    filetype text NOT NULL,
    filename text NOT NULL,
    filepath text UNIQUE NOT NULL,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    content_type text NOT NULL
);

CREATE INDEX files_idx ON files (filetype);

-- each user has a default group: user_
CREATE TABLE GROUPS (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    is_active boolean DEFAULT TRUE,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    ROLE text UNIQUE NOT NULL,
    description text
);

CREATE INDEX group_idx ON GROUPS (ROLE, is_active);

-- OAuth2 type
-- https://tools.ietf.org/html/rfc6749

CREATE TYPE oauth2 AS ENUM (
    'google',
    'yahoo',
    'hotmail',
    'github',
    'dropbox',
    'amazon'
);

-- Users
CREATE TABLE users (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    is_active boolean DEFAULT FALSE,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    avatar_id integer REFERENCES files (id) ON DELETE CASCADE,
    -- username must be 5 characters or greater
    username text,
    PASSWORD text,
    first_name text NOT NULL,
    last_name text NOT NULL,
    email text,
    oauth2_type oauth2,
    oauth2_access_token text,
    oauth2_refresh_token text,
    oauth2_expires_on timestamp without time zone CHECK (oauth2_type IS NOT NULL),
    confirmation_token uuid UNIQUE DEFAULT uuid_generate_v4 (),
    signin_token uuid UNIQUE DEFAULT uuid_generate_v4 (),
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX users_login_email_idx ON users (is_active, email, PASSWORD);

CREATE INDEX users_login_username_idx ON users (is_active, username, PASSWORD);

CREATE INDEX users_login_token_idx ON users (is_active, signin_token);

CREATE TABLE tags (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    name text UNIQUE NOT NULL,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    creator_id integer REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX tags_idx ON tags (name);

-- sessions
CREATE TABLE sessions (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    correlator uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    is_active boolean DEFAULT FALSE,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    expires_at timestamp without time zone DEFAULT LOCALTIMESTAMP + INTERVAL '30 days',
    device text,
    remote_ip cidr
);

CREATE INDEX session_idx ON sessions (user_id, uuid, is_active, expires_at);

CREATE INDEX session_correlator_idx ON sessions (correlator);

-- Memberships
CREATE TABLE memberships (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    is_active boolean DEFAULT TRUE,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    expires_at timestamp without time zone,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    group_id integer REFERENCES GROUPS (id) ON DELETE CASCADE
);

CREATE INDEX member_idx ON memberships (user_id, group_id, is_active, expires_at);

CREATE UNIQUE INDEX unique_membership_idx ON memberships (user_id, group_id);

-- Permissions
CREATE TABLE permissions (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    is_active boolean DEFAULT TRUE,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    expires_at timestamp without time zone,
    permission text NOT NULL,
    group_id integer REFERENCES GROUPS (id) ON DELETE CASCADE
);

CREATE INDEX permission_idx ON permissions (group_id, permission, is_active, expires_at);

CREATE UNIQUE INDEX uniqe_permissions_idx ON permissions (permission, group_id);

CREATE TABLE partners (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    name text UNIQUE NOT NULL,
    slogan text,
    avatar_id integer REFERENCES files (id) ON DELETE CASCADE,
    partner_id integer REFERENCES partners (id) ON DELETE CASCADE,
    background_id integer REFERENCES files (id) ON DELETE CASCADE,
    is_active boolean DEFAULT TRUE,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    description tsvector,
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX partners_idx ON partners (is_active, name);

CREATE INDEX partners_desc_idx ON partners
USING GIN (description);

-- staff may create coupons in varoius ocasions
CREATE TABLE coupons (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    code text UNIQUE NOT NULL,
    discount float NOT NULL DEFAULT 10,
    max_amount money NOT NULL DEFAULT 5000,
    is_active boolean DEFAULT TRUE,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    creator_id integer REFERENCES users (id) ON DELETE CASCADE,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    expires_at timestamp without time zone DEFAULT LOCALTIMESTAMP + INTERVAL '90 days',
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX coupons_idx ON coupons (is_active, code, expires_at);

-- each user has a valet
CREATE TABLE valets (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    balance integer DEFAULT 0,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    extra_info jsonb DEFAULT '{}'
);

-- each user has a basket
CREATE TABLE baskets (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    extra_info jsonb DEFAULT '{}'
);

CREATE TABLE sections (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    title text UNIQUE NOT NULL,
    creator_id integer REFERENCES users (id) ON DELETE CASCADE,
    parent_id integer REFERENCES sections (id) ON DELETE CASCADE,
    background_id integer REFERENCES files (id) ON DELETE CASCADE,
    mobile_background_id integer REFERENCES files (id) ON DELETE CASCADE,
    is_active boolean DEFAULT FALSE,
    is_public boolean DEFAULT FALSE,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    expires_at timestamp without time zone,
    starts_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    description tsvector,
    tag_id integer REFERENCES tags (id) ON DELETE CASCADE,
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX sections_idx ON sections (is_active, is_public, title, expires_at, starts_at);

CREATE INDEX sections_desc_idx ON sections
USING GIN (description);

-- tutorials collection packs
CREATE TABLE collections (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    title text UNIQUE NOT NULL,
    preview_id integer REFERENCES files (id) ON DELETE CASCADE,
    creator_id integer REFERENCES users (id) ON DELETE CASCADE,
    poster_id integer REFERENCES files (id) ON DELETE CASCADE,
    mobile_poster_id integer REFERENCES files (id) ON DELETE CASCADE,
    background_id integer REFERENCES files (id) ON DELETE CASCADE,
    mobile_background_id integer REFERENCES files (id) ON DELETE CASCADE,
    discount float NOT NULL DEFAULT 0.0,
    thumbnail_id integer REFERENCES files (id) ON DELETE CASCADE,
    is_active boolean DEFAULT FALSE,
    is_public boolean DEFAULT FALSE,
    is_editors_pick boolean DEFAULT FALSE,
    is_gift boolean DEFAULT FALSE,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    starts_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    tag_id integer REFERENCES tags (id) ON DELETE CASCADE,
    expires_at timestamp without time zone,
    description tsvector,
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX collections_idx ON collections (is_active, is_public, title, starts_at, expires_at);

CREATE INDEX collections_desc_idx ON collections
USING GIN (description);

CREATE TYPE skill_level AS ENUM (
    'beginner',
    'intermediate',
    'advanced'
);

CREATE TABLE tutorials (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    title text UNIQUE NOT NULL,
    country text NOT NULL DEFAULT 'iran',
    preview_id integer REFERENCES files (id) ON DELETE CASCADE,
    partner_id integer REFERENCES partners (id) ON DELETE CASCADE,
    creator_id integer REFERENCES users (id) ON DELETE CASCADE,
    poster_id integer REFERENCES files (id) ON DELETE CASCADE,
    mobile_poster_id integer REFERENCES files (id) ON DELETE CASCADE,
    background_id integer REFERENCES files (id) ON DELETE CASCADE,
    mobile_background_id integer REFERENCES files (id) ON DELETE CASCADE,
    discount float NOT NULL DEFAULT 0.0,
    thumbnail_id integer REFERENCES files (id) ON DELETE CASCADE,
    is_active boolean DEFAULT FALSE,
    level skill_level DEFAULT 'intermediate',
    is_public boolean DEFAULT FALSE,
    is_editors_pick boolean DEFAULT FALSE,
    is_gift boolean DEFAULT FALSE,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    starts_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    tag_id integer REFERENCES tags (id) ON DELETE CASCADE,
    expires_at timestamp without time zone,
    description tsvector,
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX tutorials_idx ON tutorials (is_active, is_public, title, starts_at, expires_at);

CREATE INDEX tutorials_desc_idx ON tutorials
USING GIN (description);

CREATE TABLE collections_tutorials (
    id serial PRIMARY KEY,
    collection_id integer REFERENCES collections (id) ON DELETE CASCADE,
    tutorial_id integer REFERENCES tutorials (id) ON DELETE CASCADE
);

CREATE TYPE item_orientation AS ENUM (
    'landscape',
    'portraint',
    'square',
    'circle'
);

CREATE TYPE item_width AS ENUM (
    'small',
    'medium',
    'large',
    'verylarge'
);

CREATE TABLE boxes (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    title text UNIQUE NOT NULL,
    items_mode item_orientation NOT NULL DEFAULT 'landscape',
    creator_id integer REFERENCES users (id) ON DELETE CASCADE,
    section_id integer REFERENCES sections (id) ON DELETE CASCADE,
    background_id integer REFERENCES files (id) ON DELETE CASCADE,
    mobile_background_id integer REFERENCES files (id) ON DELETE CASCADE,
    items_width item_width NOT NULL DEFAULT 'medium',
    is_active boolean DEFAULT FALSE,
    is_public boolean DEFAULT FALSE,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    starts_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    expires_at timestamp without time zone,
    orderid integer DEFAULT 1,
    description tsvector,
    tag_id integer REFERENCES tags (id) ON DELETE CASCADE,
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX boxes_idx ON boxes (is_active, is_public, section_id, starts_at, expires_at);

CREATE INDEX boxes_desc_idx ON boxes
USING GIN (description);

CREATE TABLE boxes_tutorials (
    id serial PRIMARY KEY,
    box_id integer REFERENCES boxes (id) ON DELETE CASCADE,
    tutorial_id integer REFERENCES tutorials (id) ON DELETE CASCADE
);

CREATE TABLE boxes_sections (
    id serial PRIMARY KEY,
    box_id integer REFERENCES boxes (id) ON DELETE CASCADE,
    section_id integer REFERENCES sections (id) ON DELETE CASCADE
);

CREATE TABLE videos (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    stream_ticket text UNIQUE,
    stream_task uuid UNIQUE,
    name text UNIQUE NOT NULL,
    status text NOT NULL DEFAULT 'pending',
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    file_id integer REFERENCES files (id) ON DELETE CASCADE
);

CREATE TABLE medias (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    title text UNIQUE NOT NULL,
    preview_mp4 text UNIQUE,
    preview_mpd text UNIQUE,
    preview_m3u8 text UNIQUE,
    mp4 text UNIQUE,
    mpd text UNIQUE,
    m3u8 text UNIQUE,
    creator_id integer REFERENCES users (id) ON DELETE CASCADE,
    file_id integer REFERENCES files (id) ON DELETE CASCADE,
    preview_id integer REFERENCES files (id) ON DELETE CASCADE,
    poster_id integer REFERENCES files (id) ON DELETE CASCADE,
    mobile_poster_id integer REFERENCES files (id) ON DELETE CASCADE,
    background_id integer REFERENCES files (id) ON DELETE CASCADE,
    mobile_background_id integer REFERENCES files (id) ON DELETE CASCADE,
    price money NOT NULL DEFAULT 0,
    discount float NOT NULL DEFAULT 0.0,
    thumbnail_id integer REFERENCES files (id) ON DELETE CASCADE,
    subtitle_id integer REFERENCES files (id) ON DELETE CASCADE,
    is_active boolean DEFAULT FALSE,
    is_editors_pick boolean DEFAULT FALSE,
    is_gift boolean DEFAULT FALSE,
    is_ready boolean DEFAULT FALSE,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    tag_id integer REFERENCES tags (id) ON DELETE CASCADE,
    expires_at timestamp without time zone,
    description tsvector,
    review tsvector,
    syllabus tsvector NOT NULL,
    extra_info jsonb DEFAULT '{}'
);

CREATE TABLE medias_attachments (
    id serial PRIMARY KEY,
    attachment_id integer REFERENCES files (id) ON DELETE CASCADE,
    media_id integer REFERENCES files (id) ON DELETE CASCADE
);

-- each user by default has watch later and favorites playlist (on creation of course)
CREATE TABLE playlists (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    title text UNIQUE NOT NULL,
    user_generated boolean DEFAULT FALSE,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX playlists_idx ON playlists (user_id, title);

-- each media has playback options for every user
CREATE TABLE playbacks (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    media_id integer REFERENCES medias (id) ON DELETE CASCADE,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    playlist_id integer REFERENCES playlists (id) ON DELETE CASCADE,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    last_position float DEFAULT 0,
    rate smallint,
    note tsvector,
    marker_data jsonb DEFAULT '{}'
);

CREATE INDEX playbacks_idx ON playbacks (user_id, media_id, playlist_id);

CREATE INDEX playback_note_idx ON playbacks
USING GIN (note);

-- each tutorial has progress options for every user
CREATE TABLE tutorial_progress (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    tutorial_id integer REFERENCES tutorials (id) ON DELETE CASCADE,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    last_completed_media_id integer REFERENCES medias (id) ON DELETE CASCADE,
    note tsvector,
    marker_data jsonb DEFAULT '{}'
);

CREATE INDEX progress_idx ON tutorial_progress (user_id, tutorial_id);

CREATE INDEX progress_note_idx ON tutorial_progress
USING GIN (note);

-- each user has multi purchases
CREATE TABLE purchases (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    basket_id integer REFERENCES baskets (id) ON DELETE CASCADE,
    coupon_id integer REFERENCES coupons (id) ON DELETE CASCADE,
    tutorial_id integer REFERENCES tutorials (id) ON DELETE CASCADE,
    collection_id integer REFERENCES collections (id) ON DELETE CASCADE,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX purchases_idx ON purchases (basket_id, collection_id, tutorial_id);

CREATE TABLE ownerships (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    collection_id integer REFERENCES collections (id) ON DELETE CASCADE,
    tutorial_id integer REFERENCES tutorials (id) ON DELETE CASCADE,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    starts_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    expires_at timestamp without time zone DEFAULT LOCALTIMESTAMP + INTERVAL '3650 days'
);

CREATE INDEX tutorial_ownership_idx ON ownerships (tutorial_id, user_id, starts_at, expires_at);

CREATE INDEX collection_ownership_idx ON ownerships (collection_id, user_id, starts_at, expires_at);

CREATE TYPE ticket_status AS ENUM (
    'pending',
    'assigned',
    'waiting',
    'answered',
    'resolved',
    'rejected',
    'closed'
);

CREATE TABLE tickets (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    status ticket_status NOT NULL DEFAULT 'pending',
    staffer_id integer REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX tickets_staffer_idx ON tickets (staffer_id, status);

CREATE INDEX tickets_user_idx ON tickets (user_id, status);

CREATE TABLE comments (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    body text NOT NULL,
    is_approved boolean NOT NULL DEFAULT FALSE,
    is_public boolean NOT NULL DEFAULT FALSE,
    reviewer_id integer REFERENCES users (id) ON DELETE CASCADE,
    ticket_id integer REFERENCES tickets (id) ON DELETE CASCADE,
    media_id integer REFERENCES medias (id) ON DELETE CASCADE,
    tutorial_id integer REFERENCES tutorials (id) ON DELETE CASCADE,
    collection_id integer REFERENCES collections (id) ON DELETE CASCADE,
    writer_id integer REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE comments_attachments (
    id serial PRIMARY KEY,
    attachment_id integer REFERENCES files (id) ON DELETE CASCADE,
    comment_id integer REFERENCES comments (id) ON DELETE CASCADE
);

CREATE TABLE subscriptions (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    inserted_at timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active boolean DEFAULT FALSE,
    expires_at timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP + INTERVAL '10 days',
    access_level text NOT NULL DEFAULT 'basic' -- premuim/
);

CREATE INDEX subscriptions_idx ON subscriptions (user_id, expires_at, is_active);

CREATE TABLE invoices (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    is_completed boolean NOT NULL DEFAULT FALSE,
    note text,
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    expires_at timestamp without time zone DEFAULT LOCALTIMESTAMP + INTERVAL '30 days'
);

CREATE INDEX invoices_idx ON invoices (user_id, expires_at, is_completed);

CREATE TABLE invoices_times (
    id serial PRIMARY KEY,
    collection_id integer REFERENCES collections (id) ON DELETE CASCADE,
    tutorial_id integer REFERENCES tutorials (id) ON DELETE CASCADE,
    subscription_id integer REFERENCES subscriptions (id) ON DELETE CASCADE,
    invoice_id integer REFERENCES invoices (id) ON DELETE CASCADE
);

CREATE TYPE log_level AS ENUM (
    'debug',
    'warning',
    'info',
    'error',
    'critical'
);

-- every activity will be logged
CREATE TABLE logs (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    inserted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    level log_level NOT NULL DEFAULT 'debug',
    scope text NOT NULL,
    body text NOT NULL,
    media_id integer REFERENCES medias (id),
    user_id integer REFERENCES medias (id),
    purchase_id integer REFERENCES purchases (id),
    session_id integer REFERENCES sessions (id),
    tutorial_id integer REFERENCES tutorials (id),
    partner_id integer REFERENCES partners (id),
    basket_id integer REFERENCES baskets (id),
    playback_id integer REFERENCES playbacks (id),
    ownership_id integer REFERENCES ownerships (id),
    playlist_id integer REFERENCES playlists (id),
    valet_id integer REFERENCES valets (id),
    coupon_id integer REFERENCES coupons (id),
    collection_id integer REFERENCES collections (id),
    box_id integer REFERENCES boxes (id),
    invoice_id integer REFERENCES invoices (id),
    subscription_id integer REFERENCES subscriptions (id),
    comment_id integer REFERENCES comments (id)
);
