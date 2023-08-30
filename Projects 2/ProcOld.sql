DROP TABLE IF EXISTS Employees, Users, Verifies, Backers, Creators, ProjectTypes, Projects, Updates, Rewards, Backs, Refunds CASCADE;

CREATE TABLE Employees (
  id     INT PRIMARY KEY,
  name   TEXT NOT NULL,
  salary NUMERIC NOT NULL CHECK (salary > 0)
);

CREATE TABLE Users (
  email  TEXT PRIMARY KEY,
  name   TEXT NOT NULL,
  cc1    TEXT NOT NULL,
  cc2    TEXT CHECK (cc1 <> cc2)
);

CREATE TABLE Verifies (
  email    TEXT PRIMARY KEY
    REFERENCES Users(email),
  id       INT NOT NULL REFERENCES Employees(id),
  verified DATE NOT NULL
);

CREATE TABLE Backers (
  email   TEXT PRIMARY KEY
    REFERENCES Users(email) ON UPDATE CASCADE,
  street  TEXT NOT NULL,
  num     TEXT NOT NULL,
  zip     TEXT NOT NULL,
  country TEXT NOT NULL
);

CREATE TABLE Creators (
  email   TEXT PRIMARY KEY
    REFERENCES Users(email) ON UPDATE CASCADE,
  country TEXT NOT NULL
);

CREATE TABLE ProjectTypes (
  name  TEXT PRIMARY KEY,
  id    INT NOT NULL REFERENCES Employees(id)
);

CREATE TABLE Projects (
  id       INT PRIMARY KEY,
  email    TEXT NOT NULL
    REFERENCES Creators(email) ON UPDATE CASCADE,
  ptype    TEXT NOT NULL
    REFERENCES ProjectTypes(name) ON UPDATE CASCADE,
  created  DATE NOT NULL, -- alt: TIMESTAMP
  name     TEXT NOT NULL,
  deadline DATE NOT NULL CHECK (deadline >= created),
  goal     NUMERIC NOT NULL CHECK (goal > 0)
);

CREATE TABLE Updates (
  time    TIMESTAMP,
  id      INT REFERENCES Projects(id)
    ON UPDATE CASCADE, -- ON DELETE CASCADE (optional)
  message TEXT NOT NULL,
  PRIMARY KEY (time, id)
);

CREATE TABLE Rewards (
  name    TEXT,
  id      INT REFERENCES Projects(id)
    ON UPDATE CASCADE, -- ON DELETE CASCADE (optional)
  min_amt NUMERIC NOT NULL CHECK (min_amt > 0),
  PRIMARY KEY (name, id)
);

CREATE TABLE Backs (
  email    TEXT REFERENCES Backers(email),
  name     TEXT NOT NULL,
  id       INT,
  backing  DATE NOT NULL, -- backing date
  request  DATE, -- refund request
  amount   NUMERIC NOT NULL CHECK (amount > 0),
  -- status will be derived via queries instead
  PRIMARY KEY (email, id),
  FOREIGN KEY (name, id) REFERENCES Rewards(name, id)
);

CREATE TABLE Refunds (
  email    TEXT,
  pid      INT,
  eid      INT NOT NULL REFERENCES Employees(id),
  date     DATE NOT NULL,
  accepted BOOLEAN NOT NULL,
  PRIMARY KEY (email, pid),
  FOREIGN KEY (email, pid) REFERENCES Backs(email, id)
);





/* ----- TRIGGERS     ----- */


SELECT 'Trigger 2' as msg;

/* Trigger 2 */

CREATE OR REPLACE FUNCTION back_amount_check()
RETURNS TRIGGER AS $$
DECLARE 
	min NUMERIC;
BEGIN
	SELECT min_amt 
INTO min 
FROM Rewards r 
WHERE r.id = NEW.id 
AND r.name = NEW.name;

IF (NEW.amount >= min) THEN RETURN NEW;
ELSE 
	RAISE EXCEPTION 'Pledge amount must be greater than minimum of reward tier'; 
RETURN NULL;
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER create_back_amount
BEFORE  
	INSERT
ON Backs
FOR EACH ROW 
	EXECUTE FUNCTION back_amount_check();



SELECT 'Trigger 3' as msg;

/* ----- TRIGGER QN #3     ----- */
CREATE OR REPLACE FUNCTION check_project_reward()
RETURNS TRIGGER
AS $$
DECLARE num_reward INT;
BEGIN
    SELECT COUNT(r.name) INTO num_reward FROM Rewards r WHERE r.id = NEW.id;
    IF num_reward >  0 THEN
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






SELECT 'Trigger 4' as msg;

