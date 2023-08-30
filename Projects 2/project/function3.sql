/*markdown
# Function 3
### Helper function num_days_to_reach_funding(pid) 
Finds the number of days required to reach the funding goal of the project
- Sorts the Backs instances for the specific Project sorted by date in from the oldest to the latest instance
- Iterates through these Backs instances using a cursor, while updating the cumulated funding in the sum variable
- At the first instance where the cumulated sum of funds meets or exceeds the funding goal, we return the number of days between the date of the specific backing instance, and the date of project creation
- Returns null if the funding goal has not been reached. This occurs where no backers have backed the project, or where there are backers, but the total funding amount has not reached the project goal.
### Function find_top_popular(n, today, ptype)
Finds the Project instances of the given ptype, where the project deadline is before today. For each project instance, 
- Calculates the corresponding number of days required to reach the funding goal using the num_days_to_reach_funding() function
- Orders the results by the popularity metric
- Returns the top n rows
- If the project has yet to meet its goal, the number of days calculated is set to null, and null values are considered larger than valid numeric values
*/

CREATE OR REPLACE FUNCTION num_days_to_reach_funding(pid INT) RETURNS INT AS $$ 
DECLARE 
    curs CURSOR FOR (SELECT sp.id, sp.goal, sp.created, b.amount, b.backing
                     FROM Projects sp
                     JOIN Backs b 
                     ON sp.id = b.id
                     WHERE sp.id = pid
                     ORDER BY b.backing ASC
                    );
    sum NUMERIC;
    r RECORD;
BEGIN 
    sum := 0;
    OPEN curs;
    LOOP 
        FETCH curs INTO r;
        EXIT WHEN NOT FOUND;
        sum := sum + r.amount;
        IF sum >= r.goal THEN 
            CLOSE curs;
            RETURN r.backing - r.created;
        END IF;
    END LOOP;
    CLOSE curs;
    RETURN NULL;
END;
 $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION find_top_popular(n INT, today DATE, ptype TEXT) 
RETURNS TABLE(id INT, name TEXT, email TEXT, days INT) AS $$ 
DECLARE 
    tempType TEXT := ptype;
BEGIN
    RETURN QUERY 
    SELECT p.id, p.name, p.email, num_days_to_reach_funding(p.id) AS days
    FROM Projects p
    WHERE p.ptype = tempType
    AND p.created < today
    ORDER BY days ASC, id ASC
    LIMIT n;
END;
$$ LANGUAGE plpgsql;

/*markdown
# Function 3 Testing
### Testing for order
- Include projects that require 0 days to hit the target
- Include projects where the first backing > creation date, and the first backing hits the limit
- Include projects that require several instances of backing to reach the limit
    - Projects that hit the limit on the latest backing
    - Projects that hit the limit on a non-latest backing
- Include projects that are not backed at all (we expect days = null, and for that project to be ordered last)
- Include projects that are backed, but have not reached the goal
### Testing for ptype and date
- Include projects of a different ptype
- Include projects of the same ptype, created after today
- Test different n values
*/

/* Initialise Creator */
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM Creators WHERE email='pureCreator@gmail.com') THEN
        CALL add_user('pureCreator@gmail.com', 'Pure Creator', 'Amex', 'Visa', 'Ang mo kio ave 3', '123', '92122', 'Singapore', 'CREATOR');
        CALL add_user('backer1@gmail.com', 'Backer 1', 'Amex', 'Visa', 'Ang mo kio ave 3', '123', '92122', 'Singapore', 'BACKER');
        CALL add_user('backer2@gmail.com', 'Backer 2', 'Amex', 'Visa', 'Ang mo kio ave 3', '123', '92122', 'Singapore', 'BACKER');
        CALL add_user('backer3@gmail.com', 'Backer 3', 'Amex', 'Visa', 'Ang mo kio ave 3', '123', '92122', 'Singapore', 'BACKER');
        CALL add_user('backer4@gmail.com', 'Backer 4', 'Amex', 'Visa', 'Ang mo kio ave 3', '123', '92122', 'Singapore', 'BACKER');
    END IF;
END $$;
SELECT * FROM Creators;
SELECT * FROM Backers;
/* Initialise Employee */
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM Employees WHERE id=1) THEN
        INSERT INTO Employees VALUES (1, 'Maximus', 10000);
    END IF;
END $$;
SELECT * FROM Employees;
/* Initialise Project Type */
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM ProjectTypes WHERE name='default ptype') THEN
        INSERT INTO ProjectTypes VALUES ('default ptype', 1);
        INSERT INTO ProjectTypes VALUES ('second ptype', 1);
        INSERT INTO ProjectTypes VALUES ('third ptype', 1);
    END IF;
