select 'Flows'  as resource_type,
       sum(inv_flow_count)  as native_count,
       sum(coe_flow_count)  as coe_count,
       sum(flow_delta)      as delta
from silver_environments
union all
select 'Apps',
       sum(inv_app_count),
       sum(coe_app_count),
       sum(app_delta)
from silver_environments
union all
select 'Agents',
       sum(inv_agent_count),
       sum(coe_agent_count),
       sum(agent_delta)
from silver_environments
