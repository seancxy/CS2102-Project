CREATE OR REPLACE PROCEDURE add_project(
  id      INT,     email TEXT,   ptype    TEXT,
  created DATE,    name  TEXT,   deadline DATE,
  goal    NUMERIC, names TEXT[],
  amounts NUMERIC[]
) AS $$
-- add declaration here
DECLARE idx INT; len INT;
BEGIN
  -- your code here
  INSERT INTO projects VALUES (id, email, ptype, created, name, deadline, goal);

  len := LEAST(array_length(names, 1), array_length(amounts, 1));
  idx := 1;
  LOOP
  EXIT WHEN idx > len;
    INSERT INTO Rewards VALUES (names[idx], id, amounts[idx]);
  	idx := idx + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;


/*
  explanation:
  In the add_project procedure, we first insert into projects the relevant fields.
  Then we get the smaller of the array lengths between names and amounts to prevent accessing arrays out of bounds.
  However, since we could assume that the length of names and amounts will always be the same, this does not matter and we left it anyway as a defensive mechanism.
  We then loop through the array starting at index 1 and increment it by 1 for each loop.
  In each iteration, we insert into the rewards table with the corresponding names, amounts, and the project id.
  We stop when the index is more than the length of the arrays.
*/



-- start setup
INSERT INTO public.users (email, name, cc1, cc2) VALUES ('kristopher09@yahoo.com', 'Megan Caldwell', '6011128348381842', NULL);

INSERT INTO public.creators (email, country) VALUES ('kristopher09@yahoo.com', 'India');

INSERT INTO public.employees (id, name, salary) VALUES (1, 'Ms. Sandy Hall DDS', 413.83);

INSERT INTO public.projecttypes (name, id) VALUES ('type_1', 1);
-- end setup

-- valid: multiple reward levels
CALL add_project(1, 'kristopher09@yahoo.com', 
'type_1', '2022-10-25', 'project_name_1', '2022-10-25', 1000, '{level1, level2, level3}', '{100,200,300}');

-- valid: 1 reward level
CALL add_project(2, 'kristopher09@yahoo.com', 
'type_1', '2022-10-25', 'project_name_1', '2022-10-30', 10, '{level1}', '{100}');

-- valid: decimal goal and min_amt
CALL add_project(3, 'kristopher09@yahoo.com', 
'type_1', '2022-10-25', 'project_name_1', '2022-10-30', 0.0001, '{level1}', '{0.1}');

-- invalid: empty reward level
CALL add_project(4, 'kristopher09@yahoo.com', 
'type_1', '2022-10-25', 'project_name_1', '2022-10-30', 0.0001, '{}', '{}');

-- invalid: non-empty names but empty amounts
CALL add_project(4, 'kristopher09@yahoo.com', 
'type_1', '2022-10-25', 'project_name_1', '2022-10-30', 0.0001, '{level1}', '{}');

-- invalid: non-empty amounts but empty names
CALL add_project(4, 'kristopher09@yahoo.com', 
'type_1', '2022-10-25', 'project_name_1', '2022-10-30', 0.0001, '{}', '{100}');


SELECT * FROM information_schema.triggers;