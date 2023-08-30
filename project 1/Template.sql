CREATE TABLE Users (
  email       VARCHAR(20) PRIMARY KEY,
  name        VARCHAR(20) NOT NULL,
  credit_card VARCHAR(255) NOT NULL, --- Multivalued attribute represented as a single string 
);

CREATE TABLE Creators (
  email          VARCHAR(20) PRIMARY KEY REFERENCES USERS,
  origin_country VARCHAR(20) NOT NULL,
  tax_code       VARCHAR(20) NOT NULL
);

CREATE TABLE Backers (
  email       VARCHAR(255) PRIMARY KEY REFERENCES USERS,
);

CREATE TABLE Address (
  backer_email    VARCHAR(20) PRIMARY KEY,  
  street_name   VARCHAR(20) NOT NULL,
  house_number  VARCHAR(20) NOT NULL,
  zip_code      VARCHAR(20) NOT NULL,
  country       VARCHAR(20) NOT NULL,
  FOREIGN KEY (backer_email) REFERENCES Backers(email)
)

CREATE TABLE Projects (
  project_id   SERIAL PRIMARY KEY,
  name         VARCHAR(20) NOT NULL,
  funding_goal VARCHAR(255) NOT NULL,
  deadline     VARCHAR(20) NOT NULL,
);

CREATE TABLE RewardLevels (
  project_id  REFERENCES Projects,
  name        VARCHAR (20) NOT NULL,
  min_funding INTEGER NOT NULL,
  PRIMARY KEY (project_id, name)
);

CREATE TABLE Employees (
  employee_id SERIAL PRIMARY KEY,
  name        VARCHAR(20) NOT NULL,
  salary      INTEGER NOT NULL
);

CREATE TABLE Backs (
  amount INT
);

CREATE TABLE RefundRequest (
  
  refund_status  INT,
  rejection_date INT
);

CREATE TABLE Tiers (

);

CREATE TABLE Creates (
  date INT
);


CREATE TABLE Updates (
  time INT
);

CREATE TABLE Processes (

);

CREATE TABLE Verifies (
  isVerified INT,
  date       INT
);

