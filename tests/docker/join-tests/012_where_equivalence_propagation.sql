-- Test: Join where a table has no columns selected (used only for filtering)
-- This replicates the exact problem pattern:
-- - geempre is joined but NO columns from it are selected
-- - WHERE clause is on geempre.codi_emp
-- - This should be pushed down efficiently

-- First, verify the EXPLAIN plan shows a single Foreign Scan (pushdown)
EXPLAIN (VERBOSE, COSTS OFF)
SELECT
    v."competencia" AS date,
    e."cpf"
FROM
    fovcheque v
    JOIN geempre g ON g."codi_emp" = v."codi_emp"
    JOIN foempregados e ON e."codi_emp" = v."codi_emp"
        AND e."i_empregados" = v."i_empregados"
WHERE
    g."codi_emp" = 5600
LIMIT 10;

-- Now run the actual query
SELECT
    v."competencia" AS date,
    e."cpf"
FROM
    fovcheque v
    JOIN geempre g ON g."codi_emp" = v."codi_emp"
    JOIN foempregados e ON e."codi_emp" = v."codi_emp"
        AND e."i_empregados" = v."i_empregados"
WHERE
    g."codi_emp" = 5600
LIMIT 10;

