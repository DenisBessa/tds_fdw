#!/bin/bash
# =============================================================================
# TDS_FDW JOIN Pushdown Test Runner
# =============================================================================
# This script runs individual JOIN pushdown tests in an isolated manner.
# It can be executed via docker run with TEST_NAME environment variable.
#
# Usage:
#   docker run --rm -e TEST_NAME=001_simple_inner_join tds_fdw_test
#   docker run --rm -e TEST_NAME=all tds_fdw_test  # Run all tests
#
# Environment Variables:
#   TEST_NAME       - Name of the test to run (without extension) or "all"
#   SYBASE_HOST     - Remote database host
#   SYBASE_PORT     - Remote database port
#   SYBASE_USER     - Remote database username
#   SYBASE_PASSWORD - Remote database password
#   SYBASE_DATABASE - Remote database name
#   SYBASE_SCHEMA   - Remote database schema (default: dbo)
#   DEBUG_MODE      - Set to "1" to enable verbose output
#   QUERY_TIMEOUT   - Timeout in seconds for each query (default: 10)
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TESTS_DIR="/tests/join-tests"
RESULTS_DIR="/tmp/test-results"
LOG_FILE="${RESULTS_DIR}/test.log"

# Default values
SYBASE_SCHEMA="${SYBASE_SCHEMA:-dbo}"
DEBUG_MODE="${DEBUG_MODE:-0}"
QUERY_TIMEOUT="${QUERY_TIMEOUT:-10}"
SETUP_TIMEOUT="${SETUP_TIMEOUT:-120}"  # Longer timeout for setup (IMPORT FOREIGN SCHEMA)

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[INFO] $1" >> "${LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    echo "[PASS] $1" >> "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    echo "[FAIL] $1" >> "${LOG_FILE}"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "[WARN] $1" >> "${LOG_FILE}"
}

log_debug() {
    if [ "${DEBUG_MODE}" = "1" ]; then
        echo -e "${YELLOW}[DEBUG]${NC} $1"
        echo "[DEBUG] $1" >> "${LOG_FILE}"
    fi
}

# =============================================================================
# Database Setup Functions
# =============================================================================

wait_for_postgres() {
    log_info "Waiting for PostgreSQL to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if pg_isready -U postgres -q 2>/dev/null; then
            log_info "PostgreSQL is ready."
            return 0
        fi
        log_debug "Attempt $attempt/$max_attempts - PostgreSQL not ready yet..."
        sleep 1
        attempt=$((attempt + 1))
    done
    
    log_error "PostgreSQL did not become ready in time."
    return 1
}

test_connection() {
    log_info "Testing connection to remote server..."
    
    # Try to connect using tsql (FreeTDS tool)
    if command -v tsql &> /dev/null; then
        log_debug "Using tsql to test connection..."
        if timeout 30 bash -c "echo 'quit' | tsql -H ${SYBASE_HOST} -p ${SYBASE_PORT} -U ${SYBASE_USER} -P '${SYBASE_PASSWORD}' 2>&1" | head -10; then
            log_info "Connection test completed"
            return 0
        else
            log_warning "Connection test failed or timed out"
            return 1
        fi
    else
        log_warning "tsql not available, skipping connection test"
        return 0
    fi
}

setup_extension() {
    log_info "Setting up tds_fdw extension..."
    
    # Test connection first
    test_connection || log_warning "Connection test failed, continuing anyway..."
    
    # Get TDS version from env or use default
    local tds_ver="${TDS_VERSION:-5.0}"
    
    psql -U postgres -d testdb -q <<EOF
-- Create the extension
CREATE EXTENSION IF NOT EXISTS tds_fdw;

-- Drop existing server if exists
DROP SERVER IF EXISTS test_server CASCADE;

-- Create foreign server with JOIN pushdown enabled
CREATE SERVER test_server
    FOREIGN DATA WRAPPER tds_fdw
    OPTIONS (
        servername '${SYBASE_HOST}',
        port '${SYBASE_PORT}',
        database '${SYBASE_DATABASE}',
        tds_version '${tds_ver}',
        msg_handler 'notice',
        enable_join_pushdown 'true'
    );

-- Create user mapping
CREATE USER MAPPING IF NOT EXISTS FOR postgres
    SERVER test_server
    OPTIONS (
        username '${SYBASE_USER}',
        password '${SYBASE_PASSWORD}'
    );
EOF
    
    log_info "Extension setup complete."
}

