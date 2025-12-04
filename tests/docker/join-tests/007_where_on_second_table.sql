-- Test: JOIN with WHERE on second (joined) table
-- Simplified version of the failing case - WHERE references the second table

SELECT
    e."nome" AS employee_name,
    c."nome" AS role_name
FROM
    foempregados e
    JOIN focargos c ON c."i_cargos" = e."i_cargos"
        AND c."codi_emp" = e."codi_emp"
WHERE
    c."codi_emp" = 5600
LIMIT 10;

