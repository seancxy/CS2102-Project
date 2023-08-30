/* ----- HELPER FUNCTIONS ----- */

/* ----- HELPER FUNCTION #1     ----- */
CREATE OR REPLACE FUNCTION successful_projects(given_date DATE) 
RETURNS TABLE(
    id INT, c_email TEXT, c_ptype TEXT, c_date DATE, pname TEXT, deadline DATE, goal NUMERIC, amount NUMERIC
) AS $$ 
BEGIN 
    RETURN QUERY
    SELECT
        p.id, p.email, p.ptype, p.created, p.name, p.deadline, p.goal, SUM(b.amount) AS amount
    FROM Projects p
    INNER JOIN Backs b 
    ON p.id = b.id
    WHERE p.goal <= (SELECT SUM(b1.amount) 
                    FROM Backs b1 
                    WHERE p.id = b1.id)
                    AND (p.deadline < given_date)
    GROUP BY p.id;
END;
$$ LANGUAGE plpgsql;

/* ----- HELPER FUNCTION #2     ----- */
CREATE OR REPLACE FUNCTION verified_users(given_date DATE) 
RETURNS SETOF Users AS $$ 
BEGIN 
    RETURN QUERY
    SELECT * FROM Users u
    WHERE EXISTS (SELECT email
                  FROM Verifies v
                  WHERE u.email = v.email
                  AND given_date >= verified
                );
END;
$$ LANGUAGE plpgsql;

/* ----- HELPER FUNCTION #3     ----- */
CREATE OR REPLACE FUNCTION num_days_to_reach_funding(pid INT) 
RETURNS INT AS $$ 
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

/* ------------------------ */

/* ----- TRIGGERS     ----- */

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

/* ----- TRIGGER QN #2     ----- */
CREATE OR REPLACE FUNCTION back_amount_check() 
RETURNS TRIGGER AS $$ 
DECLARE 
    min NUMERIC;
BEGIN
    SELECT min_amt INTO min
    FROM Rewards r
    WHERE r.id = NEW.id
    AND r.name = NEW.name;
    IF (NEW.amount >= min) THEN 
        RETURN NEW;
    ELSE 
        RAISE EXCEPTION 'Pledge amount must be greater than minimum of reward tier';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER create_back_amount 
BEFORE INSERT
    ON Backs 
FOR EACH ROW 
    EXECUTE FUNCTION back_amount_check();

/* ----- TRIGGER QN #3     ----- */
CREATE OR REPLACE FUNCTION check_project_reward() 
RETURNS TRIGGER AS $$ 
DECLARE 
    num_reward INT;
BEGIN
    SELECT COUNT(r.name) INTO num_reward
    FROM Rewards r
    WHERE r.id = NEW.id;
    IF num_reward > 0 THEN
        RETURN NEW;
    ELSE 
        RAISE EXCEPTION 'No reward levels for project';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER check_project_has_reward_level
AFTER INSERT
    ON Projects 
DEFERRABLE INITIALLY DEFERRED 
FOR EACH ROW 
    EXECUTE FUNCTION check_project_reward();

/* ----- TRIGGER QN #4     ----- */
CREATE OR REPLACE FUNCTION refund_request_approval_check() 
RETURNS TRIGGER AS $$ 
DECLARE 
    deadline DATE;
    request DATE;
BEGIN
    SELECT p.deadline INTO deadline
    FROM Projects p
    WHERE p.id = NEW.pid;
    SELECT b.request INTO request
    FROM Backs b
    WHERE b.id = NEW.pid
    AND b.email = NEW.email;

    IF request IS NULL THEN -- refunds not requested can neither be approved nor rejected
        RAISE EXCEPTION 'cannot approve or reject refund that is not requested';
        RETURN NULL;
    ELSIF (request - deadline <= 90) OR (NEW.accepted IS FALSE) THEN -- request date is within 90 days of deadline OR NEW.accepted is FALSE
        RETURN NEW;
    ELSE 
        RAISE EXCEPTION 'request date is 90 days after deadline, employee can only reject request';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER create_refund_approval 
BEFORE INSERT 
    ON Refunds 
FOR EACH ROW 
    EXECUTE FUNCTION refund_request_approval_check();

/* ----- TRIGGER QN #5     ----- */
CREATE OR REPLACE FUNCTION back_date_check() 
RETURNS TRIGGER AS $$ 
DECLARE 
    date_created DATE;
    deadline_date DATE;
BEGIN
    SELECT created, deadline INTO date_created, deadline_date
    FROM Projects p
    WHERE NEW.id = p.id;
    IF (NEW.backing >= date_created AND NEW.backing <= deadline_date) THEN 
        RETURN NEW;
    ELSE 
		RAISE EXCEPTION 'cannot back before project creation or after project deadline';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER create_back 
BEFORE INSERT
    ON Backs 
FOR EACH ROW 
    EXECUTE FUNCTION back_date_check();

/* ----- TRIGGER QN #6  ----- */
CREATE OR REPLACE FUNCTION check_request_on_successful_projects() 
RETURNS TRIGGER AS $$ 
BEGIN 
    IF EXISTS (SELECT 1  -- check that the requested refund project is successful
               FROM successful_projects(NEW.request) as sp
               WHERE sp.id = OLD.id) THEN 
        RETURN NEW;
    ELSE 
        RAISE EXCEPTION 'no refund on unsuccessful project';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_request_refund_on_successful_projects 
