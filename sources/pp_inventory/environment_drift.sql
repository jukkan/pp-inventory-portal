select
  environment_name,
  environment_type,
  inv_flow_count,
  coe_flow_count,
  flow_delta,
  inv_app_count,
  coe_app_count,
  app_delta,
  inv_agent_count,
  coe_agent_count,
  agent_delta,
  abs(flow_delta) + abs(app_delta) + abs(agent_delta) as total_drift,
  has_delta
from silver_environments
order by (abs(flow_delta) + abs(app_delta) + abs(agent_delta)) desc