# =============================================================================
# Test Execution Functions
# =============================================================================

get_test_info() {
    local test_name=$1
    local json_file="${TESTS_DIR}/${test_name}.json"
    
    if [ -f "${json_file}" ]; then
        cat "${json_file}"
    else
        echo "{}"
    fi
}

get_test_description() {
    local test_name=$1
    local json_file="${TESTS_DIR}/${test_name}.json"
    
    if [ -f "${json_file}" ]; then
        python3 -c "import json; print(json.load(open('${json_file}'))['test_desc'])" 2>/dev/null || echo "${test_name}"
    else
        echo "${test_name}"
    fi
}

should_check_pushdown() {
    local test_name=$1
    local json_file="${TESTS_DIR}/${test_name}.json"
    
    if [ -f "${json_file}" ]; then
        python3 -c "import json; print(json.load(open('${json_file}')).get('expect_pushdown', True))" 2>/dev/null || echo "True"
    else
        echo "True"
    fi
}

substitute_variables() {
    local sql=$1
    
    # Substitute variables in SQL
    sql="${sql//@SYBASE_HOST/${SYBASE_HOST}}"
    sql="${sql//@SYBASE_PORT/${SYBASE_PORT}}"
    sql="${sql//@SYBASE_USER/${SYBASE_USER}}"
    sql="${sql//@SYBASE_PASSWORD/${SYBASE_PASSWORD}}"
    sql="${sql//@SYBASE_DATABASE/${SYBASE_DATABASE}}"
    sql="${sql//@SYBASE_SCHEMA/${SYBASE_SCHEMA}}"
    
    echo "${sql}"
}

