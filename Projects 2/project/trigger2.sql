/** Setting up the schema and trigger 2 for testing **/

/** SCHEMA **/
DROP TABLE IF EXISTS Employees, Users, Verifies, Backers, Creators, ProjectTypes, Projects, Updates, Rewards, Backs, Refunds CASCADE;
DROP TRIGGER IF EXISTS create_back_amount ON Backs;
DROP FUNCTION IF EXISTS back_amount_check();


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

/* ----- TRIGGER QN #2     ----- */
CREATE OR REPLACE FUNCTION back_amount_check() 
RETURNS TRIGGER AS $$ 
DECLARE min NUMERIC;
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

/** Generating test data **/
CALL add_user('creator1@gmail.com', 'creator1', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'CREATOR');
CALL add_user('creator2@gmail.com', 'creator2', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'CREATOR');
CALL add_user('creator3@gmail.com', 'creator3', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'CREATOR');
CALL add_user('creator4@gmail.com', 'creator3', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'CREATOR');
CALL add_user('creator5@gmail.com', 'creator3', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'CREATOR');
CALL add_user('backer1@gmail.com', 'backer1', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'BACKER');
CALL add_user('backer2@gmail.com', 'backer2', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'BACKER');
CALL add_user('backer3@gmail.com', 'backer3', 'cc1_123', NULL, 'st', '999', 'S123456', 'SG', 'BACKER');

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
                'project1', '2022-10-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600]);
CALL add_project(2, 'creator2@gmail.com', 'type2', '2021-10-01', 
                'project2', '2022-10-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600]);
CALL add_project(3, 'creator3@gmail.com', 'type3', '2021-10-01', 
                'project3', '2022-10-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600]);
CALL add_project(4, 'creator4@gmail.com', 'type4', '2021-10-01', 
                'project4', '2022-10-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600]);
CALL add_project(5, 'creator5@gmail.com', 'type5', '2021-10-01', 
                'project5', '2022-10-01', 1000, ARRAY['bronze', 'silver', 'gold'], ARRAY[200, 400, 600]);

/** Should not have any records **/
SELECT * FROM Backs;

/** Successful insert, exception should not be raised **/
INSERT INTO Backs VALUES
('backer1@gmail.com', 'gold', 1, '2021-10-07', null, 1100),
('backer2@gmail.com', 'bronze', 1, '2021-10-07', null, 200);

/** Invalid backings, exception should be raised **/
INSERT INTO Backs VALUES
('backer3@gmail.com', 'gold', 1, '2021-10-07', null, 599);

INSERT INTO Backs VALUES
('backer3@gmail.com', 'bronze', 1, '2021-10-07', null, 199);

