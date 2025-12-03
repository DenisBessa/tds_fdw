/*------------------------------------------------------------------
*
*				Foreign data wrapper for TDS (Sybase and Microsoft SQL Server)
*
* Author: Geoff Montee
* Name: tds_fdw
* File: tds_fdw/include/tds_fdw.h
*
* Description:
* This is a PostgreSQL foreign data wrapper for use to connect to databases that use TDS,
* such as Sybase databases and Microsoft SQL server.
*
* This foreign data wrapper requires requires a library that uses the DB-Library interface,
* such as FreeTDS (http://www.freetds.org/). This has been tested with FreeTDS, but not
* the proprietary implementations of DB-Library.
*----------------------------------------------------------------------------
*/


#ifndef TDS_FDW_H
#define TDS_FDW_H

/* postgres headers */

#include "postgres.h"
#include "funcapi.h"
#if PG_VERSION_NUM < 180000
#include "commands/explain.h"
#else
#include "commands/explain_state.h"
#endif
#include "foreign/fdwapi.h"
#include "foreign/foreign.h"

#if (PG_VERSION_NUM >= 90200)
#include "optimizer/pathnode.h"
#include "optimizer/restrictinfo.h"
#include "optimizer/planmain.h"
#endif

/* DB-Library headers (e.g. FreeTDS) */
#include <sybfront.h>
#include <sybdb.h>

#include "options.h"

#if PG_VERSION_NUM >= 90500
#define IMPORT_API
#else
#undef IMPORT_API
#endif  /* PG_VERSION_NUM */

/* a column */

typedef union COL_VALUE
{
	DBSMALLINT dbsmallint;
	DBINT dbint;
	DBBIGINT dbbigint;
	DBREAL dbreal;
	DBFLT8 dbflt8;
} COL_VALUE;

typedef struct COL
{
	char *name;
	int srctype;
	bool useraw;
	COL_VALUE value;
	int local_index;
	Oid attr_oid;
} COL;

/*
 * Enum for relation types - base relations vs join relations
 * This is used to distinguish between simple foreign table scans
 * and pushdown joins between foreign tables.
 */
typedef enum TdsFdwRelationType
{
	TDS_REL_BASE,		/* Base relation (single foreign table) */
	TDS_REL_JOIN		/* Join relation (join between foreign tables) */
} TdsFdwRelationType;

/* This struct is similar to PgFdwRelationInfo from postgres_fdw */
typedef struct TdsFdwRelationInfo
{
	/*
	 * Type of relation: base table or join.
	 * For PostgreSQL 9.5+, we support JOIN pushdown.
	 */
	TdsFdwRelationType	rel_type;

	/* baserestrictinfo clauses, broken down into safe and unsafe subsets. */
	List	   *remote_conds;
	List	   *local_conds;

	/* Bitmap of attr numbers we need to fetch from the remote server. */
	Bitmapset  *attrs_used;

	/* Cost and selectivity of local_conds. */
	QualCost	local_conds_cost;
	Selectivity local_conds_sel;

	/* Estimated size and cost for a scan with baserestrictinfo quals. */
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;

	/* Options extracted from catalogs. */
	bool		use_remote_estimate;
	Cost		fdw_startup_cost;
	Cost		fdw_tuple_cost;

	/* Cached catalog information. */
	ForeignTable *table;
	ForeignServer *server;
	UserMapping *user;			/* only set in use_remote_estimate mode */

	/*
	 * Join pushdown support (PostgreSQL 9.5+)
	 */
#if (PG_VERSION_NUM >= 90500)
	/* Server OID - used to verify both sides of join use same server */
	Oid			serverid;

	/* 
	 * For join relations, these point to the component relations.
	 * For base relations, these are NULL.
	 */
	RelOptInfo *outerrel;
	RelOptInfo *innerrel;

	/* Join type (INNER, LEFT, etc.) */
	JoinType	jointype;

	/* 
	 * Join conditions that can be pushed down to the remote server.
	 * These are extracted from the join's restrictlist.
	 */
	List	   *joinclauses;

	/*
	 * Relids of base relations that are part of this join relation.
	 * Used for identifying Vars during deparsing.
	 */
	Relids		lower_rels;
#endif /* PG_VERSION_NUM >= 90500 */
} TdsFdwRelationInfo;

/* this maintains state */

typedef struct TdsFdwExecutionState
{
	LOGINREC *login;
	DBPROCESS *dbproc;
	AttInMetadata *attinmeta;
	char *query;
	List *retrieved_attrs;
	int first;
	COL *columns;
	Datum *datums;
	bool *isnull;
	int ncols;
	int row;
	MemoryContext mem_cxt;
	bool is_join_scan;		/* True if this is a join scan */
	Oid serverid;			/* Server OID for join scans */
} TdsFdwExecutionState;

/* Callback argument for ec_member_matches_foreign */
typedef struct
{
	Expr	   *current;		/* current expr, or NULL if not yet found */
	List	   *already_used;	/* expressions already dealt with */
} ec_member_foreign_arg;

/* functions called via SQL */

extern Datum tds_fdw_handler(PG_FUNCTION_ARGS);
extern Datum tds_fdw_validator(PG_FUNCTION_ARGS);

/* FDW callback routines */