run_single_test() {
    local test_name=$1
    local sql_file="${TESTS_DIR}/${test_name}.sql"
    local result_file="${RESULTS_DIR}/${test_name}.result"
    local explain_file="${RESULTS_DIR}/${test_name}.explain"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Check if SQL file exists
    if [ ! -f "${sql_file}" ]; then
        log_error "Test file not found: ${sql_file}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
    
    # Use longer timeout for setup tests
    local current_timeout="${QUERY_TIMEOUT}"
    if [[ "${test_name}" == *"setup"* ]] || [[ "${test_name}" == "000_"* ]]; then
        current_timeout="${SETUP_TIMEOUT}"
        log_debug "Using setup timeout: ${current_timeout}s"
    fi
    
    local test_desc=$(get_test_description "${test_name}")
    log_info "Running test: ${test_name} - ${test_desc}"
    
    # Read and substitute SQL
    local sql_content=$(cat "${sql_file}")
    sql_content=$(substitute_variables "${sql_content}")
    
    log_debug "SQL: ${sql_content}"
    
    # First, run EXPLAIN to check if JOIN pushdown is happening (with timeout)
    local check_pushdown=$(should_check_pushdown "${test_name}")
    
    if [ "${check_pushdown}" = "True" ]; then
        log_debug "Checking EXPLAIN output for JOIN pushdown..."
        
        # Extract the main SELECT query (skip setup statements)
        local main_query=$(echo "${sql_content}" | grep -i "^SELECT" | head -1)
        
        if [ -n "${main_query}" ]; then
            local explain_sql="EXPLAIN (VERBOSE, COSTS OFF) ${main_query}"
            
            if timeout "${current_timeout}s" psql -U postgres -d testdb -q -c "${explain_sql}" > "${explain_file}" 2>&1; then
                # Check if the plan shows a single Foreign Scan (pushdown) vs multiple
                if grep -q "Foreign Scan" "${explain_file}"; then
                    local foreign_scan_count=$(grep -c "Foreign Scan" "${explain_file}" || echo "0")
                    log_debug "Foreign Scan count in plan: ${foreign_scan_count}"
                    
                    if [ "${foreign_scan_count}" -eq 1 ]; then
                        log_debug "JOIN pushdown detected (single Foreign Scan)"
                    else
                        log_warning "Multiple Foreign Scans detected - JOIN may not be pushed down"
                    fi
                fi
                
                if [ "${DEBUG_MODE}" = "1" ]; then
                    log_debug "EXPLAIN output:"
                    cat "${explain_file}"
                fi
            else
                log_warning "EXPLAIN timed out or failed"
            fi
        fi
    fi
    
    # Execute the actual test with timeout
    if timeout "${current_timeout}s" psql -U postgres -d testdb -q -c "${sql_content}" > "${result_file}" 2>&1; then
        log_success "Test passed: ${test_name}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_error "Test TIMEOUT after ${current_timeout}s: ${test_name}"
        else
            log_error "Test failed: ${test_name}"
        fi
        log_error "Error output:"
        cat "${result_file}" 2>/dev/null || echo "(no output)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

run_all_tests() {
    log_info "Running all JOIN pushdown tests..."
    
    # Find all .sql files in tests directory
    for sql_file in "${TESTS_DIR}"/*.sql; do
        if [ -f "${sql_file}" ]; then
            local test_name=$(basename "${sql_file}" .sql)
            run_single_test "${test_name}" || true
        fi
    done
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo "=============================================="
    echo " TDS_FDW JOIN Pushdown Test Runner"
    echo "=============================================="
    
    # Create results directory
    mkdir -p "${RESULTS_DIR}"
    echo "Test run started at $(date)" > "${LOG_FILE}"
    
    # Validate environment
    if [ -z "${SYBASE_HOST}" ]; then
        log_error "SYBASE_HOST environment variable is required"
        exit 1
    fi
    
    if [ -z "${TEST_NAME}" ]; then
        log_error "TEST_NAME environment variable is required (use 'all' for all tests)"
        exit 1
    fi
    
    log_info "Configuration:"
    log_info "  SYBASE_HOST: ${SYBASE_HOST}"
    log_info "  SYBASE_PORT: ${SYBASE_PORT}"
    log_info "  SYBASE_DATABASE: ${SYBASE_DATABASE}"
    log_info "  SYBASE_SCHEMA: ${SYBASE_SCHEMA}"
    log_info "  TEST_NAME: ${TEST_NAME}"
    log_info "  DEBUG_MODE: ${DEBUG_MODE}"
    log_info "  QUERY_TIMEOUT: ${QUERY_TIMEOUT}s"
    log_info "  SETUP_TIMEOUT: ${SETUP_TIMEOUT}s"
    
    # Wait for PostgreSQL
    wait_for_postgres || exit 1
    
    # Setup extension
    setup_extension || exit 1
    
    # Run tests
    if [ "${TEST_NAME}" = "all" ]; then
        run_all_tests
    else
        run_single_test "${TEST_NAME}"
    fi
    
    # Print summary
    echo ""
    echo "=============================================="
    echo " Test Summary"
    echo "=============================================="
    echo "  Total:   ${TOTAL_TESTS}"
    echo "  Passed:  ${PASSED_TESTS}"
    echo "  Failed:  ${FAILED_TESTS}"
    echo "  Skipped: ${SKIPPED_TESTS}"
    echo "=============================================="
    
    # Exit with appropriate code
    if [ ${FAILED_TESTS} -gt 0 ]; then
        exit 1
    fi
    
    exit 0
}

# Run main function
main "$@"
