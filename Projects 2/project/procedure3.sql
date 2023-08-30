/* Procedure #3 */
CREATE OR REPLACE PROCEDURE auto_reject(
  eid INT, today DATE
) AS $$
-- add declaration here
DECLARE 
	curs CURSOR FOR ( SELECT * FROM Backs b WHERE b.request IS NOT NULL AND (b.request - (SELECT deadline FROM Projects WHERE id = b.id)) > 90);
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

/*
    explanation
    In the auto_reject procedure, we first declare a cursor for backs where the backer has requested for refund and 
    that the date of refund request is more than 90 days from the deadline of the project.
    We then loop through each record using the cursor and insert the relevant fields into the refunds table with accepted set as FALSE.
    This would meant that the refund is rejected.
    We will terminate when there is no more record found and thereafter close the cursor and end the procedure.
*/
-- setup start
BEGIN;
-- employees
INSERT INTO public.employees (id, name, salary) VALUES (1, 'Ms. Sandy Hall DDS', 413.83);

-- projecttype
INSERT INTO public.projecttypes (name, id) VALUES ('type_1', 1);

-- creators
INSERT INTO public.users (email, name, cc1, cc2) VALUES ('kathleenbennett@smith.net', 'Kristin Williams', '4055898833299913', NULL);
INSERT INTO public.users (email, name, cc1, cc2) VALUES ('edwardberry@williams-singh.biz', 'Phillip Davidson', '3575482291636297', NULL);
INSERT INTO public.creators (email, country) VALUES ('kathleenbennett@smith.net', 'South Georgia and the South Sandwich Islands');
INSERT INTO public.creators (email, country) VALUES ('edwardberry@williams-singh.biz', 'Djibouti');

-- backers
INSERT INTO public.users (email, name, cc1, cc2) VALUES ('grossanita@gmail.com', 'Lynn Gibson', '6523903433498615', '4682570140034694');
INSERT INTO public.users (email, name, cc1, cc2) VALUES ('myerschristopher@martinez.com', 'Holly Meyer', '370064293718621', NULL);
INSERT INTO public.backers (email, street, num, zip, country) VALUES ('grossanita@gmail.com', '7627 Atkinson Harbors Suite 276', '5819908091', '40604', 'Cyprus');
INSERT INTO public.backers (email, street, num, zip, country) VALUES ('myerschristopher@martinez.com', '0712 Robertson Oval', '(114)348-8601x17278', '42732', 'Libyan Arab Jamahiriya');

-- projects
INSERT INTO public.projects (id, email, ptype, created, name, deadline, goal) VALUES (1, 'kathleenbennett@smith.net', 'type_1', '2022-09-20', 'Instrumental', '', 1000);
INSERT INTO public.projects (id, email, ptype, created, name, deadline, goal) VALUES (2, 'edwardberry@williams-singh.biz', 'type_1', '2022-08-11', 'Post-Disco', '2022-10-18', 50.001);

-- rewards
INSERT INTO public.rewards (name, id, min_amt) VALUES ('bronze', 1, 300);
INSERT INTO public.rewards (name, id, min_amt) VALUES ('silver', 1, 500);
INSERT INTO public.rewards (name, id, min_amt) VALUES ('bronze', 2, 400);
INSERT INTO public.rewards (name, id, min_amt) VALUES ('silver', 2, 900);

COMMIT;
-- setup end

-- Tests
-- T1: no backs should not have refund
CALL auto_reject(1, '2024-10-20');
SELECT * FROM refunds; -- empty 

-- T2: did not request for refund should not have refund
INSERT INTO public.backs (email, name, id, backing, request, amount) VALUES ('grossanita@gmail.com', 'bronze', 1, '2022-09-08', NULL, 400); 
CALL auto_reject(1, '2024-10-20');
SELECT * FROM refunds; -- empty

--  T3: within 90 days should not reject
INSERT INTO public.backs (email, name, id, backing, request, amount) VALUES ('grossanita@gmail.com', 'bronze', 2,'2022-08-11' , '2023-01-16', 400); -- == 90 days
INSERT INTO public.backs (email, name, id, backing, request, amount) VALUES ('myerschristopher@martinez.com', 'bronze', 2, '2022-10-18', '2023-01-15', 400); -- < 90 days
CALL auto_reject(1, '2024-10-20');
SELECT * FROM refunds; -- empty

-- T4: more than 90 days should reject
INSERT INTO public.backs (email, name, id, backing, request, amount) VALUES ('myerschristopher@martinez.com', 'bronze', 1, '2023-01-17', '2022-12-20', 400); -- > 90 days
CALL auto_reject(1, '2024-10-20');
SELECT * FROM refunds -- 1 result;