void tdsExplainForeignScan(ForeignScanState *node, ExplainState *es);
void tdsBeginForeignScan(ForeignScanState *node, int eflags);
TupleTableSlot* tdsIterateForeignScan(ForeignScanState *node);
void tdsReScanForeignScan(ForeignScanState *node);
void tdsEndForeignScan(ForeignScanState *node);

/* routines for 9.2.0+ */
#if (PG_VERSION_NUM >= 90200)
void tdsGetForeignRelSize(PlannerInfo *root, RelOptInfo *baserel, Oid foreigntableid);
void tdsEstimateCosts(PlannerInfo *root, RelOptInfo *baserel, Cost *startup_cost, Cost *total_cost, Oid foreigntableid);
void tdsGetForeignPaths(PlannerInfo *root, RelOptInfo *baserel, Oid foreigntableid);
bool tdsAnalyzeForeignTable(Relation relation, AcquireSampleRowsFunc *func, BlockNumber *totalpages);
#if (PG_VERSION_NUM >= 90500)
ForeignScan* tdsGetForeignPlan(PlannerInfo *root, RelOptInfo *baserel, Oid foreigntableid, ForeignPath *best_path, List *tlist, List *scan_clauses, Plan *outer_plan);
void tdsGetForeignJoinPaths(PlannerInfo *root, RelOptInfo *joinrel,
							RelOptInfo *outerrel, RelOptInfo *innerrel,
							JoinType jointype, JoinPathExtraData *extra);
#else
ForeignScan* tdsGetForeignPlan(PlannerInfo *root, RelOptInfo *baserel, Oid foreigntableid, ForeignPath *best_path, List *tlist, List *scan_clauses);
#endif
/* routines for versions older than 9.2.0 */
#else
FdwPlan* tdsPlanForeignScan(Oid foreigntableid, PlannerInfo *root, RelOptInfo *baserel);
#endif

#ifdef IMPORT_API
List *tdsImportForeignSchema(ImportForeignSchemaStmt *stmt, Oid serverOid);
#endif  /* IMPORT_API */

/* compatibility with PostgreSQL 9.6+ */
#ifndef ALLOCSET_DEFAULT_SIZES
#define ALLOCSET_DEFAULT_SIZES \
ALLOCSET_DEFAULT_MINSIZE, ALLOCSET_DEFAULT_INITSIZE, ALLOCSET_DEFAULT_MAXSIZE
#endif

/* compatibility with PostgreSQL v11+ */
#if PG_VERSION_NUM < 110000
/* new in v11 */
#define TupleDescAttr(tupdesc, i) ((tupdesc)->attrs[(i)])
#else
/* removed in v11 */
#define get_relid_attribute_name(relid, varattno) get_attname((relid), (varattno), false)
#endif

/* Helper functions */

bool is_builtin(Oid objectId);
Expr * find_em_expr_for_rel(EquivalenceClass *ec, RelOptInfo *rel);
bool is_shippable(Oid objectId, Oid classId, TdsFdwRelationInfo *fpinfo);
void tdsBuildForeignQuery(PlannerInfo *root, RelOptInfo *baserel, TdsFdwOptionSet* option_set,
	Bitmapset* attrs_used, List** retrieved_attrs, 
	List* remote_conds, List* remote_join_conds, List* pathkeys);

/* JOIN pushdown helper functions (PostgreSQL 9.5+) */
#if (PG_VERSION_NUM >= 90500)
Oid tdsGetForeignServerIdFromRelation(PlannerInfo *root, RelOptInfo *rel);
bool tdsIsForeignRelation(PlannerInfo *root, RelOptInfo *rel);
void tdsGetForeignJoinRelSize(PlannerInfo *root, RelOptInfo *joinrel,
							  RelOptInfo *outerrel, RelOptInfo *innerrel,
							  JoinType jointype);
#endif /* PG_VERSION_NUM >= 90500 */
int tdsSetupConnection(TdsFdwOptionSet* option_set, LOGINREC *login, DBPROCESS **dbproc);
double tdsGetRowCount(TdsFdwOptionSet* option_set, LOGINREC *login, DBPROCESS *dbproc);
double tdsGetRowCountShowPlanAll(TdsFdwOptionSet* option_set, LOGINREC *login, DBPROCESS *dbproc);
double tdsGetRowCountExecute(TdsFdwOptionSet* option_set, LOGINREC *login, DBPROCESS *dbproc);
double tdsGetStartupCost(TdsFdwOptionSet* option_set);
void tdsGetColumnMetadata(ForeignScanState *node, TdsFdwOptionSet *option_set, bool is_join_scan);
char* tdsConvertToCString(DBPROCESS* dbproc, int srctype, const BYTE* src, DBINT srclen);
#if (PG_VERSION_NUM >= 90400)
int tdsDatetimeToDatum(DBPROCESS *dbproc, DBDATETIME *src, Datum *datetime_out);
#endif

/* Helper functions for DB-Library API */

int tds_err_handler(DBPROCESS *dbproc, int severity, int dberr, int oserr, char *dberrstr, char *oserrstr);
int tds_notice_msg_handler(DBPROCESS *dbproc, DBINT msgno, int msgstate, int severity, char *msgtext, char *svr_name, char *proc_name, int line);
int tds_blackhole_msg_handler(DBPROCESS *dbproc, DBINT msgno, int msgstate, int severity, char *msgtext, char *svr_name, char *proc_name, int line);

#endif