/* Trigger 4 */
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
    ELSIF (request - deadline) <= 90  OR (NEW.accepted IS FALSE) THEN -- request date is within 90 days of deadline OR NEW.accepted is FALSE
    	RETURN NEW;
    ELSE
    	RAISE EXCEPTION 'request date is 90 days after deadline, employee can only reject request';
            RETURN NULL;
     END IF;

END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER create_refund_approval
BEFORE 
    INSERT ON Refunds
FOR EACH ROW
    EXECUTE FUNCTION refund_request_approval_check();



/* ------------------------ */





/* ----- PROECEDURES  ----- */
/* Procedure #1 */
CREATE OR REPLACE PROCEDURE add_user(
  email TEXT, name    TEXT, cc1  TEXT,
  cc2   TEXT, street  TEXT, num  TEXT,
  zip   TEXT, country TEXT, kind TEXT
) AS $$
-- add declaration here
BEGIN
  -- your code here
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
        INSERT INTO Creators VALUES
          (email, country);
        INSERT INTO Backers VALUES
          (email, street, num, zip, country);
    ELSE
        RAISE EXCEPTION 'Non existent Kind --> %', kind;
    END CASE; 
END;
$$ LANGUAGE plpgsql;

SELECT 'PROCEDURE 1' as msg;

CALL add_user('test@gmail.com', 'test', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'test');
CALL add_user('creator1@gmail.com', 'creator1', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'CREATOR');
CALL add_user('creator2@gmail.com', 'creator2', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'CREATOR');
CALL add_user('creator3@gmail.com', 'creator3', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'CREATOR');
CALL add_user('creator4@gmail.com', 'creator3', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'CREATOR');
CALL add_user('creator5@gmail.com', 'creator3', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'CREATOR');
CALL add_user('backer1@gmail.com', 'backer1', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'BACKER');
CALL add_user('backer2@gmail.com', 'backer2', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'BACKER');
CALL add_user('backer3@gmail.com', 'backer3', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'BACKER');
CALL add_user('backer4@gmail.com', 'backer4', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'BACKER');
CALL add_user('backer5@gmail.com', 'backer5', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'BACKER');
CALL add_user('backer6@gmail.com', 'backer6', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'BACKER');
SELECT * FROM Users;
SELECT * FROM Backers;
SELECT * FROM Creators;

INSERT INTO Employees VALUES
(1,'zhili1',1000),
(2,'zhili2',1000),
(3,'zhili3',1000),
(4,'zhili4',1000),
(5,'zhili5',1000);

INSERT INTO ProjectTypes VALUES
('type1',1),
('type2',2),
('type3',3),
('type4',4),
('type5',5);



/* Procedure #2 */
CREATE OR REPLACE PROCEDURE add_project(
  id      INT,     email TEXT,   ptype    TEXT,
  created DATE,    name  TEXT,   deadline DATE,
  goal    NUMERIC, names TEXT[],
  amounts NUMERIC[]
) AS $$
-- add declaration here
DECLARE 
  idx INT; len INT;
BEGIN
  -- your code here
  INSERT INTO Projects VALUES 
    (id, email, ptype, created, name, deadline, goal);
  
  len := LEAST(array_length(names, 1), array_length(amounts, 1));
  idx := 1;

  LOOP
    EXIT WHEN idx > len;
    INSERT INTO Rewards VALUES
      (names[idx], id, amounts[idx]);
    
    idx := idx + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT 'PROCEDURE 2' as msg;
