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


-- New stuff in pg12
-- \pset format csv
-- REINDEX CONCURRENTLY
-- GENERATED ALWAYS AS ( km * 1.852 ) STORED,
-- FOR SHARE
-- FOR UPDATE
-- BEGIN TRANSACTION READ ONLY;
-- COMMIT AND CHAIN; COMMIT AND NO CHAIN (COMMIT);
-- ROLLBACK TO SAVEPOINT X; RELEASE SAVEPOINT X;
-- DDLs - Creating and altering a table inside a transaction block is possible with ability to rollback!
--  Using single deployment transactions is good software practice.
-- MVCC is multi version concurrency control.
-- Locking a transaction
-- use SELECT FOR UPDATE inside transactions
-- For reports, you use: BEGIN TRANSACTION WITH ISOLATION LEVEL REPEATABLE READ;
-- Using pg_advisory_lock and pg_advisory_unlock
-- Setting random_page_cost = 1 for SSD storage makes sense.
-- analyzing with EXPLAIN (analyze true, buffers true)
-- finding correlation with SELECT tablename, attname, correlation FROM pg_stats WHERE tablename IN ('test1', 'sometable') ORDER BY 1, 2;
-- Correlation has important effect on query execution time. If equals 1, it's the best senario (data is sequenced).
-- Using cluster to improve correlation. Cluster will Lock table and can only use 1 index.
-- CLUSTER mytable USING idx_index_name;
-- You need to VACUUM ANAZLIZE the table before it can be seen on pg_stats.





CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-----------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION timestamp_update_func()
    RETURNS trigger AS
        $$
            BEGIN
                NEW.updated_at = now();
                IF OLD.inserted_at IS NULL THEN
                    NEW.inserted_at = now();
                END IF;
                RETURN NEW;
            END;
        $$
LANGUAGE 'plpgsql';

-----------------------------------------------------------------------------------------------------------------


-- Groups
-- Desc:
--      Each group is role.  for example admin role (a user must
--      be in admin group to access to admin permissions)
-- files may be on S3 storage.  Etag is what returned by file server

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE files (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    etag TEXT UNIQUE,
    filetype TEXT NOT NULL,
    filename TEXT NOT NULL,
    filepath TEXT UNIQUE NOT NULL,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    content_type TEXT NOT NULL
);

CREATE INDEX files_idx ON files (filetype);

-----------------------------------------------------------------------------------------------------------------
-- each user has a default group: user_
CREATE TABLE GROUPS (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    is_active BOOLEAN DEFAULT TRUE,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    role TEXT UNIQUE NOT NULL,
    description TEXT
);

CREATE INDEX group_idx ON GROUPS (role, is_active);

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

-----------------------------------------------------------------------------------------------------------------
CREATE TYPE gender AS ENUM (
    'male',
    'female',
    'N/A'
);

-----------------------------------------------------------------------------------------------------------------

