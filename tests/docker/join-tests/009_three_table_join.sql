-- Test: Three table JOIN
-- Tests pushdown with three tables joined together

SELECT
    e."nome" AS employee_name,
    c."nome" AS role_name,
    d."nome" AS department_name
FROM
    foempregados e
    JOIN focargos c ON c."i_cargos" = e."i_cargos"
        AND c."codi_emp" = e."codi_emp"
    JOIN fodepto d ON d."i_depto" = e."i_depto"
        AND d."codi_emp" = e."codi_emp"
WHERE
    e."codi_emp" = 5600
LIMIT 10;

