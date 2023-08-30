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



/* ----- Find Top Success ----- */
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

CALL add_project(1, 'creator1@gmail.com', 'type1', '2021-10-01', 
                'project1', '2022-01-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600]);
CALL add_project(2, 'creator2@gmail.com', 'type1', '2021-10-01', 
                'project2', '2022-02-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600,2]);
CALL add_project(3, 'creator3@gmail.com', 'type1', '2021-10-01', 
                'project3', '2022-01-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600]);
CALL add_project(4, 'creator4@gmail.com', 'type1', '2021-10-01', 
                'project4', '2022-01-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600]);
CALL add_project(5, 'creator5@gmail.com', 'type1', '2021-10-01', 
                'project5', '2022-01-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600]);
SELECT * FROM Projects;


/* project deadlines are 2022-01-01 */
INSERT INTO Backs VALUES
('backer1@gmail.com', 'gold', 1, '2021-10-07','2022-05-01',600),
('backer2@gmail.com', 'bronze', 1, '2021-10-12','2022-05-01',400),
('backer2@gmail.com', 'silver', 2, '2021-10-10','2022-05-01',1000),
('backer3@gmail.com', 'bronze', 3, '2021-10-10','2022-03-01',600),
('backer4@gmail.com', 'silver', 4, '2021-10-01','2022-02-01',1000),
('backer5@gmail.com', 'silver', 5, '2021-10-10','2022-10-10',5000),
('backer6@gmail.com', 'gold', 5, '2021-10-10','2022-09-09',5000);




SELECT 'Test func 2' AS msg;
SELECT * FROM Projects;
SELECT * FROM Backs;

/* EXPECTED RESULTS */
-- before projects have ended, results should be empty as there are no sucessful projects
SELECT find_top_success(5, '2021-12-31', 'type1');


-- projects have ended except project 2, results should not include project 2
SELECT find_top_success(5, '2022-01-15', 'type1');

-- should have no results under 'type2'
SELECT find_top_success(5, '2022-01-15', 'type2');

SELECT * FROM successful_projects('2022-12-31');

-- smaller project id 
-- project 5 ranked first (largest ratio)
-- project 1, 2, 4 (same ratio)
  -- project 2 ranked first as later project deadline
  -- project 1, 4 (same project deadline)
    -- project 1 ranked first as smaller project id followed by project 4

SELECT find_top_success(3, '2022-12-31', 'type1');
SELECT find_top_success(5, '2022-12-31', 'type1');

