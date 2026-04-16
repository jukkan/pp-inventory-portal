# Architecture

This document explains how the PP Inventory Portal works, from data to deployed website.

## The big picture

The portal is a **static website** that displays governance data about a Power Platform tenant. "Static" means the site is plain HTML/CSS/JS files served from GitHub Pages — there is no server processing requests when someone visits the page.

The data comes from a **Microsoft Fabric Lakehouse**, which is a cloud database. SQL queries run against this database once at build time, and the results are baked into the HTML. The site never contacts the database when a visitor loads it.

```mermaid
graph LR
    A[Power Platform Tenant] -->|Inventory API| B[Fabric Lakehouse]
    B -->|SQL at build time| C[Evidence Build]
    C -->|Static HTML| D[GitHub Pages]
    D -->|HTTPS| E[inventory.jukkan.com]
```

## Data flow in detail

Data flows through three stages. Each stage runs independently — if one breaks, the others continue with the last good data.

```mermaid
flowchart TB
    subgraph stage1 ["Stage 1: Data Capture"]
        direction LR
        API[Power Platform\nInventory API]
        CoE[CoE Starter Kit\nDataverse tables]
        Scripts[Python scripts\n+ PAC CLI]
        API --> Scripts
        CoE --> Scripts
    end

    subgraph stage2 ["Stage 2: Storage & Transformation"]
        direction LR
        Bronze[Bronze tables\nraw JSON snapshots]
        Silver[Silver tables\ncleaned, typed, joined]
        Notebook[PySpark notebooks]
        Bronze --> Notebook --> Silver
    end

    subgraph stage3 ["Stage 3: Dashboard Build"]
        direction LR
        SQL[9 SQL queries]
        MD[5 Markdown pages]
        Build[Evidence build]
        HTML[Static HTML site]
        SQL --> Build
        MD --> Build
        Build --> HTML
    end

    Scripts -->|"upload to\nFabric Lakehouse"| Bronze
    Silver -->|"queried by"| SQL

    style stage1 fill:#1e293b,stroke:#475569,color:#e2e8f0
    style stage2 fill:#1e293b,stroke:#475569,color:#e2e8f0
    style stage3 fill:#1e293b,stroke:#475569,color:#e2e8f0
```

## How the build connects to Fabric

The trickiest part of this project is the database connection. Here's the chain:

```mermaid
flowchart LR
    subgraph runner ["GitHub Actions Runner (Ubuntu)"]
        Evidence[Evidence.dev]
        Connector[Custom Fabric\nConnector]
        msnode[msnodesqlv8\nnpm package]
        ODBC[ODBC Driver 18\nfor SQL Server]
        Evidence --> Connector --> msnode --> ODBC
    end

    subgraph azure ["Microsoft Cloud"]
        EntraID[Entra ID\ntoken service]
        Fabric[Fabric SQL\nanalytics endpoint]
    end

    ODBC -->|"1. Request token\n(service principal)"| EntraID
    EntraID -->|"2. Return access token"| ODBC
    ODBC -->|"3. TDS + token"| Fabric
    Fabric -->|"4. Query results"| ODBC

    style runner fill:#0f172a,stroke:#475569,color:#e2e8f0
    style azure fill:#172554,stroke:#3b82f6,color:#e2e8f0
```

**Why this chain exists:** Evidence normally uses a JavaScript library called `tedious` to talk to SQL Server. Tedious cannot connect to Fabric — it fails during the login handshake. So this project uses a custom connector that delegates to Microsoft's native ODBC driver instead, which handles Fabric authentication correctly.

## Authentication

```mermaid
sequenceDiagram
    participant GH as GitHub Actions
    participant EV as Evidence Build
    participant SP as Service Principal
    participant AD as Entra ID
    participant FB as Fabric Lakehouse

    GH->>EV: Start build (inject secrets)
    EV->>SP: Use client ID + secret
    SP->>AD: Request access token
    AD->>SP: Access token (scoped to Fabric)
    SP->>FB: SQL query + token
    FB->>SP: Query results
    SP->>EV: Rows & column types
    EV->>GH: Static HTML files
```

The service principal is an app registration in Microsoft Entra ID (formerly Azure AD). It has **Viewer** access to the Fabric workspace — read-only, it cannot modify data. Its credentials are stored as GitHub Actions secrets, never in code.

## Where things live

```mermaid
graph TB
    subgraph github ["GitHub"]
        Repo[jukkan/pp-inventory-portal\nSource code]
        Pages[GitHub Pages\ninventory.jukkan.com]
        Actions[GitHub Actions\nCI/CD pipeline]
        Secrets[Repository Secrets\nclient ID + secret]
    end

    subgraph fabric ["Microsoft Fabric"]
        Workspace[Fabric Workspace]
        Lakehouse[pp_inventory\nLakehouse]
        Tables["Silver tables\n• silver_environments\n• silver_resources\n• silver_governance_signals"]
    end

    subgraph entra ["Microsoft Entra ID"]
        App[App Registration\npp-inventory-portal-build]
    end

    Repo --> Actions
    Secrets --> Actions
    Actions -->|build| Pages
    Actions -->|SQL queries| Lakehouse
    App -->|authenticates to| Workspace
    Lakehouse --> Tables

    style github fill:#0f172a,stroke:#475569,color:#e2e8f0
    style fabric fill:#172554,stroke:#3b82f6,color:#e2e8f0
    style entra fill:#1e1b4b,stroke:#6366f1,color:#e2e8f0
```

## The connector explained

Evidence uses a plugin system for database connections. Each plugin is a small npm package that implements three functions:

| Function | Purpose |
|---|---|
| `runQuery(sql, options)` | Execute a SQL string and return rows + column types |
| `testConnection(options)` | Verify the connection works (used by Evidence CLI) |
| `getRunner(options)` | Return a function that runs `.sql` files one at a time |

The custom Fabric connector (`packages/fabric-connector/index.cjs`) implements these three functions using `msnodesqlv8`. It builds an ODBC connection string like:

```
Driver={ODBC Driver 18 for SQL Server};
Server=<fabric-endpoint>;
Database=pp_inventory;
Encrypt=yes;
Authentication=ActiveDirectoryServicePrincipal;
UID=<client-id>;
PWD=<client-secret>
```

The ODBC driver handles all the complexity: TLS negotiation, Entra ID token acquisition, TDS protocol framing. The connector just passes through the SQL and maps the results to Evidence's type system.

## Build pipeline

```mermaid
flowchart LR
    Push["git push\nto main"] --> Checkout
    
    subgraph ci ["GitHub Actions Workflow"]
        Checkout[Checkout\ncode] --> ODBC_Install["Install\nODBC Driver 18"]
        ODBC_Install --> NPM["npm ci\n(install deps)"]
        NPM --> Sources["npm run sources\n(9 SQL queries)"]
        Sources --> Build["npm run build\n(generate HTML)"]
        Build --> Deploy["Deploy to\ngh-pages branch"]
    end

    Deploy --> Live["inventory.jukkan.com\nupdated"]

    style ci fill:#0f172a,stroke:#475569,color:#e2e8f0
```

The workflow also runs on `workflow_dispatch`, so you can trigger a data refresh from the GitHub Actions UI without pushing a code change.