END $$;
SELECT * FROM ProjectTypes;
/* Create Projects */
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM Projects WHERE id=1) THEN
        CALL add_project(1, 'pureCreator@gmail.com', 'default ptype', DATE(CURRENT_DATE) - 100, '0 Day Project', DATE(CURRENT_DATE - 1), 100, Array['Third', 'Second', 'First'], Array[10, 20, 30]);
        CALL add_project(2, 'pureCreator@gmail.com', 'default ptype', DATE(CURRENT_DATE) - 100, 'One Shot Project', DATE(CURRENT_DATE - 2), 100, Array['Third', 'Second', 'First'], Array[10, 20, 30]);
        CALL add_project(3, 'pureCreator@gmail.com', 'default ptype', DATE(CURRENT_DATE) - 100, 'Latest Multi Backed Project', DATE(CURRENT_DATE - 3), 100, Array['Third', 'Second', 'First'], Array[10, 20, 30]);
        CALL add_project(4, 'pureCreator@gmail.com', 'default ptype', DATE(CURRENT_DATE) - 100, 'Earlier Multi Backed Project', DATE(CURRENT_DATE - 4), 100, Array['Third', 'Second', 'First'], Array[10, 20, 30]);
        CALL add_project(5, 'pureCreator@gmail.com', 'default ptype', DATE(CURRENT_DATE) - 100, 'Unbacked Project', DATE(CURRENT_DATE - 5), 100, Array['Third', 'Second', 'First'], Array[10, 20, 30]);
        CALL add_project(6, 'pureCreator@gmail.com', 'default ptype', DATE(CURRENT_DATE) - 100, 'Premature Project', DATE(CURRENT_DATE - 6), 100, Array['Third', 'Second', 'First'], Array[10, 20, 30]);
        -- For ptype testing
        CALL add_project(7, 'pureCreator@gmail.com', 'second ptype', DATE(CURRENT_DATE) - 100, 'Type 2 Project 1', DATE(CURRENT_DATE - 1), 100, Array['Third', 'Second', 'First'], Array[10, 20, 30]);
        CALL add_project(8, 'pureCreator@gmail.com', 'second ptype', DATE(CURRENT_DATE) - 100, 'Type 2 Project 1', DATE(CURRENT_DATE - 2), 100, Array['Third', 'Second', 'First'], Array[10, 20, 30]);
        CALL add_project(9, 'pureCreator@gmail.com', 'third ptype', DATE(CURRENT_DATE) - 100, 'Type 3 Project 1', DATE(CURRENT_DATE - 3), 100, Array['Third', 'Second', 'First'], Array[10, 20, 30]); 
    END IF;
END $$;
SELECT * FROM Projects;

/* Create Backs */
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM Backs WHERE email='backer1@gmail.com') THEN
        -- 0 days to hit target
        INSERT INTO Backs VALUES ('backer1@gmail.com', 'Third', 1, DATE(CURRENT_DATE) - 100, NULL, 100);
        -- 1 backing and 1 day to hit target
        INSERT INTO Backs VALUES ('backer1@gmail.com', 'First', 2, DATE(CURRENT_DATE) - 99, NULL, 300);
        -- 4 backings and 4 days to hit target
        INSERT INTO Backs VALUES ('backer1@gmail.com', 'First', 3, DATE(CURRENT_DATE) - 99, NULL, 30);
        INSERT INTO Backs VALUES ('backer2@gmail.com', 'Second', 3, DATE(CURRENT_DATE) - 98, NULL, 20);
        INSERT INTO Backs VALUES ('backer3@gmail.com', 'Third', 3, DATE(CURRENT_DATE) - 97, NULL, 10);
        INSERT INTO Backs VALUES ('backer4@gmail.com', 'First', 3, DATE(CURRENT_DATE) - 96, NULL, 50);
        -- 4 backings and 2 days to hit target
        INSERT INTO Backs VALUES ('backer1@gmail.com', 'First', 4, DATE(CURRENT_DATE) - 99, NULL, 60);
        INSERT INTO Backs VALUES ('backer2@gmail.com', 'First', 4, DATE(CURRENT_DATE) - 98, NULL, 60);
        INSERT INTO Backs VALUES ('backer3@gmail.com', 'Third', 4, DATE(CURRENT_DATE) - 97, NULL, 10);
        INSERT INTO Backs VALUES ('backer4@gmail.com', 'Third', 4, DATE(CURRENT_DATE) - 96, NULL, 10);
        -- Unbacked project has no backing
        -- Premature project with 3 backings, have not reached target
        INSERT INTO Backs VALUES ('backer1@gmail.com', 'First', 6, DATE(CURRENT_DATE) - 99, NULL, 40);
        INSERT INTO Backs VALUES ('backer2@gmail.com', 'Second', 6, DATE(CURRENT_DATE) - 98, NULL, 30);
        INSERT INTO Backs VALUES ('backer3@gmail.com', 'Third', 6, DATE(CURRENT_DATE) - 97, NULL, 20);
        -- For ptype testing
        INSERT INTO Backs VALUES ('backer1@gmail.com', 'First', 7, DATE(CURRENT_DATE) - 90, NULL, 110);
        INSERT INTO Backs VALUES ('backer2@gmail.com', 'Second', 8, DATE(CURRENT_DATE) - 90, NULL, 110);
        INSERT INTO Backs VALUES ('backer3@gmail.com', 'Third', 9, DATE(CURRENT_DATE) - 90, NULL, 110);
    END IF;
END $$;
SELECT * FROM Projects;
        

-- Vary n
SELECT * FROM find_top_popular(10, CURRENT_DATE, 'default ptype');
SELECT * FROM find_top_popular(2, CURRENT_DATE, 'default ptype');
SELECT * FROM find_top_popular(0, CURRENT_DATE, 'default ptype')

-- Vary date
SELECT * FROM find_top_popular(10, CURRENT_DATE, 'default ptype');
SELECT * FROM find_top_popular(10, CURRENT_DATE - 2, 'default ptype');
SELECT * FROM find_top_popular(10, CURRENT_DATE - 4, 'default ptype');
SELECT * FROM find_top_popular(10, CURRENT_DATE - 6, 'default ptype');

-- Vary ptype
SELECT * FROM find_top_popular(10, CURRENT_DATE, 'second ptype');
SELECT * FROM find_top_popular(10, CURRENT_DATE, 'third ptype');