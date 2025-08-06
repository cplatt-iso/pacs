# Brit PACS Containerized Deployment

This directory contains the necessary files to build and deploy an **InsiteOne PACS system** in a Docker container using the Brit PACS software package.

## Overview

The InsiteOne PACS (Picture Archiving and Communication System) is a medical imaging management system that provides storage, retrieval, and distribution of medical images and associated data. This containerized deployment makes it easy to run a PACS system for development, testing, or production use.

## Files in this Directory

- **`Dockerfile`** - Defines the container image build process for the Brit PACS system
- **`docker-compose.yml`** - Orchestrates the PACS container with proper networking and volume configuration

## Files you will also need when you build but are not in this directory

- **`brit-works_6.5.0-07f_amd64.deb`** - The InsiteOne PACS software package (Debian package)
- Place in local directory when building.  Modify script if using other versions.

## Prerequisites

Before building and running the PACS system, ensure you have:

1. **Docker** installed and running
2. **Docker Compose** installed
3. The Brit PACS Debian package (`brit-works_6.5.0-07f_amd64.deb`) in this directory
4. Access to the `axiom_shared_network` Docker network (created by other components)

## Quick Notes

Depending on your envrionment, the "docker-compose" command may be "docker compose" - adjust as necessary.

## Quick Start

### 1. Build the PACS Container

```bash
cd /path/to/infra/brit
docker-compose build
```

### 2. Start the PACS System

```bash
docker-compose up -d
```

### 3. Access the PACS Web Interface

Once the container is running, you can access the PACS web interface at:

```
http://localhost:8081
```

**Default Credentials:**
- Username: `admin` (or check Brit documentation for default credentials)
- Password: ask an InsiteOne representative.

## Container Architecture

### Base System
- **Base Image:** Ubuntu 22.04
- **Java Runtime:** OpenJDK 8 (required for Brit PACS)
- **User Account:** `pacs` user with home directory at `/opt/pacs`

### Security Features
- Self-signed SSL certificate automatically generated
- Dedicated `pacs` user with restricted permissions
- Proper file ownership and permissions

### Data Persistence
The following directories are mounted as Docker volumes for data persistence:

- **`brit-db`** → `/opt/pacs/db` - Database files
- **`brit-logs`** → `/opt/pacs/logs` - Application logs
- **`brit-store`** → `/opt/pacs/store` - DICOM image storage
- **`brit-transactions`** → `/opt/pacs/transactions` - Transaction logs

You can edit the docker-compose file to remap volumes to accessible filesystems on the host.

### Network Configuration
- **Port 8081** (host) → Port 80 (container) - Web UI access - note that you will want to map other ports externally, specifically 9080 and 9443 if you do not use a reverse proxy.
- **Internal Ports:** 443, 3200, 3222, 3280, 3300, 9080, 9082, 9443
- **Networks:** Connected to `axiom_shared_network` and `npm_web` in this example.  **Adjust as necessary.**  This system was tested behind an nginx proxy manager (NPM) reverse proxy and used in an environment with other containers facilitating scheduled workflow (hl7/dicom).

## Detailed Setup Instructions

### Step 1: Prepare the Environment

1. Ensure the PACS Debian package is in this directory:
   ```bash
   ls -la brit-works_6.5.0-07f_amd64.deb
   ```

2. Create the shared network if it doesn't exist:
   ```bash
   docker network create axiom_shared_network
   ```

### Step 2: Build the Container Image

The Dockerfile performs the following operations:

1. **System Setup:**
   - Installs Java 8 and required dependencies
   - Creates the `pacs` user and directory structure
   - Installs the Brit PACS Debian package

2. **Security Configuration:**
   - Generates a self-signed SSL certificate
   - Sets proper file permissions and ownership

3. **Service Configuration:**
   - Configures the PACS service for container execution
   - Sets up Java runtime parameters optimized for PACS workloads

Build the image:
```bash
docker-compose build --no-cache
```

