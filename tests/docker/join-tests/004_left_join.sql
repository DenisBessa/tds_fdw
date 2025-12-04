-- Test: LEFT JOIN between two tables
-- This tests LEFT OUTER JOIN pushdown functionality

SELECT
    e."nome" AS employee_name,
    c."nome" AS role_name
FROM
    foempregados e
    LEFT JOIN focargos c ON c."i_cargos" = e."i_cargos"
        AND c."codi_emp" = e."codi_emp"
LIMIT 10;

