<h1 align="center">
<br>
<img src=assets/osdls.png >
<br>
<strong>os / osd + logstash + wazuh</strong>
</h1>


This project provides a seamless integration between Wazuh, a free and open-source security platform, and OpenSearch, a community-driven, open-source search and analytics suite. This integration allows for efficient log management, security event analysis, and real-time monitoring of your infrastructure.

The setup includes:
- Wazuh manager for security event collection and analysis
- OpenSearch cluster for powerful search and analytics capabilities
- OpenSearch Dashboards for visualization and data exploration
- Logstash for data processing and ingestion into OpenSearch

## Features

- Custom Docker image combining Wazuh and Logstash for simplified deployment
- Two-node OpenSearch cluster for high availability
- Automated setup process with environment validation
- Centralized configuration management
- Scalable architecture suitable for production environments

## Prerequisites

- Docker (version 19.03 or later)
- Docker Compose (version 1.27 or later)
- Git
- Bash shell
- At least 4GB of RAM available for the containers

## Quick Start

1. Clone the repository:
   ```
   git clone https://github.com/anubhavg-icpl/osdls.git
   cd osdls
   ```

2. Create a `.env` file in the project root with the following content:
   ```
   OPENSEARCH_INITIAL_ADMIN_PASSWORD=your_secure_password
   OPENSEARCH_PASSWORD=your_secure_password
   OPENSEARCH_USERNAME=admin
   LOGSTASH_KEYSTORE_PASS=your_secure_password
   ```
   Replace `your_secure_password` with strong, unique passwords.

3. Run the setup script:
   ```
   chmod +x setup.sh
   ./setup.sh
   ```

4. Once the setup is complete, access OpenSearch Dashboards at `http://localhost:5601`.

## Detailed Setup

The `setup.sh` script performs the following actions:
1. Validates the environment and prerequisites
2. Builds a custom Docker image containing Wazuh and Logstash
3. Updates the `docker-compose.yml` file to use the custom image
4. Starts the services using Docker Compose

For manual setup or customization, refer to the individual component configurations in the `docker-compose.yml` file.

## Configuration

### Wazuh

Wazuh configuration files are located in the `wazuh-config` volume. To modify Wazuh settings:

1. Access the Wazuh container:
   ```
   docker exec -it wazuh /bin/bash
   ```
2. Edit the configuration files in `/var/ossec/etc/`.
3. Restart the Wazuh manager:
   ```
   supervisorctl restart wazuh-manager
   ```

### OpenSearch

OpenSearch settings can be adjusted in the `docker-compose.yml` file under the `opensearch-node1` and `opensearch-node2` services. For advanced configurations, refer to the [OpenSearch documentation](https://opensearch.org/docs/latest/).

### Logstash

Logstash configuration is located in `logstash/config/logstash.conf`. Modify this file to adjust data processing rules or add new input/output plugins.

## Usage

After setup, you can:
- Use Wazuh agents to collect security data from your infrastructure
- Search and analyze data using OpenSearch Dashboards
- Create custom dashboards and visualizations in OpenSearch Dashboards
- Set up alerts and notifications based on security events

## Troubleshooting

- If services fail to start, check the Docker logs:
  ```
  docker-compose logs
  ```
- Ensure all required ports are available and not in use by other services
- Verify that the passwords in the `.env` file meet the complexity requirements

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Wazuh](https://wazuh.com/)
- [OpenSearch](https://opensearch.org/)
- [Logstash](https://www.elastic.co/logstash/)

## Support

For support, please open an issue in the GitHub repository or contact the maintainers directly.
