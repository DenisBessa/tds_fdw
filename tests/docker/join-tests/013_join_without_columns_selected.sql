-- Test: Join with table that has no columns selected
-- This is the EXACT problem case:
-- - geempre is joined but NO columns from it are selected
-- - WHERE clause is on fovcheque.codi_emp (NOT geempre.codi_emp)
-- - This should be pushed down efficiently

-- First show the EXPLAIN to see what's happening
EXPLAIN (VERBOSE, COSTS OFF)
SELECT
    e."cpf",
    e."tipo_conta" AS account_type,
    b."i_bancos" AS bank_id
FROM
    fovcheque v
    JOIN geempre g ON g."codi_emp" = v."codi_emp"
    JOIN foempregados e ON e."codi_emp" = v."codi_emp"
        AND e."i_empregados" = v."i_empregados"
    JOIN fobancos b ON b."i_bancos" = v."i_bancos"
WHERE
    v."codi_emp" = 5600
LIMIT 10;

-- Now run the actual query
SELECT
    e."cpf",
    e."tipo_conta" AS account_type,
    b."i_bancos" AS bank_id
FROM
    fovcheque v
    JOIN geempre g ON g."codi_emp" = v."codi_emp"
    JOIN foempregados e ON e."codi_emp" = v."codi_emp"
        AND e."i_empregados" = v."i_empregados"
    JOIN fobancos b ON b."i_bancos" = v."i_bancos"
WHERE
    v."codi_emp" = 5600
LIMIT 10;

