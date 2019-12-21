CREATE OR REPLACE FUNCTION user_on_update_funcs ()
    RETURNS TRIGGER
    AS $$
    -- store newhash
DECLARE
    newhash text;
    -- for logbody
    DECLARE logbody text;
    -- for email body
    DECLARE emailbody text;
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
    ---------------------------------------------------------------------
    RETURN NEW;
    --****************************************************************--
END;
$$
LANGUAGE 'plpgsql';
