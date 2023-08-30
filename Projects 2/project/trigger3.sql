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
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER check_project_has_reward_level
AFTER INSERT
ON Projects
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_project_reward();

/*
    explanation
    trigger name: check_project_has_reward_level
    trigger function: check_project_reward()

    On the projects table, the trigger is run after each row of insertion to check if the project being inserted has at least one reward level in the rewards table. The trigger is initially deferred as the procedure add_project would insert a project first before inserting the reward levels for that project. In which case, the trigger is run after the procedure finish execution.

    The trigger function first counts the number of rewards in the reward table where the reward belongs to the project id being inserted.
    If the number of rewards is more than zero, we allow for the insertion to go ahead. Otherwise, we raise an exception and the insertion is rolled back.
*/

-- setup start
INSERT INTO public.users (email, name, cc1, cc2) VALUES ('kristopher09@yahoo.com', 'Megan Caldwell', '6011128348381842', NULL);

INSERT INTO public.creators (email, country) VALUES ('kristopher09@yahoo.com', 'India');

INSERT INTO public.employees (id, name, salary) VALUES (1, 'Ms. Sandy Hall DDS', 413.83);

INSERT INTO public.projecttypes (name, id) VALUES ('type_1', 1);
-- setup end

-- Tests
-- T1: add_project should work as expected
CALL add_project(1, 'kristopher09@yahoo.com', 
'type_1', '2022-10-25', 'project_name_1', '2022-10-25', 1000, '{level1, level2, level3}', '{100,200,300}');
SELECT * FROM projects;

-- T2: insert project without reward should fail (throw exception)
INSERT INTO public.projects (id, email, ptype, created, name, deadline, goal) VALUES (3, 'kathleenbennett@smith.net', 'type_1', '2022-09-20', 'Instrumental', '2022-09-20', 1000);

-- T3: insert project in transaction should insert
BEGIN;
INSERT INTO public.projects (id, email, ptype, created, name, deadline, goal) VALUES (3, 'kathleenbennett@smith.net', 'type_1', '2022-09-20', 'Instrumental', '2022-09-20', 1000),
;
INSERT INTO public.rewards (name, id, min_amt) VALUES ('level1', 3, 300);
COMMIT;
SELECT * FROM projects;

-- T4: multiple insert with no reward levels should fail
INSERT INTO public.projects (id, email, ptype, created, name, deadline, goal) VALUES (4, 'kathleenbennett@smith.net', 'type_1', '2022-09-20', 'Instrumental', '2022-09-20', 1000), (5, 'kathleenbennett@smith.net', 'type_1', '2022-09-20', 'Instrumental', '2022-09-20', 1000);