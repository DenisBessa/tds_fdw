-- Test: JOIN with WHERE conditions on both tables
-- Tests combining WHERE conditions from different tables

SELECT
    e."nome" AS employee_name,
    c."nome" AS role_name
FROM
    foempregados e
    JOIN focargos c ON c."i_cargos" = e."i_cargos"
        AND c."codi_emp" = e."codi_emp"
WHERE
    e."codi_emp" = 5600
    AND c."i_cargos" > 0
LIMIT 10;

