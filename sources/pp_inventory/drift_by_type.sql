select 'Flows'  as resource_type,
       CAST(sum(inv_flow_count)  AS INT) as native_count,
       CAST(sum(coe_flow_count)  AS INT) as coe_count,
       CAST(sum(flow_delta)      AS INT) as delta
from silver_environments
union all
select 'Apps',
       CAST(sum(inv_app_count)   AS INT),
       CAST(sum(coe_app_count)   AS INT),
       CAST(sum(app_delta)       AS INT)
from silver_environments
union all
select 'Agents',
       CAST(sum(inv_agent_count) AS INT),
       CAST(sum(coe_agent_count) AS INT),
       CAST(sum(agent_delta)     AS INT)
from silver_environments
