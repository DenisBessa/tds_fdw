-- Setup: Import foreign tables for JOIN testing
-- This follows the Sybase import pattern with proper case handling

-- Create helper procedure for importing tables
CREATE OR REPLACE PROCEDURE _import_if_not_exists(
    p_remote_schema TEXT,
    p_table_name TEXT,
    p_server_name TEXT,
    p_local_schema TEXT
)
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = p_local_schema 
        AND table_name = lower(p_table_name)
    ) THEN
        EXECUTE format(
            'IMPORT FOREIGN SCHEMA %I LIMIT TO (%I) FROM SERVER %I INTO %I',
            p_remote_schema, p_table_name, p_server_name, p_local_schema
        );
        RAISE NOTICE 'Imported table: %', p_table_name;
    ELSE
        RAISE NOTICE 'Table already exists: %', p_table_name;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Failed to import %: %', p_table_name, SQLERRM;
END;
$$;

-- Import tables needed for JOIN tests
CALL _import_if_not_exists('bethadba', 'foempregados', 'test_server', 'public');
CALL _import_if_not_exists('bethadba', 'focargos', 'test_server', 'public');
CALL _import_if_not_exists('bethadba', 'foccustos', 'test_server', 'public');
CALL _import_if_not_exists('bethadba', 'fodepto', 'test_server', 'public');
CALL _import_if_not_exists('bethadba', 'forescisoes', 'test_server', 'public');
CALL _import_if_not_exists('bethadba', 'FOVCHEQUE', 'test_server', 'public');
CALL _import_if_not_exists('bethadba', 'geempre', 'test_server', 'public');
CALL _import_if_not_exists('bethadba', 'fobancos', 'test_server', 'public');
CALL _import_if_not_exists('bethadba', 'FOAFASTAMENTOS_TIPOS', 'test_server', 'public');

-- Rename columns to lowercase
DO $$
DECLARE
    rec RECORD;
    rename_cmd TEXT;
BEGIN
    FOR rec IN
        SELECT
            n.nspname AS schemaname,
            c.relname AS tablename,
            a.attname AS column_name,
            lower(a.attname) AS new_column_name
        FROM pg_catalog.pg_attribute a
        JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
        JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
        WHERE
            c.relkind = 'f'
            AND a.attnum > 0
            AND NOT a.attisdropped
            AND a.attname <> lower(a.attname)
        ORDER BY n.nspname, c.relname, a.attnum
    LOOP
        rename_cmd := format(
            'ALTER FOREIGN TABLE %I.%I RENAME COLUMN %I TO %I',
            rec.schemaname, rec.tablename, rec.column_name, rec.new_column_name
        );
        EXECUTE rename_cmd;
    END LOOP;
END
$$;

-- Rename tables to lowercase
DO $$
DECLARE
    rec RECORD;
    rename_cmd TEXT;
BEGIN
    FOR rec IN
        SELECT
            n.nspname AS schema_name,
            c.relname AS table_name,
            lower(c.relname) AS new_table_name
        FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
        WHERE
            c.relkind = 'f'
            AND c.relname <> lower(c.relname)
            AND n.nspname NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
        ORDER BY n.nspname, c.relname
    LOOP
        IF EXISTS (
            SELECT 1
            FROM pg_catalog.pg_class c2
            JOIN pg_catalog.pg_namespace n2 ON c2.relnamespace = n2.oid
            WHERE n2.nspname = rec.schema_name AND c2.relname = rec.new_table_name AND c2.relkind = 'f'
        ) THEN
            EXECUTE format('DROP FOREIGN TABLE IF EXISTS %I.%I', rec.schema_name, rec.table_name);
        ELSE
            rename_cmd := format('ALTER FOREIGN TABLE %I.%I RENAME TO %I',
                rec.schema_name, rec.table_name, rec.new_table_name);
            EXECUTE rename_cmd;
        END IF;
    END LOOP;
END
$$;

-- Verify tables were imported
SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename IN (
    'foempregados', 'focargos', 'foccustos', 'fodepto', 'forescisoes', 
    'fovcheque', 'geempre', 'fobancos', 'foafastamentos_tipos'
);
