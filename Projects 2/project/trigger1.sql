/*markdown
# Trigger 1 Submission
### Trigger Function check_user()
For the new user to be inserted, check_user() checks whether there exists an instance of a Backer or a Creator (or both) with the corresponding unique email address. If neither exists, an exception is raised; Otherwise, the proposed new User is inserted into the database.
### Trigger create_user_check
Runs the check_user() function after a new User row is inserted into the database. If the insert statement on Users is called within a transaction, this check is deferred to after the relevant transaction is completed.
### How will the trigger affect the add_user procedure?
The add_user procedure inserts a new User into the database, before inserting the corresponding Backer or Creator entities. Since our trigger constraint is set to initially deferred, the trigger will only run the check_user() function after the entire add_user procedure is complete. At which point, for the inserted User, at least one corresponding Backer or Creator entity should exist in the database, and the transaction will be successful. No exception will be raised. 
###
Without the deferral, the add_user procedure would always be rolled back. The trigger will run the check_user() immediately after the User insertion, at which point there will be no instances of a Backer or Creator with the same email. Hence, an exception will be raised and the transaction will be rolled back. 
###
Another implementation of deferral will be to set DEFERRABLE to INITIALLY IMMEDIATE such that the trigger runs immediately by default. With this setting, the add_user procedure will behave the same way as without the deferral. To ensure the deferral is enacted in add_user, we have to add the line "SET CONSTRAINT DEFERRED" in add_user. This achieves the same behavior as our existing initially deferred implementation.
*/

DROP TRIGGER IF EXISTS create_user_check ON Users;
DROP FUNCTION IF EXISTS check_user;

/* ----- TRIGGER QN #1     ----- */
CREATE OR REPLACE FUNCTION check_user() 
RETURNS TRIGGER AS $$ 
BEGIN 
    IF (NOT EXISTS (SELECT 1 
                    FROM Backers b 
                    WHERE b.email = NEW.email) 
                    AND 
                    NOT EXISTS (SELECT 1 
                                FROM Creators c
                                WHERE c.email = NEW.email)) THEN 
            RAISE EXCEPTION 'User must be a Creator or a Buyer, or both!';
            RETURN NULL;
    ELSE 
        RETURN NEW;
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER create_user_check
AFTER INSERT
    ON Users 
DEFERRABLE INITIALLY DEFERRED 
FOR EACH ROW 
    EXECUTE FUNCTION check_user();

/*markdown
# Trigger 1 Testing
- Check direct insertion on Users
- Check insertion on Users via add_user
- Check another random procedure that involves creating a User without a corresponding Backer or Creator
*/

/*
HELPER FUNCTION
Deletes a User from DB
*/
CREATE OR REPLACE PROCEDURE delete_user(input_email TEXT) 
AS $$ -- add declaration here
BEGIN -- your code here
    DELETE FROM Backers b WHERE b.email = input_email;
    DELETE FROM Creators c WHERE c.email = input_email;
    DELETE FROM Users u WHERE u.email = input_email;
END;
$$ LANGUAGE plpgsql;

/*
Direct insertion on User
- Expects an exception to be raised, nothing should be created
*/
INSERT INTO Users VALUES ('invalidPerson@u.nus.edu', 'Invalid Person', 'Amex', 'Visa');

/*
Insertion on User via add_user
- Expects the corresponding User and its child entities to be created
*/
CALL add_user('bothPerson@u.nus.edu', 'Both Person', 'Amex', 'Visa', 'Ang mo kio ave 3', '123', '92122', 'Singapore', 'BOTH');
SELECT * FROM Users;
SELECT * FROM Backers;
SELECT * FROM Creators;


CALL delete_user('bothPerson@u.nus.edu');


CALL add_user('pureBacker@u.nus.edu', 'Pure Backer', 'Amex', 'Visa', 'Ang mo kio ave 3', '123', '92122', 'Singapore', 'BACKER');
SELECT * FROM Users;
SELECT * FROM Backers;
SELECT * FROM Creators;

CALL delete_user('pureBacker@u.nus.edu');


CALL add_user('pureCreator@u.nus.edu', 'Pure Creator', 'Amex', 'Visa', 'Ang mo kio ave 3', '123', '92122', 'Singapore', 'CREATOR');
SELECT * FROM Users;
SELECT * FROM Backers;
SELECT * FROM Creators;


CALL delete_user('pureCreator@u.nus.edu');


CALL add_user('pureBacker@u.nus.edu', 'Pure Backer', 'Amex', 'Visa', 'Ang mo kio ave 3', '123', '92122', 'Singapore', 'BACKER');
SELECT * FROM Users;
SELECT * FROM Backers;
SELECT * FROM Creators;


CALL delete_user('pureBacker@u.nus.edu');


/*
Insertion on User via another procedure that does not create a corresponding Backer or Creator
- Exception should be raised, nothing should be created
*/
CREATE OR REPLACE PROCEDURE temp_add_user_procedure(email TEXT, name TEXT, cc1 TEXT, cc2 TEXT, street TEXT, 
                                     num TEXT, zip TEXT, country TEXT, kind TEXT) 
AS $$ -- add declaration here
BEGIN -- your code here
    INSERT INTO Users VALUES
    (email, name, cc1, cc2);
END;
$$ LANGUAGE plpgsql;

CALL temp_add_user_procedure('invalidPerson@u.nus.edu', 'Invalid Person', 'Amex', 'Visa', 'Ang mo kio ave 3', '123', '92122', 'Singapore', 'BOTH');
DROP PROCEDURE IF EXISTS temp_add_user_procedure

DROP PROCEDURE IF EXISTS delete_user