# n8n-infra

A complete self-hosted infrastructure for n8n automation platform with monitoring, backup, and high availability features.

## Overview

n8n-infra provides a production-ready setup for running n8n with all necessary supporting services:

- **n8n**: Workflow automation platform
- **PostgreSQL**: Database with automated backups
- **Qdrant**: Vector database for AI/ML features
- **Traefik**: Reverse proxy with automatic SSL
- **Monitoring**: Prometheus, Grafana, and health checks
- **Auto-healing**: Automatic container recovery

## Features

- **Secure**: All services run with security best practices
- **Auto-healing**: Automatic container recovery
- **Monitoring**: Comprehensive monitoring with Prometheus and Grafana
- **Backup**: Automated database backups
- **SSL**: Automatic SSL certificates with Traefik
- **Production-ready**: Optimized for production use

## Prerequisites

- Docker and Docker Compose
- A domain name with DNS access
- Basic understanding of Docker and n8n

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/coyls/n8n-infra.git
   cd n8n-infra
   ```

2. Copy the example environment files:
   ```bash
   cp n8n/.env.example n8n/.env
   cp postgres/.env.example postgres/.env
   cp qdrant/.env.example qdrant/.env
   ```

3. Configure your environment variables in the `.env` files

4. Start the infrastructure:
   ```bash
   ./n8n-infra-start.sh
   ```

## Directory Structure

```
n8n-infra/
├── n8n/               # n8n service configuration
├── postgres/          # PostgreSQL database configuration
├── qdrant/            # Vector database configuration
├── traefik/           # Reverse proxy configuration
├── monitoring/        # Monitoring stack configuration
├── n8n-infra-start.sh # Infrastructure startup script
└── update-n8n.sh      # n8n update script
```

## Services

### n8n
- Access: `https://n8n.yourdomain.com`
- Features: Workflow automation, webhooks, API access

### PostgreSQL
- Access: Internal network only
- Features: Automated daily backups, Adminer interface

### Qdrant
- Access: Internal network only
- Features: Vector database for AI/ML features

### Monitoring
> ⚠️ **Warning**: The monitoring configuration is currently incomplete and under development. Some features may not be fully functional.

- Prometheus: Internal metrics collection
- Grafana: `https://grafana.yourdomain.com`
- Node Exporter: System metrics
- cAdvisor: Container metrics

## Maintenance

### Updating n8n
```bash
./update-n8n.sh
```

### Automation
The update script can be automated using a cron job. Here's an example configuration to run updates daily:

```bash
# Add this line to your crontab (crontab -e)
0 3 * * * /path/to/n8n-infra/update-n8n.sh
```

The script handles its own logging with timestamps and different log levels.

### Backups
> ⚠️ **Warning**: The backup configuration is currently incomplete and under development. Some features may not be fully functional.

- PostgreSQL: Daily automated backups
- n8n: Manual backup through the interface

### Monitoring
- Access Grafana at `https://grafana.yourdomain.com`
- Default credentials in `.env` file

## Security

- All services run with minimal privileges
- Automatic SSL certificates
- Network isolation between services
- Regular security updates

## Important Notice

This infrastructure is provided "AS IS" without any warranty. By using this software, you agree to the following:

1. **Disclaimer**: This is a personal project for learning and experimentation. The author provides no guarantees regarding its functionality or suitability for any purpose.

2. **Responsibility**: Users are responsible for their own setup, maintenance, and troubleshooting.

3. **Modifications**: If you modify this infrastructure, you must share your modifications under the same GPL v2.0 license.

## License

This project is licensed under the GNU General Public License v2.0. See the [LICENSE](LICENSE) file for full details.

## Contributing

Hey! I'm still learning and would love to hear your thoughts! If you have any suggestions to make this better or spot something that could be improved:
- Feel free to open an issue to chat about it
- If you want to help out, pull requests are welcome
- Your feedback and experiences would be super helpful
