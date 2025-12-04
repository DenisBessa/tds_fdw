-- Test: JOIN with WHERE on JOINED table (CRITICAL TEST CASE)
-- This is the problematic case: WHERE clause references a table that is NOT 
-- the first in the FROM clause.
-- Before the fix, this would fail or cause incorrect behavior.

SELECT
    "foempregados"."nome" AS "employee_name",
    "focargos"."nome" AS "role_name"
FROM
    "focargos"
    JOIN "foempregados" ON "foempregados"."i_cargos" = "focargos"."i_cargos"
        AND "foempregados"."codi_emp" = "focargos"."codi_emp"
WHERE
    "foempregados"."codi_emp" = 5600
LIMIT 10;
