    INSERT INTO users (email, passwd, firstname, lastname, gender, username)
        VALUES('rodmena@me.com', 'Cc_1000mehrfar', 'farsheed', 'ashouri', 'male', 'rodmena');

    UPDATE users set passwd_change_confirmed = TRUE WHERE email='rodmena@me.com';
