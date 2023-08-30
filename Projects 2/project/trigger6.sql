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

DROP FUNCTION IF EXISTS successful_projects(date);

/* ----- HELPER FUNCTIONS ----- */
CREATE OR REPLACE FUNCTION successful_projects(given_date DATE) RETURNS TABLE(
    id INT, c_email TEXT, ptype TEXT, c_date DATE, pname TEXT, deadline DATE, goal NUMERIC, amount NUMERIC
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

DROP TRIGGER IF EXISTS check_request_refund_on_successful_projects ON Backs;
DROP FUNCTION IF EXISTS check_request_on_successful_projects;

/* ----- TRIGGER QN #6  ----- */
CREATE OR REPLACE FUNCTION check_request_on_successful_projects() 
RETURNS TRIGGER AS $$ 
BEGIN 
    IF EXISTS (SELECT 1 
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
    On Backs 
FOR EACH ROW
    WHEN (OLD.request IS NULL AND NEW.request IS NOT NULL)
    EXECUTE FUNCTION check_request_on_successful_projects();

/* ------------------------ */


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
('backer4@gmail.com', 'silver', 4, '2021-10-01',NULL,1000),
('backer5@gmail.com', 'silver', 5, '2021-10-10',NULL,5000),
('backer6@gmail.com', 'gold', 5, '2021-10-10',NULL,5000);



drop procedure if exists update_backs;
CREATE OR REPLACE PROCEDURE update_backs(b_email TEXT, b_id INT, request_date DATE) 
AS $$ -- add declaration here
BEGIN -- your code here
    UPDATE Backs 
    SET request = request_date
    WHERE email = b_email
    AND id = b_id;
END;
$$ LANGUAGE plpgsql;


SELECT 'Test func 2' AS msg;
SELECT * FROM Projects;
SELECT * FROM Backs;


/* EXPECTED RESULTS */
-- before projects have ended, results should be empty as there are no sucessful projects
CALL update_backs('backer1@gmail.com', 1, '2050-02-01'); -- initial request date is not null, invalid update
CALL update_backs('backer4@gmail.com', 4, NULL); -- initial request date is null, new request date is null, invalid update
CALL update_backs('backer5@gmail.com', 5, 'hello'); -- initial request date is null, invalid new request date
CALL update_backs('backer6@gmail.com', 6, '2050-01-01'); -- project id is not valid, invalid update
CALL update_backs('backer6@gmail.com', 5, '2050-01-01'); -- initial request date is null, valid update

-- expected results:
-- only 'backer6@gmail.com', 5, request date should be changed from null to '2050-01-01'

SELECT * FROM Backs;

