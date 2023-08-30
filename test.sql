/* Function #3  */
CREATE OR REPLACE FUNCTION find_top_popular(n INT, today DATE, ptype TEXT) 
RETURNS TABLE(id INT, name TEXT, email TEXT, days INT) AS $$ 
DECLARE 
    tempType TEXT := ptype;
BEGIN
    RETURN QUERY 
    SELECT p.id, p.name, p.email, num_days_to_reach_funding(p.id) AS days
    FROM Projects p
    WHERE p.ptype = tempType
    AND p.created < today
    ORDER BY days ASC, id ASC
    LIMIT n;
END;
$$ LANGUAGE plpgsql;



