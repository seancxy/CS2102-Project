/** Setting up the schema, helpers and function 1 for testing **/

/** SCHEMA **/
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


/* ----- HELPER FUNCTIONS ----- */
CREATE OR REPLACE FUNCTION successful_projects(given_date DATE) RETURNS TABLE(
    id INT, c_email TEXT, c_ptype TEXT, c_date DATE, pname TEXT, deadline DATE, goal NUMERIC, amount NUMERIC
) AS $$ 
BEGIN 
    RETURN QUERY
    SELECT
        p.id, p.email, p.ptype, p.created, p.name, p.deadline, p.goal, SUM(b.amount) AS amount
    FROM Projects p
    INNER JOIN Backs b 
    ON p.id = b.id
    WHERE p.goal <= (SELECT SUM(b1.amount) FROM Backs b1 WHERE p.id = b1.id)
                    AND (p.deadline < given_date)
    GROUP BY p.id;
END;
$$ LANGUAGE plpgsql;

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


/** Should not have any records **/
SELECT * FROM find_superbackers('2022-10-25');

/** Insert statements to check for the first condition **/
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

INSERT INTO Employees VALUES
(1,'zhili1',1000),
(2,'zhili2',1000),
(3,'zhili3',1000),
(4,'zhili4',1000),
(5,'zhili5',1000);

INSERT INTO Verifies VALUES
('backer1@gmail.com', 1, '2022-01-01'),
('backer2@gmail.com', 1, '2022-01-01'),
('backer3@gmail.com', 1, '2022-01-01'),
('backer4@gmail.com', 1, '2022-01-01');

INSERT INTO ProjectTypes VALUES
('type1',1),
('type2',2),
('type3',3),
('type4',4),
('type5',5);

CALL add_project(1, 'creator1@gmail.com', 'type1', '2021-10-01', 
                'project1', '2022-10-01', 50, ARRAY['bronze', 'silver', 'gold'], ARRAY[50, 100, 150]);
CALL add_project(2, 'creator2@gmail.com', 'type2', '2021-10-01', 
                'project2', '2022-10-01', 50, ARRAY['bronze', 'silver', 'gold'], ARRAY[50, 100, 150]);
CALL add_project(3, 'creator3@gmail.com', 'type3', '2021-10-01', 
                'project3', '2022-10-01', 50, ARRAY['bronze', 'silver', 'gold'], ARRAY[50, 100, 150]);
CALL add_project(4, 'creator4@gmail.com', 'type4', '2021-10-01', 
                'project4', '2022-10-01', 50, ARRAY['bronze', 'silver', 'gold'], ARRAY[50, 100, 150]);
CALL add_project(5, 'creator5@gmail.com', 'type5', '2021-10-01', 
                'project5', '2022-10-01', 50, ARRAY['bronze', 'silver', 'gold'], ARRAY[50, 100, 150]);
CALL add_project(6, 'creator5@gmail.com', 'type5', '2021-10-01', 
                'project5', '2022-10-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600]);
CALL add_project(7, 'creator5@gmail.com', 'type5', '2021-10-01', 
                'project5', '2022-10-01', 50, ARRAY['bronze', 'silver', 'gold'], ARRAY[50, 100, 150]);
CALL add_project(8, 'creator5@gmail.com', 'type5', '2021-10-01', 
                'project5', '2022-10-01', 50, ARRAY['bronze', 'silver', 'gold'], ARRAY[50, 100, 150]);
CALL add_project(9, 'creator5@gmail.com', 'type5', '2021-10-01', 
                'project5', '2022-10-01', 50, ARRAY['bronze', 'silver', 'gold'], ARRAY[50, 100, 150]);
CALL add_project(10, 'creator5@gmail.com', 'type5', '2021-10-01', 
                'project5', '2022-10-01', 50, ARRAY['bronze', 'silver', 'gold'], ARRAY[50, 100, 150]);

/* project deadlines are 2022-01-01 */
INSERT INTO Backs VALUES
('backer1@gmail.com', 'gold', 1, '2021-10-07', null, 50),
('backer1@gmail.com', 'silver', 2, '2021-10-10', null, 50),
('backer1@gmail.com', 'bronze', 3, '2021-10-10', null, 50),
('backer1@gmail.com', 'silver', 4, '2021-10-01', null, 50),
('backer1@gmail.com', 'silver', 5, '2021-10-10', null, 50);

/** Should only have one super backer that passes the first condition **/
SELECT * FROM find_superbackers('2022-10-25');

/** Insert statements to check for the second condition **/
INSERT INTO Backs VALUES
('backer2@gmail.com', 'silver', 6, '2021-10-10', null, 1600);

/** Should show the new backer that passes the second condition **/
SELECT * FROM find_superbackers('2022-10-25');

/** Invalid superbacker: requested refund **/
INSERT INTO Backs VALUES
('backer3@gmail.com', 'silver', 6, '2021-10-10', '2022-10-01', 1600);

/** Should should not show backer 3 **/
SELECT * FROM find_superbackers('2022-10-25');

/** Invalid superbacker: user not validated **/
INSERT INTO Backs VALUES
('backer4@gmail.com', 'gold', 1, '2021-10-07', null, 50),
('backer4@gmail.com', 'bronze', 7, '2021-10-10', null, 50),
('backer4@gmail.com', 'bronze', 8, '2021-10-10', null, 50),
('backer4@gmail.com', 'bronze', 9, '2021-10-10', null, 50),
('backer4@gmail.com', 'bronze', 10, '2021-10-10', null, 50);

/** Should not show backer 4 **/
SELECT * FROM find_superbackers('2022-10-25');

/** Invalid superbacker: not enough project types **/
INSERT INTO Backs VALUES
('backer5@gmail.com', 'silver', 6, '2021-10-10', '2022-10-01', 1600);

/** Should should not show backer 5 **/
SELECT * FROM find_superbackers('2022-10-25');
