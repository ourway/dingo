CREATE OR REPLACE FUNCTION user_before_delete_funcs() RETURNS TRIGGER AS $$

      BEGIN
		-- *****************************************************************

--		DELETE FROM groups
--			WHERE role = ('user_' || NEW.id || '_group');





    RETURN NEW;
	-- *****************************************************************
    END;
    $$ LANGUAGE 'plpgsql';

