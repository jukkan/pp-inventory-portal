CREATE TABLE silver_environments AS
SELECT * FROM read_csv_auto('sources/pp_inventory/silver_environments.csv');

CREATE TABLE silver_resources AS
SELECT * FROM read_csv_auto('sources/pp_inventory/silver_resources.csv');

CREATE TABLE silver_governance_signals AS
SELECT * FROM read_csv_auto('sources/pp_inventory/silver_governance_signals.csv');
