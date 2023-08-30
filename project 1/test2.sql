DROP TABLE IF EXISTS Users CASCADE;
DROP TABLE IF EXISTS Creators CASCADE;
DROP TABLE IF EXISTS Backers CASCADE;
DROP TABLE IF EXISTS Projects CASCADE;
DROP TABLE IF EXISTS RewardLevels CASCADE;
DROP TABLE IF EXISTS Backs CASCADE;
DROP TABLE IF EXISTS Refund CASCADE;
DROP TABLE IF EXISTS Processes CASCADE;
DROP TABLE IF EXISTS Employees CASCADE;
DROP TABLE IF EXISTS Verifies CASCADE;
DROP TABLE IF EXISTS Updates CASCADE;

CREATE TABLE Users (
email       TEXT PRIMARY KEY,
name        TEXT NOT NULL,
credit_card_1 	TEXT NOT NULL,
credit_card_2 TEXT
);


CREATE TABLE Creators (
email          TEXT 	PRIMARY KEY,
origin_country 	TEXT 	NOT NULL,
FOREIGN KEY (email) REFERENCES Users(email) ON DELETE CASCADE ON
UPDATE CASCADE
);


CREATE TABLE Backers (
email       TEXT 	PRIMARY KEY,
street_name 	TEXT 	NOT NULL,  
house_number  TEXT 	NOT NULL,
zip_code      TEXT 	NOT NULL,
country_name       TEXT 	NOT NULL,
FOREIGN KEY (email) REFERENCES Users(email) ON DELETE CASCADE ON
UPDATE CASCADE
);


CREATE TABLE Projects (
project_id   	SERIAL 	PRIMARY KEY,
name         TEXT NOT NULL,
funding_goal 	NUMERIC NOT NULL,
deadline     DATE NOT NULL,
date_created 		DATE NOT NULL,
creator_email 		TEXT NOT NULL, -- Each project must have a creator
FOREIGN KEY (creator_email) REFERENCES Creators (email) ON UPDATE CASCADE
);


-- includes tier 
CREATE TABLE RewardLevels (
name        TEXT,
project_id        SERIAL,
min_funding 	   NUMERIC NOT NULL,
FOREIGN KEY (project_id) REFERENCES Projects(project_id) ON DELETE CASCADE ON UPDATE CASCADE,
PRIMARY KEY (name, project_id)
);


CREATE TABLE Backs (
backer_email 		TEXT,
level_name 	TEXT,
pid 	SERIAL,
amount 	NUMERIC,
FOREIGN KEY (level_name, pid) REFERENCES RewardLevels (name, project_id) ON UPDATE CASCADE,
FOREIGN KEY (backer_email) REFERENCES Backers (email) ON UPDATE CASCADE,
UNIQUE(backer_email, pid), -- Each backer can only back a project once
PRIMARY KEY (backer_email, level_name, pid)
);


CREATE TABLE Refund (
status 		TEXT 	NOT NULL 	DEFAULT 'pending' CHECK (status in ('pending', 'approve', 'reject')),
date 	DATE NOT NULL, -- date requested
backer_email 	TEXT,
level_name 	TEXT,
pid 	SERIAL,
PRIMARY KEY (backer_email, level_name, pid),
FOREIGN KEY (backer_email, level_name, pid) REFERENCES Backs(backer_email,
level_name, pid) ON DELETE CASCADE ON UPDATE CASCADE
);


CREATE TABLE Employees (
 employee_id 		SERIAL 	PRIMARY KEY,
 name        TEXT 	NOT NULL,
 salary      NUMERIC 	NOT NULL
);

CREATE TABLE Processes (
employee_id 	SERIAL,
date 	DATE,
backer_email 	TEXT,
level_name 	TEXT,
pid 	SERIAL,
PRIMARY KEY (employee_id, backer_email, level_name, pid),
FOREIGN KEY (backer_email, level_name, pid) REFERENCES Refund (backer_email, level_name, pid) ON UPDATE CASCADE,
FOREIGN KEY (employee_id) REFERENCES Employees(employee_id) ON UPDATE CASCADE
);


CREATE TABLE Verifies (
email     TEXT,
employee_id	 SERIAL,
date       DATE NOT NULL,
PRIMARY KEY (email, employee_id),
FOREIGN KEY (email) REFERENCES Users(email) ON UPDATE CASCADE,
FOREIGN KEY (employee_id) REFERENCES Employees(employee_id) ON UPDATE CASCADE
);


CREATE TABLE Updates (
project_id 	SERIAL,
time 	TIMESTAMP,
PRIMARY KEY (project_id, time),
FOREIGN KEY (project_id) REFERENCES Projects(project_id) ON DELETE CASCADE ON UPDATE CASCADE
);

