-- Creating user groups and related permissions for normal guest group
-- User may have basic permissions even before activating his/her email
-- address. After each confirmation, more permissions might be added to
-- user. Here is the function for adding uesr specific group.

CREATE OR REPLACE FUNCTION user_after_insert_funcs ()
    RETURNS TRIGGER
    AS $$
    -- after every insert, return into `lastid` var.
DECLARE
    lastid BIGINT;
    DECLARE field text;
    DECLARE logbody text;
    -- for email body
    DECLARE emailbody text;
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
            INSERT INTO permissions (group_id, action)
            VALUES (lastid, field);
        END LOOP;
        --------------------------------------------------------------------
        -- Add permissions to super admin user:
        IF NEW.is_super_admin IS TRUE THEN
            FOREACH field IN ARRAY ARRAY['manage_users'] LOOP
                INSERT INTO permissions (group_id, action)
                VALUES (lastid, field);
            END LOOP;
        END IF;
    END IF;
    ---------------------------------------------------------------------
    IF OLD.email <> NEW.email IS TRUE
        -- or may be it's insert mode:
        OR OLD.email IS NULL THEN
        -- log the event:
        logbody = 'email for user changed to ' || NEW.email;
        INSERT INTO logs (scope, level, body, user_id)
        VALUES ('db', 'debug', logbody, NEW.id);
        -- an Email will queued (and must be send by app) to validate action:
        RAISE NOTICE 'Email address Confirmation required for %.', NEW.email;
        emailbody = 'Welcome dear ' || NEW.firstname || ',\nWe need you to confirm your email.\nClick the link to confirm:\n';
        --SELECT nextval('users_id_seq') INTO l_userid;
        INSERT INTO emails (scope, priority, target, message, subject, action, action_link, TEMPLATE, user_id)
        VALUES ('confirm', 'high', NEW.email, emailbody, 'Email Confirmation', 'Confirm', '/api/v1/authentication/confirm/passwdchange/' || NEW.email_confirmation_token, 'email_confirmation.eex', NEW.id)
    RETURNING
        id INTO lastid;
        -- Notify email send
        PERFORM
            pg_notify('email', lastid::text);
    END IF;
    ---------------------------------------------------------------------
    IF NEW.cellphone IS NOT NULL
        -- check if it's changing
        AND OLD.cellphone <> NEW.cellphone IS NOT FALSE THEN
        -- log the event:
        logbody = 'cellphone for ' || NEW.email || ' updated to ' || NEW.cellphone;
        INSERT INTO logs (scope, level, body, user_id)
        VALUES ('db', 'debug', logbody, NEW.id)
    RETURNING
        id INTO lastid;
        -- an SMS will queued (and must be send by app) to validate action:
        INSERT INTO sms (target, message, user_id)
        VALUES (NEW.cellphone, 'Activation code: ' || NEW.cellphone_activation_code::TEXT, NEW.id)
    RETURNING
        id INTO lastid;
        PERFORM
            pg_notify('sms', lastid::text);
    END IF;
    ---------------------------------------------------------------------
    IF OLD.cellphone_activated IS FALSE AND NEW.cellphone_activated IS TRUE THEN
        INSERT INTO sms (target, message, user_id)
        VALUES (NEW.cellphone, 'Your cellphone has been activated.\nThank you.', NEW.id)
    RETURNING
        id INTO lastid;
        PERFORM
            pg_notify('sms', lastid::text);
    END IF;
    ---------------------------------------------------------------------
    IF NEW.passwd IS NOT NULL AND OLD.passwd <> NEW.passwd IS NOT FALSE THEN
        -- log the event:
        logbody = 'password for ' || NEW.email || ' changed';
        INSERT INTO logs (scope, level, body, user_id)
        VALUES ('db', 'debug', logbody, NEW.id);
        -- for debug process for now
        RAISE NOTICE 'password for "%" changed.  Confirmation required.', NEW.email;
        -- an Email will queued (and must be send by app) to validate action:
        -- message must be updated later. TODO
        emailbody = 'Dear ' || NEW.firstname || ',\nWe need you to confirm password update action.\nClick the link to confirm:\n';
        INSERT INTO emails (scope, priority, target, message, subject, action, action_link, TEMPLATE, user_id)
        VALUES ('confirm', 'high', NEW.email, emailbody, 'Password Change Confirmation', 'Confirm', '/api/v1/authentication/confirm/passwdchange/' || NEW.passwd_change_confirmation_token, 'password_change_confirmation.eex', NEW.id)
    RETURNING
        id INTO lastid;
        -- Notify email send, this should be handled by a listener on app side.
        PERFORM
            pg_notify('email', lastid::text);
    END IF;
    ---------------------------------------------------------------------
    RETURN NEW;
    -- *****************************************************************
END;
$$
LANGUAGE 'plpgsql';