BEFORE UPDATE
    ON Backs 
FOR EACH ROW
    WHEN (OLD.request IS NULL AND NEW.request IS NOT NULL) -- Assume the only change is to set the Backs.backing from NULL to non-NULL values
    EXECUTE FUNCTION check_request_on_successful_projects();

/* ------------------------ */



/* ----- PROECEDURES  ----- */
/* Procedure #1 */
CREATE OR REPLACE PROCEDURE add_user(email TEXT, name TEXT, cc1 TEXT, cc2 TEXT, street TEXT, 
                                     num TEXT, zip TEXT, country TEXT, kind TEXT) 
AS $$ -- add declaration here
BEGIN -- your code here
    INSERT INTO Users VALUES
    (email, name, cc1, cc2);
    CASE kind
        WHEN 'BACKER' THEN
            INSERT INTO Backers VALUES
            (email, street, num, zip, country);
        WHEN 'CREATOR' THEN
            INSERT INTO Creators VALUES
            (email, country);
        WHEN 'BOTH' THEN
            INSERT INTO  Creators VALUES
            (email, country);
        INSERT INTO Backers VALUES
            (email, street, num, zip, country);
        ELSE 
            RAISE EXCEPTION 'Nonexistent kind --> %', kind;
    END CASE;
END;
$$ LANGUAGE plpgsql;

/* Procedure #2 */
CREATE OR REPLACE PROCEDURE add_project(id INT, email TEXT, ptype TEXT, created DATE, 
                                        name TEXT, deadline DATE, goal NUMERIC,
                                        names TEXT [], amounts NUMERIC []) 
AS $$ -- add declaration here
DECLARE 
    idx INT;
    len INT;
BEGIN -- your code here
    INSERT INTO projects VALUES 
    (id, email, ptype, created, name, deadline, goal);
    len := LEAST(array_length(names, 1), array_length(amounts, 1));
    idx := 1;
    LOOP EXIT
    WHEN idx > len;
    INSERT INTO Rewards VALUES
    (names [idx], id, amounts [idx]);
    idx := idx + 1;
END LOOP;
END;
$$ LANGUAGE plpgsql;

/* Procedure #3 */
CREATE OR REPLACE PROCEDURE auto_reject(eid INT, today DATE) 
AS $$ -- add declaration here
DECLARE curs CURSOR FOR (SELECT * FROM Backs b 
                        WHERE b.request IS NOT NULL 
                        AND (b.request - (SELECT deadline FROM Projects WHERE id = b.id)) > 90);
r RECORD;
BEGIN -- your code here
    OPEN curs;
    LOOP 
        FETCH curs into r;
        EXIT WHEN NOT FOUND;
        INSERT INTO Refunds VALUES
        (r.email, r.id, eid, today, FALSE);
    END LOOP;
    CLOSE curs;
END;

$$ LANGUAGE plpgsql;

/* ------------------------ */
/* ----- FUNCTIONS    ----- */
/* Function #1  */
CREATE OR REPLACE FUNCTION find_superbackers(today DATE
) RETURNS TABLE(email TEXT, name TEXT) AS $$
-- add declaration here
BEGIN
	RETURN QUERY
	SELECT q.email, q.name
    FROM 
        (
            (SELECT u.email, u.name
             FROM (SELECT * FROM verified_users(today)) u, 
                  (SELECT * FROM successful_projects(today)) p,
                  Backs b   
             WHERE u.email = b.email
             AND b.id = p.id
             AND today - p.deadline <= 30
             GROUP BY u.email, u.name
             HAVING COUNT(p.id) >= 5
             AND COUNT(DISTINCT(p.c_ptype)) >= 3
            )
	    UNION
    		(SELECT u.email, u.name
    		 FROM (SELECT * FROM verified_users(today)) u, 
			      (SELECT * FROM successful_projects(today)) p,
                  Backs b
             WHERE u.email = b.email
             AND b.id = p.id
             AND today - p.deadline <= 30
             AND NOT EXISTS (SELECT 1 FROM Backs b1 
						     WHERE b1.email = b.email
                        	 AND b1.request IS NOT NULL
                        	 AND today - b1.request <= 30)
			GROUP BY u.email, u.name
            HAVING SUM(b.amount) >= 1500
            )
	    ) q
    ORDER BY email ASC, name ASC; 
END;
$$ LANGUAGE plpgsql;


/* Function #2  */
CREATE OR REPLACE FUNCTION find_top_success(
  n INT, today DATE, ptype TEXT
) RETURNS TABLE(id INT, name TEXT, email TEXT,
                amount NUMERIC) AS $$
  SELECT p.id, p.pname, p.c_email, p.amount
  FROM (SELECT * FROM successful_projects(today)) p
  WHERE p.c_ptype = ptype
  ORDER BY (p.amount/p.goal) DESC, p.deadline DESC, p.id ASC
  LIMIT n;
$$ LANGUAGE sql;


/* Function #3  */
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