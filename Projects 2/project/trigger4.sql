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
BEFORE 
    INSERT ON Refunds 
FOR EACH ROW 
    EXECUTE FUNCTION refund_request_approval_check();



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
('backer2@gmail.com', 'bronze', 1, '2021-10-12','2022-05-01',1000),
('backer2@gmail.com', 'silver', 2, '2021-10-10','2022-05-01',1000),
('backer3@gmail.com', 'bronze', 3, '2021-10-10','2022-03-01',600),
('backer4@gmail.com', 'silver', 4, '2021-10-01','2022-02-01',1000),
('backer5@gmail.com', 'silver', 5, '2021-10-10','2022-10-10',5000),
('backer6@gmail.com', 'gold', 5, '2021-10-10','2022-09-09',5000),
('backer6@gmail.com', 'silver', 1, '2021-11-10',NULL,5000);



SELECT 'Test trigger 4' AS msg;
SELECT * FROM Projects;
SELECT * FROM Backs;
INSERT INTO Refunds VALUES
('backer3@gmail.com', 3, 1, '2022-05-01', TRUE); -- request date is 90 days within deadline
INSERT INTO Refunds VALUES
('backer4@gmail.com', 4, 1, '2022-05-01', FALSE); -- request date is 90 days within deadline
INSERT INTO Refunds VALUES
('backer5@gmail.com', 5, 1, '2022-05-01', FALSE); -- request date is 90 days after deadline
INSERT INTO Refunds VALUES
('backer6@gmail.com', 5, 1, '2022-05-01', TRUE); -- request date is 90 days after deadline (REJECT)
INSERT INTO Refunds VALUES
('backer6@gmail.com', 1, 1, '2022-05-01', TRUE); -- request is null (REJECT)

/* EXPECTED RESULTS */
-- first 3 tuples returned
SELECT * FROM refunds;