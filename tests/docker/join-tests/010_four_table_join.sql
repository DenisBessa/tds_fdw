-- Test: Four table JOIN with multiple conditions
-- Tests pushdown with four tables joined together (fovcheque, geempre, foempregados, fobancos)
-- This replicates a common payroll system query pattern

SELECT
    e."cpf",
    e."tipo_conta" AS account_type,
    b."i_bancos" AS bank_id,
    v."competencia" AS date,
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

