const {
	EvidenceType,
	TypeFidelity,
	asyncIterableToBatchedAsyncGenerator,
	cleanQuery,
	exhaustStream
} = require('@evidence-dev/db-commons');

/**
 * Map ODBC/SQL types to Evidence types based on column metadata from msnodesqlv8.
 */
function sqlTypeToEvidenceType(sqlType) {
	if (!sqlType) return EvidenceType.STRING;
	const t = sqlType.toLowerCase();
	if (t.includes('int') || t.includes('float') || t.includes('real') ||
		t.includes('decimal') || t.includes('numeric') || t.includes('money')) {
		return EvidenceType.NUMBER;
	}
	if (t.includes('bit')) return EvidenceType.BOOLEAN;
	if (t.includes('date') || t.includes('time')) return EvidenceType.DATE;
	return EvidenceType.STRING;
}

/**
 * Build an ODBC connection string for Fabric SQL analytics endpoint
 * using ODBC Driver 18 with ActiveDirectoryServicePrincipal auth.
 */
function buildConnectionString(opts) {
	const parts = [
		`Driver={ODBC Driver 18 for SQL Server}`,
		`Server=${opts.server}`,
		`Database=${opts.database}`,
		`Encrypt=yes`,
		`Authentication=ActiveDirectoryServicePrincipal`,
		`UID=${opts.clientid}`,
		`PWD=${opts.clientsecret}`
	];
	return parts.join(';');
}

/** @type {import("@evidence-dev/db-commons").RunQuery} */
const runQuery = async (queryString, database = {}, batchSize = 100000) => {
	const msnodesqlv8 = require('msnodesqlv8');
	const connStr = buildConnectionString(database);

	return new Promise((resolve, reject) => {
		msnodesqlv8.open(connStr, (err, conn) => {
			if (err) return reject(new Error(`Fabric connection failed: ${err.message || err}`));

			const cleaned = cleanQuery(queryString);
			conn.queryRaw(cleaned, (err, results) => {
				if (err) {
					conn.close(() => {});
					return reject(new Error(`Query failed: ${err.message || err}`));
				}

				const columnTypes = (results.meta || []).map(col => ({
					name: col.name,
					evidenceType: sqlTypeToEvidenceType(col.sqlType),
					typeFidelity: TypeFidelity.PRECISE
				}));

				const rows = (results.rows || []).map(row => {
					const obj = {};
					(results.meta || []).forEach((col, i) => {
						obj[col.name] = row[i];
					});
					return obj;
				});

				conn.close(() => {});

				resolve({
					rows: rows,
					columnTypes: columnTypes,
					expectedRowCount: rows.length
				});
			});
		});
	});
};

module.exports = runQuery;

/** @type {import("@evidence-dev/db-commons").GetRunner} */
module.exports.getRunner = async (opts) => {
	return async (queryContent, queryPath, batchSize) => {
		if (!queryPath.endsWith('.sql')) return null;
		return runQuery(queryContent, opts, batchSize);
	};
};

/** @type {import("@evidence-dev/db-commons").ConnectionTester} */
module.exports.testConnection = async (opts) => {
	try {
		await runQuery('SELECT 1 AS test', opts);
		return true;
	} catch (e) {
		return { reason: e.message };
	}
};

module.exports.options = {
	server: {
		title: 'Server',
		type: 'string',
		description: 'Fabric SQL analytics endpoint hostname',
		required: true
	},
	database: {
		title: 'Database',
		type: 'string',
		description: 'Lakehouse or Warehouse name',
		required: true
	},
	clientid: {
		title: 'Client ID',
		type: 'string',
		description: 'Service principal application (client) ID',
		secret: true,
		required: true
	},
	clientsecret: {
		title: 'Client Secret',
		type: 'string',
		description: 'Service principal client secret',
		secret: true,
		required: true
	}
};
