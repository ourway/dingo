-- tables.sql
--
--   ___              _                   _ 
--  / __\_ _ _ __ ___| |__   ___  ___  __| |
-- / _\/ _` | '__/ __| '_ \ / _ \/ _ \/ _` |
--/ / | (_| | |  \__ \ | | |  __/  __/ (_| |
--\/   \__,_|_|  |___/_| |_|\___|\___|\__,_|
--
-- CLS tables sql file.

-- uuid-ossp extenstion for creation uuid4
-- https://www.postgresql.org/docs/devel/static/uuid-ossp.html
-- run \F5 in vim to create and setup and quick test

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Groups
-- Desc:
--      Each group is role.  for example admin role (a user must 
--      be in admin group to access to admin permissions)



-- files may be on S3 storage.  Etag is what returned by file server
CREATE TABLE files (
    id                  serial                          PRIMARY KEY,
    uuid                uuid                            UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    etag                text                     UNIQUE,
    filetype            text                     NOT NULL,
    filename            text                    NOT NULL,
    fpath               text                    UNIQUE NOT NULL,
    inserted_at         timestamp without time zone     DEFAULT CURRENT_TIMESTAMP,
    content_type        text                    NOT NULL
);

CREATE INDEX files_idx on files (filetype);

-- each user has a default group: user_<user_id>
CREATE TABLE groups (
    id                  serial                          PRIMARY KEY,
    uuid                uuid                            UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    is_active           boolean                         DEFAULT true,
    inserted_at         timestamp without time zone     DEFAULT CURRENT_TIMESTAMP,
    updated_at          timestamp without time zone     DEFAULT CURRENT_TIMESTAMP,
    role                text                     UNIQUE NOT NULL,
    description         text
);

CREATE INDEX group_idx on groups (role, is_active);


-- Users
CREATE TABLE users (
    id                  serial                          PRIMARY KEY,
    uuid                uuid                            UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    is_active           boolean                         DEFAULT false,
    inserted_at         timestamp without time zone     DEFAULT CURRENT_TIMESTAMP,
    updated_at          timestamp without time zone     DEFAULT CURRENT_TIMESTAMP,
    avatar_id           integer                         REFERENCES files(id) ON DELETE CASCADE,
    -- username must be 5 characters or greater
    username            text,
    password            text,
    first_name          text,
    last_name           text,
    email               text,
    confirmation_token  uuid                            UNIQUE DEFAULT uuid_generate_v4(),
    signin_token        uuid                            UNIQUE DEFAULT uuid_generate_v4(),
    extra_info          jsonb				DEFAULT '{}'
);
CREATE INDEX users_login_email_idx on users (is_active, email, password);
CREATE INDEX users_login_username_idx on users (is_active, username, password);
CREATE INDEX users_login_token_idx on users (is_active, signin_token);

CREATE TABLE tags (
    id                 serial                          PRIMARY KEY,
    uuid               uuid                            UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    name               text                            UNIQUE NOT NULL,
    inserted_at        timestamp without time zone     DEFAULT CURRENT_TIMESTAMP,
    creator_id         integer                         REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX tags_idx on tags (name);

-- sessions
CREATE TABLE sessions (
    id                  serial                          PRIMARY KEY,
    uuid                uuid                            UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    correlator          uuid                            UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    is_active           boolean                         DEFAULT false,
    user_id             integer                         REFERENCES users(id) ON DELETE CASCADE,
    inserted_at         timestamp without time zone     DEFAULT CURRENT_TIMESTAMP,
    updated_at          timestamp without time zone     DEFAULT CURRENT_TIMESTAMP,
    expires_at          timestamp without time zone     DEFAULT LOCALTIMESTAMP + INTERVAL '30 days',
    device              text,
    remote_ip           cidr
);

CREATE INDEX session_idx on sessions (user_id, uuid, is_active, expires_at);
CREATE INDEX session_correlator_idx on sessions (correlator);


-- Memberships
CREATE TABLE  memberships (
    id                  serial                          PRIMARY KEY,
    uuid                uuid                            UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    is_active           boolean                         DEFAULT true,
    inserted_at         timestamp without time zone     DEFAULT CURRENT_TIMESTAMP,
    updated_at          timestamp without time zone     DEFAULT CURRENT_TIMESTAMP,
    expires_at          timestamp without time zone,
    user_id             integer                         REFERENCES users(id) ON DELETE CASCADE,
    group_id            integer                         REFERENCES groups(id) ON DELETE CASCADE
);

CREATE INDEX member_idx on memberships (user_id, group_id, is_active, expires_at);
CREATE UNIQUE INDEX unique_membership_idx on memberships (user_id, group_id);

-- Permissions
CREATE TABLE permissions (
    id                  serial                          PRIMARY KEY,
    uuid                uuid                            UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    is_active           boolean                         DEFAULT true,
    inserted_at         timestamp without time zone     DEFAULT CURRENT_TIMESTAMP,
    updated_at          timestamp without time zone     DEFAULT CURRENT_TIMESTAMP,
    expires_at          timestamp without time zone,
    permission          text                            NOT NULL,
    group_id            integer                         REFERENCES groups(id) ON DELETE CASCADE
);

CREATE INDEX permission_idx on permissions (group_id, permission, is_active, expires_at);
CREATE UNIQUE INDEX uniqe_permissions_idx on permissions(permission, group_id);
