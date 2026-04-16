"""Extract silver-layer data from Fabric Lakehouse SQL analytics endpoint to CSV files.

Requires:
  - ODBC Driver 18 for SQL Server
  - pyodbc
  - Environment variables: AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID
"""
import csv
import json
import os
import struct
import sys
import urllib.parse
import urllib.request


SERVER = "kewrblglvpbunj4xl6fj3enicm-nbqkmhcyvveuhdiaygrq4xkq6q.datawarehouse.fabric.microsoft.com"
DATABASE = "pp_inventory"
TABLES = ["silver_environments", "silver_resources", "silver_governance_signals"]
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "sources", "pp_inventory")


def get_access_token(tenant_id: str, client_id: str, client_secret: str) -> str:
    data = (
        f"grant_type=client_credentials"
        f"&client_id={client_id}"
        f"&client_secret={urllib.parse.quote(client_secret)}"
        f"&scope=https://database.windows.net/.default"
    )
    req = urllib.request.Request(
        f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token",
        data=data.encode(),
        method="POST",
    )
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    resp = json.loads(urllib.request.urlopen(req).read())
    return resp["access_token"]


def connect(token: str):
    import pyodbc

    token_bytes = token.encode("UTF-16-LE")
    token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)
    conn_str = f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={SERVER};DATABASE={DATABASE};"
    return pyodbc.connect(conn_str, attrs_before={1256: token_struct})


def extract_table(conn, table: str, output_dir: str) -> int:
    cursor = conn.cursor()
    cursor.execute(f"SELECT * FROM {table}")
    cols = [desc[0] for desc in cursor.description]
    rows = cursor.fetchall()

    path = os.path.join(output_dir, f"{table}.csv")
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(cols)
        for row in rows:
            writer.writerow([str(v) if v is not None else "" for v in row])

    return len(rows)


def main():
    tenant_id = os.environ.get("AZURE_TENANT_ID")
    client_id = os.environ.get("AZURE_CLIENT_ID")
    client_secret = os.environ.get("AZURE_CLIENT_SECRET")

    if not all([tenant_id, client_id, client_secret]):
        print("ERROR: Set AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID", file=sys.stderr)
        sys.exit(1)

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("Acquiring access token...")
    token = get_access_token(tenant_id, client_id, client_secret)
    print(f"Token acquired (length: {len(token)})")

    print(f"Connecting to {SERVER}...")
    conn = connect(token)
    print("Connected!")

    for table in TABLES:
        count = extract_table(conn, table, OUTPUT_DIR)
        print(f"  {table}: {count} rows → {table}.csv")

    conn.close()
    print("Done!")


if __name__ == "__main__":
    main()