CREATE TABLE users (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL UNIQUE DEFAULT uuid_generate_v4(),
    is_super_user BOOLEAN NOT NULL DEFAULT FALSE,
    accepted_terms BOOLEAN NOT NULL DEFAULT FALSE,
    -- email

    email TEXT NOT NULL UNIQUE,
    email_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    email_confirmation_token uuid UNIQUE DEFAULT uuid_generate_v4(),
    email_confirmation_expires_on TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    -- cellphone

    cellphone BIGINT,
    cellphone_activated BOOLEAN NOT NULL DEFAULT FALSE,
    cellphone_activation_code INTEGER NOT NULL DEFAULT floor(random() * (999999-100000) + 100000)::int,
    cellphone_activation_expires_on TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '2 minutes'),

    -- password
    passwd TEXT,
    oldhash TEXT,
    salt TEXT NOT NULL DEFAULT gen_salt('bf'),

    passwd_change_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    passwd_change_confirmation_token uuid UNIQUE DEFAULT uuid_generate_v4(),
    passwd_change_confirmation_expires_on TIMESTAMP WITHOUT TIME ZONE DEFAULT (NOW() + INTERVAL '2 hours'),

    -- OAUTH2
    oauth2_type oauth2,
    oauth2_access_token TEXT,
    oauth2_refresh_token TEXT,
    oauth2_expires_on TIMESTAMP WITHOUT TIME ZONE,

    -- profile
    firstname TEXT,
    lastname TEXT,
    gender gender,
    username TEXT UNIQUE,
    profile JSONB DEFAULT '{}',
    group_id INTEGER REFERENCES GROUPS (id) ON DELETE CASCADE,

    -- scaling ...
    extra_info JSONB DEFAULT '{}',

    -- primary security 
    is_active BOOLEAN DEFAULT FALSE,
    confirmation_token uuid UNIQUE DEFAULT uuid_generate_v4 (),

    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT user_cellphone_action_confirmation_only_if_there_is_a_cellphone CHECK (((cellphone_activated IS FALSE) OR (cellphone IS NOT NULL))),
    CONSTRAINT user_email_is_valid CHECK (((email)::text ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'::text)),
    CONSTRAINT user_name_must_be_null_or_at_least_5_chars CHECK (((username IS NULL) OR (length((username)::text) >= 5))),
    CONSTRAINT user_oauth2_access_token_is_null_or_oauth2_type_is_not_null CHECK (((oauth2_refresh_token IS NULL) OR (oauth2_type IS NOT NULL))),
    CONSTRAINT user_oauth2_refresh_token_is_null_or_oauth2_type_is_not_null CHECK (((oauth2_access_token IS NULL) OR (oauth2_type IS NOT NULL))),
    CONSTRAINT user_password_action_confirmation_only_if_there_is_a_passwd CHECK (((passwd_change_confirmed IS FALSE) OR (passwd IS NOT NULL))),
    CONSTRAINT user_phone_is_valid CHECK (((cellphone IS NULL) OR ((cellphone)::text ~ '^(\d{1,3}\d{10})$'::text)))
);

CREATE INDEX users_email ON users (is_active, email);
CREATE UNIQUE INDEX users_is_super_user_idx ON users (is_super_user) WHERE (is_super_user = true);


-- TODO: lots to do here. (I need to check old elixir project)


CREATE TRIGGER 
    users_timestamps_update_trigger
        BEFORE UPDATE OR INSERT
            ON users
            FOR EACH ROW
            EXECUTE PROCEDURE timestamp_update_func();



-----------------------------------------------------------------------------------------------------------------
CREATE TABLE tags (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    name TEXT UNIQUE NOT NULL,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    creator_id integer REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX tags_idx ON tags (name);

CREATE TRIGGER 
    tags_timestamps_update_trigger
        BEFORE UPDATE OR INSERT
            ON tags
            FOR EACH ROW
            EXECUTE PROCEDURE timestamp_update_func();

-----------------------------------------------------------------------------------------------------------------
-- sessions
CREATE TABLE sessions (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    correlator uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    is_active BOOLEAN DEFAULT FALSE,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITHOUT TIME ZONE DEFAULT LOCALTIMESTAMP + INTERVAL '30 days',
    device TEXT,
    remote_ip cidr
);

CREATE INDEX session_idx ON sessions (user_id, uuid, is_active, expires_at);

CREATE INDEX session_correlator_idx ON sessions (correlator);

-----------------------------------------------------------------------------------------------------------------
-- Memberships
CREATE TABLE memberships (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    is_active BOOLEAN DEFAULT TRUE,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITHOUT TIME ZONE,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    group_id integer REFERENCES GROUPS (id) ON DELETE CASCADE
);

CREATE INDEX member_idx ON memberships (user_id, group_id, is_active, expires_at);

CREATE UNIQUE INDEX unique_membership_idx ON memberships (user_id, group_id);

-----------------------------------------------------------------------------------------------------------------
-- Permissions
CREATE TABLE permissions (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    is_active BOOLEAN DEFAULT TRUE,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITHOUT TIME ZONE,
    permission TEXT NOT NULL,
    group_id integer REFERENCES GROUPS (id) ON DELETE CASCADE
);

CREATE INDEX permission_idx ON permissions (group_id, permission, is_active, expires_at);

CREATE UNIQUE INDEX uniqe_permissions_idx ON permissions (permission, group_id);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE partners (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    name TEXT UNIQUE NOT NULL,
    slogan TEXT,
    avatar_id integer REFERENCES files (id) ON DELETE CASCADE,
    partner_id integer REFERENCES partners (id) ON DELETE CASCADE,
    background_id integer REFERENCES files (id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT TRUE,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    description tsvector,
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX partners_idx ON partners (is_active, name);

CREATE INDEX partners_desc_idx ON partners
USING GIN (description);

-----------------------------------------------------------------------------------------------------------------
-- staff may create coupons in varoius ocasions
CREATE TABLE coupons (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    code TEXT UNIQUE NOT NULL,
    discount float NOT NULL DEFAULT 10,
    max_amount money NOT NULL DEFAULT 5000,
    is_active BOOLEAN DEFAULT TRUE,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    creator_id integer REFERENCES users (id) ON DELETE CASCADE,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITHOUT TIME ZONE DEFAULT LOCALTIMESTAMP + INTERVAL '90 days',
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX coupons_idx ON coupons (is_active, code, expires_at);

-----------------------------------------------------------------------------------------------------------------
-- each user has a walet
CREATE TABLE walets (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    balance integer DEFAULT 0,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    extra_info jsonb DEFAULT '{}'
);

-----------------------------------------------------------------------------------------------------------------
-- each user has a basket
CREATE TABLE baskets (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    extra_info jsonb DEFAULT '{}'
);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE sections (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    title TEXT UNIQUE NOT NULL,
    creator_id integer REFERENCES users (id) ON DELETE CASCADE,
    parent_id integer REFERENCES sections (id) ON DELETE CASCADE,
    background_id integer REFERENCES files (id) ON DELETE CASCADE,
    mobile_background_id integer REFERENCES files (id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT FALSE,
    is_public BOOLEAN DEFAULT FALSE,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITHOUT TIME ZONE,
    starts_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    description tsvector,
    tag_id integer REFERENCES tags (id) ON DELETE CASCADE,
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX sections_idx ON sections (is_active, is_public, title, expires_at, starts_at);

CREATE INDEX sections_desc_idx ON sections
USING GIN (description);

-----------------------------------------------------------------------------------------------------------------
-- tutorials collection packs
CREATE TABLE collections (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    title TEXT UNIQUE NOT NULL,
    preview_id integer REFERENCES files (id) ON DELETE CASCADE,
    creator_id integer REFERENCES users (id) ON DELETE CASCADE,
    poster_id integer REFERENCES files (id) ON DELETE CASCADE,
    mobile_poster_id integer REFERENCES files (id) ON DELETE CASCADE,
    background_id integer REFERENCES files (id) ON DELETE CASCADE,
    mobile_background_id integer REFERENCES files (id) ON DELETE CASCADE,
    discount float NOT NULL DEFAULT 0.0,
    thumbnail_id integer REFERENCES files (id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT FALSE,
    is_public BOOLEAN DEFAULT FALSE,
    is_editors_pick BOOLEAN DEFAULT FALSE,
    is_gift BOOLEAN DEFAULT FALSE,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    starts_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    tag_id integer REFERENCES tags (id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITHOUT TIME ZONE,
    description tsvector,
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX collections_idx ON collections (is_active, is_public, title, starts_at, expires_at);

CREATE INDEX collections_desc_idx ON collections
USING GIN (description);

-----------------------------------------------------------------------------------------------------------------
CREATE TYPE skill_level AS ENUM (
    'beginner',
    'intermediate',
    'advanced'
);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE tutorials (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    title TEXT UNIQUE NOT NULL,
    country TEXT NOT NULL DEFAULT 'iran',
    preview_id integer REFERENCES files (id) ON DELETE CASCADE,
    partner_id integer REFERENCES partners (id) ON DELETE CASCADE,
    creator_id integer REFERENCES users (id) ON DELETE CASCADE,
    poster_id integer REFERENCES files (id) ON DELETE CASCADE,
    mobile_poster_id integer REFERENCES files (id) ON DELETE CASCADE,
    background_id integer REFERENCES files (id) ON DELETE CASCADE,
    mobile_background_id integer REFERENCES files (id) ON DELETE CASCADE,
    discount float NOT NULL DEFAULT 0.0,
    thumbnail_id integer REFERENCES files (id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT FALSE,
    level skill_level DEFAULT 'intermediate',
    is_public BOOLEAN DEFAULT FALSE,
    is_editors_pick BOOLEAN DEFAULT FALSE,
    is_gift BOOLEAN DEFAULT FALSE,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    starts_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    tag_id integer REFERENCES tags (id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITHOUT TIME ZONE,
    description tsvector,
    extra_info jsonb DEFAULT '{}'
);

-----------------------------------------------------------------------------------------------------------------
CREATE INDEX tutorials_idx ON tutorials (is_active, is_public, title, starts_at, expires_at);

CREATE INDEX tutorials_desc_idx ON tutorials
USING GIN (description);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE collections_tutorials (
    id serial PRIMARY KEY,
    collection_id integer REFERENCES collections (id) ON DELETE CASCADE,
    tutorial_id integer REFERENCES tutorials (id) ON DELETE CASCADE
);

-----------------------------------------------------------------------------------------------------------------
CREATE TYPE item_orientation AS ENUM (
    'landscape',
    'portraint',
    'square',
    'circle'
);

-----------------------------------------------------------------------------------------------------------------
CREATE TYPE item_width AS ENUM (
    'small',
    'medium',
    'large',
    'verylarge'
);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE boxes (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    title TEXT UNIQUE NOT NULL,
    items_mode item_orientation NOT NULL DEFAULT 'landscape',
    creator_id integer REFERENCES users (id) ON DELETE CASCADE,
    section_id integer REFERENCES sections (id) ON DELETE CASCADE,
    background_id integer REFERENCES files (id) ON DELETE CASCADE,
    mobile_background_id integer REFERENCES files (id) ON DELETE CASCADE,
    items_width item_width NOT NULL DEFAULT 'medium',
    is_active BOOLEAN DEFAULT FALSE,
    is_public BOOLEAN DEFAULT FALSE,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    starts_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITHOUT TIME ZONE,
    orderid integer DEFAULT 1,
    description tsvector,
    tag_id integer REFERENCES tags (id) ON DELETE CASCADE,
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX boxes_idx ON boxes (is_active, is_public, section_id, starts_at, expires_at);

CREATE INDEX boxes_desc_idx ON boxes
USING GIN (description);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE boxes_tutorials (
    id serial PRIMARY KEY,
    box_id integer REFERENCES boxes (id) ON DELETE CASCADE,
    tutorial_id integer REFERENCES tutorials (id) ON DELETE CASCADE
);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE boxes_sections (
    id serial PRIMARY KEY,
    box_id integer REFERENCES boxes (id) ON DELETE CASCADE,
    section_id integer REFERENCES sections (id) ON DELETE CASCADE
);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE videos (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    stream_ticket TEXT UNIQUE,
    stream_task uuid UNIQUE,
    name TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    file_id integer REFERENCES files (id) ON DELETE CASCADE
);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE medias (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    title TEXT UNIQUE NOT NULL,
    preview_mp4 TEXT UNIQUE,
    preview_mpd TEXT UNIQUE,
    preview_m3u8 TEXT UNIQUE,
    mp4 TEXT UNIQUE,
    mpd TEXT UNIQUE,
    m3u8 TEXT UNIQUE,
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
    is_active BOOLEAN DEFAULT FALSE,
    is_editors_pick BOOLEAN DEFAULT FALSE,
    is_gift BOOLEAN DEFAULT FALSE,
    is_ready BOOLEAN DEFAULT FALSE,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    tag_id integer REFERENCES tags (id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITHOUT TIME ZONE,
    description tsvector,
    review tsvector,
    syllabus tsvector NOT NULL,
    extra_info jsonb DEFAULT '{}'
);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE medias_attachments (
    id serial PRIMARY KEY,
    attachment_id integer REFERENCES files (id) ON DELETE CASCADE,
    media_id integer REFERENCES files (id) ON DELETE CASCADE
);

-----------------------------------------------------------------------------------------------------------------
-- each user by default has watch later and favorites playlist (on creation of course)
CREATE TABLE playlists (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    title TEXT UNIQUE NOT NULL,
    user_generated BOOLEAN DEFAULT FALSE,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX playlists_idx ON playlists (user_id, title);

-----------------------------------------------------------------------------------------------------------------
-- each media has playback options for every user
CREATE TABLE playbacks (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    media_id integer REFERENCES medias (id) ON DELETE CASCADE,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    playlist_id integer REFERENCES playlists (id) ON DELETE CASCADE,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_position float DEFAULT 0,
    rate smallint,
    note tsvector,
    marker_data jsonb DEFAULT '{}'
);

CREATE INDEX playbacks_idx ON playbacks (user_id, media_id, playlist_id);

CREATE INDEX playback_note_idx ON playbacks
USING GIN (note);

-----------------------------------------------------------------------------------------------------------------
-- each tutorial has progress options for every user
CREATE TABLE tutorial_progress (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    tutorial_id integer REFERENCES tutorials (id) ON DELETE CASCADE,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_completed_media_id integer REFERENCES medias (id) ON DELETE CASCADE,
    note tsvector,
    marker_data jsonb DEFAULT '{}'
);

CREATE INDEX progress_idx ON tutorial_progress (user_id, tutorial_id);

CREATE INDEX progress_note_idx ON tutorial_progress
USING GIN (note);

-----------------------------------------------------------------------------------------------------------------
-- each user has multi purchases
CREATE TABLE purchases (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    basket_id integer REFERENCES baskets (id) ON DELETE CASCADE,
    coupon_id integer REFERENCES coupons (id) ON DELETE CASCADE,
    tutorial_id integer REFERENCES tutorials (id) ON DELETE CASCADE,
    collection_id integer REFERENCES collections (id) ON DELETE CASCADE,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    extra_info jsonb DEFAULT '{}'
);

CREATE INDEX purchases_idx ON purchases (basket_id, collection_id, tutorial_id);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE ownerships (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    collection_id integer REFERENCES collections (id) ON DELETE CASCADE,
    tutorial_id integer REFERENCES tutorials (id) ON DELETE CASCADE,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    starts_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITHOUT TIME ZONE DEFAULT LOCALTIMESTAMP + INTERVAL '3650 days'
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

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE tickets (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status ticket_status NOT NULL DEFAULT 'pending',
    staffer_id integer REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX tickets_staffer_idx ON tickets (staffer_id, status);

CREATE INDEX tickets_user_idx ON tickets (user_id, status);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE comments (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    body TEXT NOT NULL,
    is_approved BOOLEAN NOT NULL DEFAULT FALSE,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    reviewer_id integer REFERENCES users (id) ON DELETE CASCADE,
    ticket_id integer REFERENCES tickets (id) ON DELETE CASCADE,
    media_id integer REFERENCES medias (id) ON DELETE CASCADE,
    tutorial_id integer REFERENCES tutorials (id) ON DELETE CASCADE,
    collection_id integer REFERENCES collections (id) ON DELETE CASCADE,
    writer_id integer REFERENCES users (id) ON DELETE CASCADE,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE comments_attachments (
    id serial PRIMARY KEY,
    attachment_id integer REFERENCES files (id) ON DELETE CASCADE,
    comment_id integer REFERENCES comments (id) ON DELETE CASCADE
);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE subscriptions (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    inserted_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT FALSE,
    expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT LOCALTIMESTAMP + INTERVAL '10 days',
    access_level TEXT NOT NULL DEFAULT 'basic' -- premuim/
);

CREATE INDEX subscriptions_idx ON subscriptions (user_id, expires_at, is_active);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE invoices (
    id serial PRIMARY KEY,
    uuid uuid UNIQUE NOT NULL DEFAULT uuid_generate_v4 (),
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    note TEXT,
    inserted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    user_id integer REFERENCES users (id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITHOUT TIME ZONE DEFAULT LOCALTIMESTAMP + INTERVAL '30 days'
);

CREATE INDEX invoices_idx ON invoices (user_id, expires_at, is_completed);

-----------------------------------------------------------------------------------------------------------------
CREATE TABLE invoices_times (
    id serial PRIMARY KEY,
    collection_id integer REFERENCES collections (id) ON DELETE CASCADE,
    tutorial_id integer REFERENCES tutorials (id) ON DELETE CASCADE,
    subscription_id integer REFERENCES subscriptions (id) ON DELETE CASCADE,
    invoice_id integer REFERENCES invoices (id) ON DELETE CASCADE
);

-----------------------------------------------------------------------------------------------------------------
-- Creating user groups and related permissions for normal guest group
-- User may have basic permissions even before activating his/her email
-- address. After each confirmation, more permissions might be added to
-- user. Here is the function for adding uesr specific group.

CREATE OR REPLACE FUNCTION user_after_insert_or_update_funcs ()
    RETURNS TRIGGER
    AS $$
    -- after every insert, return into `lastid` var.
DECLARE
    lastid BIGINT;
    DECLARE field TEXT;
BEGIN
    -- *****************************************************************
    -- Lets create a group for user (ON INSERT ONLY)
    IF OLD.id IS NULL THEN
        INSERT INTO GROUPS (ROLE)
        VALUES ('user_' || NEW.id || '_group')
    RETURNING
        id INTO lastid;
        --------------------------------------------------------------------
        -- Now we attach the newly created user to this group
        -- using membership table:
        INSERT INTO memberships (user_id, group_id)
        VALUES (NEW.id, lastid);
        --------------------------------------------------------------------
        -- Let's add some permissions to newly added
        -- user. Of course user is not email-validated
        -- but he/she must be able to login and edit
        -- basic information.
        FOREACH field IN ARRAY ARRAY['edit_profile', 'purchase', 'login'] LOOP
            INSERT INTO permissions (group_id, permission)
            VALUES (lastid, field);
        END LOOP;
        --------------------------------------------------------------------
        -- Add permissions to super admin user:
        IF NEW.is_super_user IS TRUE THEN
            FOREACH field IN ARRAY ARRAY['manage_users'] LOOP
                INSERT INTO permissions (group_id, permission)
                VALUES (lastid, field);
            END LOOP;
        END IF;
    END IF;
    ---------------------------------------------------------------------
    IF OLD.email <> NEW.email IS TRUE
    THEN
        -- do something here
    END IF;
    ---------------------------------------------------------------------
    IF NEW.cellphone IS NOT NULL
        -- check if it's changing
        AND OLD.cellphone <> NEW.cellphone IS NOT FALSE THEN
        -- an SMS will queued (and must be send by app) to validate action:
    END IF;
    ---------------------------------------------------------------------
    IF OLD.cellphone_activated IS FALSE AND NEW.cellphone_activated IS TRUE THEN
        -- inform user she is activated
    END IF;
    ---------------------------------------------------------------------
    IF NEW.passwd IS NOT NULL AND OLD.passwd <> NEW.passwd IS NOT FALSE THEN
        -- do something
    END IF;
    ---------------------------------------------------------------------
    RETURN NEW;
    -- *****************************************************************
END;
$$
LANGUAGE 'plpgsql';

-----------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION user_before_insert_or_update_funcs ()
    RETURNS TRIGGER
    AS $$
    -- store newhash
DECLARE
    newhash TEXT;
    -- for logbody
    DECLARE logbody TEXT;
    -- for email body
    DECLARE old_users_count INT;
BEGIN
    --****************************************************************--
    ---------------------------------------------------------------------
    -- in password update
    -- Since we don't know the old password, we have to calculate it anyway.
    -- if new password is null, then it means user disabled it's password
    -- which is ok by the way.
    IF NEW.passwd IS NOT NULL AND OLD.passwd <> NEW.passwd IS NOT FALSE THEN
        IF NEW.passwd !~ '^(?=.*[A-Z])(?=.*[0-9])(?=.*[a-z]).{8,}$' AND NEW.passwd IS NOT NULL THEN
            RAISE EXCEPTION 'Weak password.';
        END IF;
        -- Lets encrypt the password
        newhash = crypt(NEW.passwd, NEW.salt);
        -- Now let's check if password actually has changed or not.
        IF newhash <> NEW.oldhash IS NOT FALSE THEN
            NEW.passwd = newhash;
            NEW.oldhash = newhash;
            -- password change will result to account deactivation and user is required to
            NEW.passwd_change_confirmed = FALSE;
            -- regenerate token
            NEW.passwd_change_confirmation_token = uuid_generate_v4 ();
            -- extend expiration
            NEW.passwd_change_confirmation_expires_on = NOW() + INTERVAL '2 hours';
        ELSE
            -- This is where there is no change in password.
            -- password is same as before, so pass the old hash as new password,
            NEW.passwd = newhash;
        END IF;
    END IF;
    ---------------------------------------------------------------------
    -- Checks on password confirmation process
    -- check if password confirmation status is changing from nagative to affirmative:
    IF OLD.passwd_change_confirmed IS FALSE AND NEW.passwd_change_confirmed IS TRUE THEN
        -- Check if confirmation deadline is not reached:
        -- If deadline is past, raise
        IF OLD.passwd_change_confirmation_expires_on < NOW() THEN
            RAISE EXCEPTION 'Password confirmation token has been expired.';
        END IF;
        -- check if password is not null
        -- if password is null, raise
        IF NEW.passwd IS NULL THEN
            RAISE EXCEPTION 'Password is empty.';
        ELSE
            -- ok, not confirmation can proceed
            -- expire confirmation deadline:
            NEW.passwd_change_confirmation_expires_on = NOW() - INTERVAL '1 year';
            -- expire confirmation token:
            NEW.passwd_change_confirmation_token = uuid_generate_v4 ();
        END IF;
    END IF;
    ---------------------------------------------------------------------
    -- check if user changes his/her email:
    -- Since we should have email, we don't except email to be NULL on update.
    IF OLD.email <> NEW.email IS TRUE
        -- or may be it's insert mode:
        OR OLD.email IS NULL THEN
        -- make sure email status changes to not confirmed
        NEW.email = LOWER(NEW.email);
        NEW.email_confirmed = FALSE;
        -- regerate confirmation token.
        NEW.email_confirmation_token = uuid_generate_v4 ();
        -- extend expiration time
        NEW.email_confirmation_expires_on = NOW() + INTERVAL '12 hours';
    END IF;
    ---------------------------------------------------------------------
    -- check email confirmation conditions:
    -- check if status is changing from false to true;
    IF OLD.email_confirmed = FALSE AND NEW.email_confirmed IS TRUE THEN
        -- if confirmation deadline is reached, raise
        IF OLD.email_confirmation_expires_on < NOW() THEN
            RAISE EXCEPTION 'Email confirmation token has been expired.';
        ELSE
            -- expire confirmation deadline:
            NEW.email_confirmation_expires_on = NOW() - INTERVAL '1 year';
            -- regenerate email confirmation token:
            NEW.email_confirmation_token = uuid_generate_v4 ();
        END IF;
    END IF;
    ---------------------------------------------------------------------
    -- check if user changes his/her cellphone number:
    -- check if it's insert
    IF NEW.cellphone IS NOT NULL
        -- check if it's changing
        AND OLD.cellphone <> NEW.cellphone IS NOT FALSE THEN
        RAISE NOTICE 'Cellphone Confirmation required for %.', NEW.cellphone;
        NEW.cellphone_activated = FALSE;
        NEW.cellphone_activation_code = floor(random() * (999999 - 100000) + 100000)::int;
        NEW.cellphone_activation_expires_on = NOW() + INTERVAL '2 minutes';
    END IF;
    ---------------------------------------------------------------------
    -- Check if it's activating
    IF OLD.cellphone_activated IS FALSE AND NEW.cellphone_activated IS TRUE THEN
        -- check if deadline is reached
        IF OLD.cellphone_activation_expires_on < NOW() THEN
            RAISE EXCEPTION 'Cellphone confirmation token has been expired.';
        ELSE
            -- check if it's not null now
            IF NEW.cellphone IS NULL THEN
                RAISE EXCEPTION 'Cellphone is NULL.';
            END IF;
            NEW.cellphone_activation_expires_on = NOW() - INTERVAL '1 year';
        END IF;
    END IF;

    SELECT count(id) from users limit 2 into old_users_count;
    IF old_users_count < 2 THEN
        -- RAISE NOTICE 'Super user created for %.', NEW.email;
        NEW.is_super_user = 't';
    END IF;


    ---------------------------------------------------------------------
    RETURN NEW;
    --****************************************************************--
END;
$$
LANGUAGE 'plpgsql';

CREATE TRIGGER user_creation_trigger
 AFTER INSERT OR UPDATE
 ON users
 FOR EACH ROW
   EXECUTE PROCEDURE user_after_insert_or_update_funcs();


CREATE TRIGGER user_update_trigger
 BEFORE UPDATE OR INSERT
 ON users
 FOR EACH ROW
   EXECUTE PROCEDURE user_before_insert_or_update_funcs();






