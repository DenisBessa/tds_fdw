-- Test: Four table JOIN with WHERE on intermediate table
-- This is the exact pattern causing performance issues:
-- - fovcheque is the main table (first in FROM)
-- - geempre is an intermediate table with the WHERE condition
-- - foempregados is joined with multiple conditions
-- - fobancos is the last table

SELECT
    e."cpf",
    e."tipo_conta" AS account_type,
    b."i_bancos" AS bank_id,
    v."i_empregados" AS employee_id,
    g."codi_emp" AS company_id
FROM
    fovcheque v
    JOIN geempre g ON g."codi_emp" = v."codi_emp"
    JOIN foempregados e ON e."codi_emp" = v."codi_emp"
        AND e."i_empregados" = v."i_empregados"
    JOIN fobancos b ON b."i_bancos" = v."i_bancos"
WHERE
    g."codi_emp" = 5600
LIMIT 10;

