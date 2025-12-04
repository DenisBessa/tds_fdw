-- Test: Multi-table JOIN with WHERE on primary table (WORKING CASE)
-- This query works because WHERE clause references the first table in FROM
-- Simplified to use only tables that exist

SELECT
    "foempregados"."nome" AS "name",
    "focargos"."nome" AS "role",
    "fodepto"."nome" AS "department"
FROM
    "foempregados"
    JOIN "focargos" ON "focargos"."i_cargos" = "foempregados"."i_cargos"
        AND "focargos"."codi_emp" = "foempregados"."codi_emp"
    JOIN "fodepto" ON "fodepto"."i_depto" = "foempregados"."i_depto"
        AND "fodepto"."codi_emp" = "foempregados"."codi_emp"
WHERE
    "foempregados"."codi_emp" = 5600
ORDER BY
    "foempregados"."nome" ASC
LIMIT 10;
