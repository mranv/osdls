#!/bin/bash

echo "Waiting for OpenSearch to be ready..."
until curl -s -k https://localhost:9200 -u admin:${OPENSEARCH_INITIAL_ADMIN_PASSWORD} | grep -q "You Know, for Search"
do
    sleep 5
done

echo "OpenSearch is ready. Configuring..."

# Download Wazuh template
curl -o logstash/templates/wazuh.json https://packages.wazuh.com/integrations/opensearch/4.x-2.x/dashboards/wz-os-4.x-2.x-template.json

# Create Wazuh index pattern
curl -k -X POST "https://localhost:9200/_plugins/_index_management/api/index_templates/wazuh" -H 'Content-Type: application/json' -u admin:${OPENSEARCH_INITIAL_ADMIN_PASSWORD} -d @logstash/templates/wazuh.json

echo "OpenSearch configuration complete."
echo "Please manually import Wazuh dashboards in OpenSearch Dashboards."