CALL add_project(1, 'creator1@gmail.com', 'type1', '2021-10-01', 'project1', '2022-01-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600]);
CALL add_project(2, 'creator2@gmail.com', 'type1', '2021-10-01', 'project2', '2022-02-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600,2]);
CALL add_project(3, 'creator3@gmail.com', 'type1', '2021-10-01', 'project3', '2022-01-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600]);
CALL add_project(4, 'creator4@gmail.com', 'type1', '2021-10-01', 'project4', '2022-01-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600]);
CALL add_project(5, 'creator5@gmail.com', 'type1', '2021-10-01', 'project5', '2022-01-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600]);

SELECT * FROM Projects;

/* Procedure #3 */
CREATE OR REPLACE PROCEDURE auto_reject(
  eid INT, today DATE
) AS $$
-- add declaration here
DECLARE
    curs CURSOR FOR (SELECT * FROM Backs b
                    WHERE b.request IS NOT NULL AND 
                    (b.request - (SELECT deadline FROM Projects WHERE id = b.id) > 90 ));
    r RECORD;
BEGIN
  -- your code here
    OPEN curs;
    LOOP
      FETCH curs into r;
      EXIT WHEN NOT FOUND;
      INSERT INTO Refunds VALUES (r.email, r.id, eid, today, FALSE);
    END LOOP;
    CLOSE curs;
END;
$$ LANGUAGE plpgsql;
/* ----------------
-------- */

SELECT 'PROCEDURE 3' as msg;
SELECT * FROM Projects;
SELECT * FROM Rewards;

INSERT INTO Backs VALUES
('backer1@gmail.com', 'gold', 1, '2021-10-07','2022-05-01',600),
('backer2@gmail.com', 'bronze', 1, '2021-10-12','2022-05-01',1000),
('backer2@gmail.com', 'silver', 2, '2021-10-10','2022-05-01',1000),
('backer3@gmail.com', 'bronze', 3, '2021-10-10','2022-04-01',600),
('backer4@gmail.com', 'silver', 4, '2021-10-01','2022-03-01',1000),
('backer5@gmail.com', 'silver', 5, '2021-10-10','2022-10-01',5000),
('backer6@gmail.com', 'gold', 5, '2021-10-10','2022-03-01',5000),
('backer6@gmail.com', 'silver', 1, '2021-11-10',NULL,5000);
SELECT * FROM Backs;
-- CALL auto_reject(1, '2022-10-01');
SELECT * FROM Refunds;




/* test trigger 4 */
SELECT 'Test trigger 4' AS msg;
SELECT * FROM Projects;
SELECT * FROM Backs;
INSERT INTO Refunds VALUES
('backer3@gmail.com', 3, 1, '2022-05-01', TRUE),
('backer5@gmail.com', 5, 1, '2022-05-01', TRUE),
('backer6@gmail.com', 5, 1, '2022-05-01', FALSE),
('backer6@gmail.com', 1, 1, '2022-05-01', FALSE);
SELECT * FROM refunds;


/* ----- FUNCTIONS    ----- */
/* Function #1  */
CREATE OR REPLACE FUNCTION find_superbackers(
  today DATE
) RETURNS TABLE(email TEXT, name TEXT) AS $$
-- add declaration here
BEGIN
  -- your code here
END;
$$ LANGUAGE plpgsql;



/* Function #2  */


CREATE OR REPLACE FUNCTION successful_projects(
	given_date DATE
) RETURNS SETOF Projects AS $$
BEGIN
	RETURN QUERY
	SELECT * FROM Projects p 
	WHERE p.goal <= (SELECT SUM(amount) FROM Backs b 
					 WHERE p.id = b.id)
	AND (p.deadline < given_date)
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION find_top_success(
  n INT, today DATE, ptype TEXT
) RETURNS TABLE(id INT, name TEXT, email TEXT,
                amount NUMERIC) AS $$
  SELECT p.id, p.name, p.email, t.amount
  FROM (SELECT * FROM successful_projects(today) p
        WHERE p.deadline < today 
        AND p.ptype = ptype) AS p
        INNER JOIN 
        (SELECT b.id, SUM(amount) AS amount
        FROM Backs b 
        GROUP BY b.id) AS t
        ON p.id = t.id
  ORDER BY  (t.amount/p.goal) DESC, p.deadline DESC, p.id ASC
  LIMIT n;

$$ LANGUAGE sql;


--SELECT find_top_success(3, to_date('2022-02-01', 'YYYY-MM-DD'), 'type1');
SELECT find_top_success(3, '2022-05-01', 'type1');

SELECT find_top_success(5, '2022-05-01', 'type1');

-- /* Function #3  */
-- CREATE OR REPLACE FUNCTION find_top_popular(
--   n INT, today DATE, ptype TEXT
-- ) RETURNS TABLE(id INT, name TEXT, email TEXT,
--                 days INT) AS $$
-- -- add declaration here
-- DECLARE
--     curs CURSOR FOR (SELECT p.id , p.name , p.email, p.created, t.backing, t.amount, p.goal,
--                       SUM(t.amount) OVER (PARTITION BY p.id ORDER BY t.backing) AS cumulativeTotal 
--                       FROM 
--                       (SELECT * FROM Projects p
--                       WHERE p.created < '2023-01-01'
--                       AND p.ptype = 'type1') AS p
--                       INNER JOIN 
--                       (SELECT b.id, b.backing, SUM(amount) AS amount
--                       FROM Backs b 
--                       GROUP BY b.id, b.backing
--                       ORDER BY b.id, b.backing ASC) AS t
--                       ON p.id = t.id);
-- 	  r RECORD;

-- BEGIN
--   -- your code here
--   id = -1;
--   OPEN curs;
--     LOOP
--       FETCH curs into r;
--         EXIT WHEN NOT FOUND;
--         IF 
        
--     END LOOP;
-- 	CLOSE curs;

--   ORDER BY days DESC, p.id ASC
--   LIMIT n;
-- END;
-- $$ LANGUAGE plpgsql;
-- /* ------------------------ */

/* Function #3  */
CREATE OR REPLACE FUNCTION find_top_popular(
  n INT, today DATE, ptype TEXT
) RETURNS TABLE(id INT, name TEXT, email TEXT,
                days INT) AS $$
-- add declaration here
#variable_conflict use_variable
BEGIN
  -- your code here
  RETURN QUERY
      WITH popular_project AS (
          SELECT p.id , p.name , p.email, p.created, t.backing, t.amount, p.goal,
          SUM(t.amount) OVER (PARTITION BY p.id ORDER BY t.backing) AS cumulativeTotal
          FROM 
            (SELECT * FROM Projects p
            WHERE p.created < today
            AND p.ptype = ptype) AS p
          INNER JOIN 
            (SELECT b.id, b.backing, SUM(amount) AS amount
            FROM Backs b 
            GROUP BY b.id, b.backing
            ORDER BY b.id, b.backing ASC) AS t
            ON p.id = t.id)
      SELECT p.id, p.name, p.email, (p.backing - p.created) AS days 
      FROM popular_project p
      WHERE p.cumulativeTotal >= p.goal
      AND p.backing = (SELECT MIN(p2.backing) 
                    FROM popular_project p2 
                    WHERE p2.id=p.id
                    AND p2.cumulativeTotal >= p2.goal)
      ORDER BY days ASC, p.id ASC
      LIMIT n;
END;
$$ LANGUAGE plpgsql;
/* ------------------------ */





SELECT * FROM Projects
WHERE ptype = 'type1';
SELECT b.id, b.backing, SUM(amount) AS amount
FROM Backs b 
GROUP BY b.id, b.backing
ORDER BY b.id, b.backing ASC;

WITH popular_project AS (
SELECT p.id , p.name , p.email, p.created, t.backing, t.amount, p.goal,
SUM(t.amount) OVER (PARTITION BY p.id ORDER BY t.backing) AS cumulativeTotal
FROM 
  (SELECT * FROM Projects p
  WHERE p.created < '2023-01-01'
  AND p.ptype = 'type1') AS p
INNER JOIN 
  (SELECT b.id, b.backing, SUM(amount) AS amount
  FROM Backs b 
  GROUP BY b.id, b.backing
  ORDER BY b.id, b.backing ASC) AS t
  ON p.id = t.id)
SELECT p.id, p.name, p.email, (p.backing - p.created) AS days  FROM popular_project p
WHERE (cumulativeTotal) >= goal
AND backing = (SELECT MIN(p2.backing) FROM popular_project p2 
              WHERE p2.id=p.id
              AND (cumulativeTotal) >= goal);


SELECT find_top_popular(5, '2023-01-01', 'type1');




SELECT * FROM Projects;
SELECT * FROM Rewards;
SELECT * FROM Backs;
INSERT INTO Backs VALUES
('backer1@gmail.com', 'gold', 7, '2021-10-07','2022-05-01',700);




CREATE OR REPLACE FUNCTION successful_projects(
	given_date DATE
) RETURNS TABLE(id INT, c_email TEXT, ptype TEXT, c_date DATE, pname TEXT, deadline DATE, goal NUMERIC, amount NUMERIC) AS $$
BEGIN
	RETURN QUERY
	SELECT  p.id, p.email, p.ptype, p.created, p.name, p.deadline, p.goal, SUM(b.amount) AS amount
FROM Projects p 
	INNER JOIN
Backs b
ON p.id = b.id
	WHERE p.goal <= (SELECT SUM(b1.amount) FROM Backs b1 
					 WHERE p.id = b1.id)
	AND (p.deadline < given_date)
GROUP BY p.id;
END;
$$ LANGUAGE plpgsql;



SELECT successful_projects('2022-05-01');

WITH popular_project AS (
    SELECT p.id , p.name , p.email, p.created, t.backing, t.amount, p.goal,
    SUM(t.amount) OVER (PARTITION BY p.id ORDER BY t.backing) AS cumulativeTotal
    FROM 
      (SELECT * FROM Projects p
      WHERE p.created < '2023-05-01'
      AND p.ptype = ptype) AS p
    INNER JOIN 
      (SELECT b.id, b.backing, SUM(amount) AS amount
      FROM Backs b 
      GROUP BY b.id, b.backing
      ORDER BY b.id, b.backing ASC) AS t
      ON p.id = t.id)
SELECT *
FROM popular_project p;