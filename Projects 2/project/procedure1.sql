/*markdown
# Procedure 1
### add_user Procedure
With the given user information, this procedure creates a User entity with the provided email, name, and credit card details. Then, it checks whether the User is a Backer, a Creator, or both. 
- If it is a Backer, a new Backer entity is created with the provided details and associated with the parent User entity
- If it is a Creator, a new Creator entity is created with the provided details and associated with the parent User entity
- If it is both, a Backer and a Creator entity is created with the provided details and associated with the parent User entity
- If it is none of the above, or if any exceptions occur while creating the relevant Creator or Backer entities, an exception is raised and the transaction is rolled back such that no entities are created as a result of this procedure.

*/

CREATE OR REPLACE PROCEDURE add_user(
 email TEXT, name    TEXT, cc1  TEXT,
 cc2   TEXT, street  TEXT, num  TEXT,
 zip   TEXT, country TEXT, kind TEXT
) AS $$
-- add declaration here
BEGIN
 -- your code here
 INSERT INTO Users VALUES (email, name, cc1, cc2);
	CASE kind
 	WHEN 'BACKER' THEN
		INSERT INTO Backers VALUES (email, street, num, zip, country);
 	WHEN 'CREATOR' THEN
 		INSERT INTO Creators VALUES (email, country);
 	WHEN 'BOTH' THEN
 	  		INSERT INTO Creators VALUES (email, country);
 	  		INSERT INTO Backers VALUES (email, street, num, zip, country);
 	ELSE
 		RAISE EXCEPTION 'Nonexistent kind --> %', kind; 		
	END CASE;
END;
$$ LANGUAGE plpgsql;

/*markdown
# Procedure 1 Testing
### Create Backer
- Create a valid Backer
- Try to create a Backer with an invalid email
- Try to create a Backer with NULL values
### Create Creator
- Create a valid Creator
- Try to create a Creator with an invalid email
- Try to create a Creator with NULL values
### Create Both
- Create a valid User who is both a Backer and a Creator
- Try to do so with invalid values

### Create Neither
- Run add_user with an invalid 'kind' parameter
*/

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM Users WHERE email='pureBacker@gmail.com') THEN
        /* Create Valid Backers */
        CALL add_user('pureBacker@gmail.com', 'Pure Backer', 'Amex', 'Visa', 'Ang mo kio ave 3', '123', '92122', 'Singapore', 'BACKER');
        CALL add_user('pureBacker2@gmail.com', 'Pure Backer', 'Amex', NULL, 'Bishan', '123', '92122', 'Singapore', 'BACKER');
        /* Create Valid Creators */
        CALL add_user('pureCreator@gmail.com', 'Pure Creator', 'Mastercard', 'Visa', NULL, NULL, NULL, 'Singapore', 'CREATOR');
        CALL add_user('pureCreator2@gmail.com', 'Pure Creator', 'Amex', NULL, 'Ang mo kio ave 3', '123', '92122', 'Singapore', 'CREATOR');
        /* Create Valid Both */
        CALL add_user('both1@gmail.com', 'Both 1', 'Chase', 'Mastercard', 'Mountmatten', '123', '92122', 'Singapore', 'BOTH');
        CALL add_user('both2@gmail.com', 'Both 2', 'Amex', NULL, 'Expo', '123', '92122', 'Singapore', 'BOTH');
    END IF;
END $$;
SELECT * FROM Users;
SELECT * FROM Backers;
SELECT * FROM Creators;

/* Create Invalid Backers */
CALL add_user('invalidBacker@gmail.com', 'Pure Backer', 'Amex', 'Visa', NULL, '123', '92122', 'Singapore', 'BACKER');


CALL add_user('invalidBacker@gmail.com', 'Pure Backer', 'Mastercard', 'Amex', 'Ang mo kio ave 3', NULL, '92122', 'Singapore', 'BACKER');

/* Create Invalid Creators */
CALL add_user('invalidCreator@gmail.com', 'Pure Creator', 'Amex', 'Amex', 'Ang mo kio ave 3', '123', '92122', NULL, 'CREATOR');

CALL add_user('invalidCreator@gmail.com', NULL, 'Amex', 'Visa', 'Ang mo kio ave 3', '123', '92122', 'Singapore', 'CREATOR');

/* Create Invalid Both */
CALL add_user('invalid@gmail.com', 'Both 1', 'Chase', 'Mastercard', 'Mountmatten', '123', NULL, 'Singapore', 'BOTH');


CALL add_user('invalid@gmail.com', NULL, 'Amex', NULL, 'Expo', '123', '92122', 'Singapore', 'BOTH');

/* Create Neither */
CALL add_user('invalid@gmail.com', 'Both 1', 'Chase', 'Mastercard', 'Mountmatten', '123', NULL, 'Singapore', 'NEITHER');


CALL add_user('invalid@gmail.com', 'Both 1', 'Chase', 'Mastercard', 'Mountmatten', '123', NULL, 'Singapore', 'CREATOR BACKER');

SELECT * FROM Users;
SELECT * FROM Backers;
SELECT * FROM Creators;