### Step 3: Start the PACS System

Start the container in detached mode:
```bash
docker-compose up -d
```

Monitor the startup process:
```bash
docker-compose logs -f brit-works
```

### Step 4: Verify Installation

1. **Check container status:**
   ```bash
   docker-compose ps
   ```

2. **Check PACS logs:**
   ```bash
   docker-compose logs brit-works
   ```

3. **Access web interface:**
   - If using local host for build -
   - Open browser to `http://localhost:9080` **you will need to map 9080/9443 in docker-compose if you dont use a reverse proxy**
   - Look for the Brit PACS login page

## Configuration

### Java Memory Settings
The container is configured with optimized Java settings for PACS workloads:
- Initial heap: 1GB (`-Xms1g`)
- Maximum heap: 1GB (`-Xmx1g`)
- G1 garbage collector for low-latency performance
- Detailed GC logging for monitoring

### DICOM Configuration
The PACS system listens on standard DICOM ports:
**This was AI generated and probably wrong, 3200 does work for DICOM**
- **Port 3200** - DICOM C-STORE operations
- **Port 3222** - DICOM query/retrieve
- **Port 3280** - DICOM modality worklist
- **Port 3300** - HL7 MLLP

## Troubleshooting

### Common Issues

1. **Container fails to start:**
   ```bash
   # Check logs for detailed error messages
   docker-compose logs brit-works
   
   # Verify the Debian package exists and is valid
   ls -la brit-works_6.5.0-07f_amd64.deb
   ```

2. **Web interface not accessible:**
   ```bash
   # Verify port mapping
   docker-compose ps
   
   # Check if container is running
   docker-compose up -d
   ```

3. **SSL certificate issues:**
   ```bash
   # Rebuild container to regenerate certificate
   docker-compose down
   docker-compose build --no-cache
   docker-compose up -d
   ```

4. **Permission issues:**
   ```bash
   # Check volume permissions
   docker-compose exec brit-works ls -la /opt/pacs/
   ```

### Viewing Logs

- **Application logs:** `docker-compose logs brit-works`
- **Java memory logs:** `docker-compose exec brit-works tail -f /opt/pacs/logs/memory.log`
- **System logs:** `docker-compose exec brit-works journalctl -f`

## Integration with Other Systems

This PACS container is designed to work with other components in the axiom infrastructure:

- **HL7 Yeeter:** Sends DICOM studies to this PACS for storage and validation
- **Database systems:** Can query and retrieve studies for processing
- **Web interfaces:** Accessible through the shared network configuration

## Data Backup

To backup PACS data:

```bash
# Stop the container
docker-compose down

# Backup volumes
docker run --rm -v brit-db:/source -v $(pwd):/backup alpine tar czf /backup/brit-db-backup.tar.gz -C /source .
docker run --rm -v brit-store:/source -v $(pwd):/backup alpine tar czf /backup/brit-store-backup.tar.gz -C /source .

# Restart the container
docker-compose up -d
```

## Maintenance

### Regular Maintenance Tasks

1. **Monitor disk usage:**
   ```bash
   docker system df
   docker-compose exec brit-works df -h /opt/pacs/
   ```

2. **Clean up old logs:**
   ```bash
   docker-compose exec brit-works find /opt/pacs/logs -name "*.log" -mtime +30 -delete
   ```

3. **Update the system:**
   ```bash
   docker-compose down
   docker-compose build --no-cache
   docker-compose up -d
   ```

## Security Considerations

- The container runs with a dedicated `pacs` user account
- SSL certificate is automatically generated for secure communications
- Internal ports are not exposed to the host system
- Data is persisted in Docker volumes with proper permissions

## Support and Documentation

For additional information about the Brit PACS system:
- Refer to the official Brit Systems documentation
- Check the application logs for detailed error messages
- Contact your PACS administrator for configuration-specific issues

---

**Note:** This containerized deployment is configured for development and testing environments. For production use, additional security hardening and configuration may be required.
