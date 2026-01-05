# Build-and-Deploy-Dockerized-Application
# Spring PetClinic CI/CD Pipeline

## Overview

This repository contains a GitHub Actions workflow that automates the build, containerization, and deployment of the Spring PetClinic application. The pipeline builds a JAR file using Maven, packages it into a Docker image, and deploys it to a remote server.

## Workflow Architecture

```
┌─────────────────┐
│  Push to main   │
│       or        │
│ Manual trigger  │
└────────┬────────┘
         │
         v
┌─────────────────────────────────────┐
│          BUILD JOB                  │
├─────────────────────────────────────┤
│ 1. Checkout code                    │
│ 2. Set up Java 11                   │
│ 3. Build with Maven                 │
│ 4. Create Docker image tag          │
│ 5. Build Docker image               │
│ 6. Save image as artifact           │
└────────┬────────────────────────────┘
         │
         v
┌─────────────────────────────────────┐
│         DEPLOY JOB                  │
├─────────────────────────────────────┤
│ 1. Download Docker image artifact   │
│ 2. Copy image to remote server      │
│ 3. Load image on server             │
│ 4. Stop old container               │
│ 5. Run new container                │
└─────────────────────────────────────┘
```

## Features

- **Automated Build**: Compiles Spring Boot application using Maven
- **Dynamic Tagging**: Creates unique Docker image tags based on branch name and commit SHA
- **Artifact Storage**: Stores Docker images as GitHub Actions artifacts
- **Remote Deployment**: Automatically deploys to production server via SSH/SCP
- **Zero-Downtime**: Replaces old container with new one
- **Manual Trigger**: Supports workflow_dispatch for on-demand deployments

## Prerequisites

### Repository Requirements

1. **Dockerfile**: Your repository must contain a `Dockerfile` at the root level
2. **Maven Project**: Application must be a valid Maven project with `pom.xml`
3. **Java Version**: Application must be compatible with Java 11

### Server Requirements

1. **Docker Installation**: Docker must be installed and running on the target server
2. **SSH Access**: Server must allow SSH connections
3. **Port Availability**: Port 8080 must be available for the application
4. **Deploy Directory**: Target deployment directory must exist and be writable

## Configuration

### Required GitHub Secrets

Navigate to **Settings → Secrets and variables → Actions** and add the following secrets:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `SERVER_HOST` | IP address or hostname of deployment server | `192.168.1.100` or `example.com` |
| `SERVER_USER` | SSH username for server access | `ubuntu` or `deploy` |
| `SERVER_PASSWORD` | SSH password for authentication | `your-secure-password` |
| `SERVER_PORT` | SSH port number | `22` |
| `SERVER_DEPLOY_PATH` | Absolute path to deployment directory | `/home/ubuntu/deploy` |

### Security Best Practices

⚠️ **Important**: Using password authentication is not recommended for production environments.

**Recommended Alternative**: Use SSH key-based authentication

1. Generate an SSH key pair on your local machine:
   ```bash
   ssh-keygen -t ed25519 -C "github-actions-deploy"
   ```

2. Add the public key to the server's `~/.ssh/authorized_keys`

3. Store the private key in GitHub Secrets as `SERVER_SSH_KEY`

4. Modify the workflow to use `key` instead of `password`:
   ```yaml
   - name: Copy Docker image to server
     uses: appleboy/scp-action@v0.1.5
     with:
       host: ${{ secrets.SERVER_HOST }}
       username: ${{ secrets.SERVER_USER }}
       key: ${{ secrets.SERVER_SSH_KEY }}
       port: ${{ secrets.SERVER_PORT }}
       source: "spring-petclinic.tar"
       target: ${{ secrets.SERVER_DEPLOY_PATH }}
   ```

## Workflow Triggers

### Automatic Trigger

The workflow runs automatically on every push to the `main` branch:

```bash
git push origin main
```

### Manual Trigger

To manually trigger the workflow:

1. Go to **Actions** tab in your GitHub repository
2. Select **Build and Deploy Dockerized JAR - PetClinic**
3. Click **Run workflow**
4. Select the branch and click **Run workflow**

## Docker Image Tagging Strategy

Images are tagged using the format: `<branch-name>-<short-commit-sha>`

**Examples**:
- Push to `main` branch with commit `a1b2c3d4`: `main-a1b2c3d4`
- Push to `feature/auth` branch with commit `e5f6g7h8`: `feature-auth-e5f6g7h8`

This ensures:
- Unique identification of each build
- Easy traceability to source code
- Support for multiple branches

## Workflow Jobs

### Build Job

**Purpose**: Compile application and create Docker image

**Steps**:
1. **Checkout code**: Retrieves source code from repository
2. **Set up Java**: Installs Java 11 (Microsoft distribution)
3. **Build with Maven**: Compiles application and creates JAR file (skips tests)
4. **Set Docker image tag**: Creates unique tag from branch name and commit SHA
5. **Build Docker image**: Packages JAR into Docker image
6. **Save Docker image**: Exports image to TAR file
7. **Upload artifact**: Stores TAR file for deployment job

**Outputs**:
- `image_tag`: The generated Docker image tag (passed to deploy job)

### Deploy Job

**Purpose**: Deploy Docker image to production server

**Steps**:
1. **Download artifact**: Retrieves Docker image TAR file
2. **Copy to server**: Transfers TAR file to remote server via SCP
3. **Load and run**: SSH into server, load image, stop old container, start new one

**Environment**: Production (requires approval if configured)

## Deployment Process

When the workflow runs, the following happens on your server:

```bash
# 1. Docker image is loaded from TAR file
docker load -i spring-petclinic.tar

# 2. Old container is stopped and removed (if exists)
docker rm -f spring-petclinic

# 3. New container is started
docker run -d --name spring-petclinic -p 8080:8080 spring-petclinic:main-a1b2c3d4
```

## Accessing the Application

After successful deployment, access the application at:

```
http://<SERVER_HOST>:8080
```

For example: `http://192.168.1.100:8080`

## Troubleshooting

### Build Failures

**Maven build fails**:
```bash
# Check logs in GitHub Actions
# Common issues:
- Missing dependencies
- Compilation errors
- Incorrect Java version
```

**Solution**: Review the build logs and fix code issues

### Docker Build Failures

**Dockerfile errors**:
```bash
# Ensure Dockerfile exists and is valid
# Check that JAR file path matches Dockerfile expectations
```

**Solution**: Verify Dockerfile syntax and JAR file location

### Deployment Failures

**Connection refused**:
```
Error: ssh: connect to host X.X.X.X port 22: Connection refused
```

**Solutions**:
- Verify `SERVER_HOST` and `SERVER_PORT` are correct
- Ensure server firewall allows SSH connections
- Check that SSH service is running: `sudo systemctl status ssh`

**Permission denied**:
```
Error: Permission denied (publickey,password)
```

**Solutions**:
- Verify `SERVER_USER` and `SERVER_PASSWORD` are correct
- Check SSH server configuration allows password authentication
- Consider switching to SSH key authentication

**Docker not found**:
```
Error: docker: command not found
```

**Solution**: Install Docker on the server:
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

**Port already in use**:
```
Error: bind: address already in use
```

**Solution**: Stop the process using port 8080:
```bash
# Find process
sudo lsof -i :8080

# Kill process
sudo kill -9 <PID>

# Or change the port in the workflow
docker run -d --name spring-petclinic -p 9090:8080 spring-petclinic:${IMAGE_TAG}
```

## Monitoring

### Check Container Status

SSH into your server and run:

```bash
# View running containers
docker ps

# Check container logs
docker logs spring-petclinic

# Follow logs in real-time
docker logs -f spring-petclinic
```

### Check Application Health

```bash
# Test if application is responding
curl http://localhost:8080

# Check specific endpoint
curl http://localhost:8080/actuator/health
```

## Maintenance

### Cleanup Old Images

Docker images accumulate over time. Clean up periodically:

```bash
# Remove unused images
docker image prune -a

# Remove stopped containers
docker container prune
```

### Rollback to Previous Version

If a deployment fails, rollback to a previous image:

```bash
# List available images
docker images | grep spring-petclinic

# Stop current container
docker rm -f spring-petclinic

# Run previous version
docker run -d --name spring-petclinic -p 8080:8080 spring-petclinic:main-<previous-sha>
```

## Environment Protection (Optional)

To add deployment approval:

1. Go to **Settings → Environments**
2. Click **New environment**
3. Name it **Production**
4. Enable **Required reviewers**
5. Add team members who can approve deployments

The workflow will pause before deployment and require approval.

## Customization

### Skip Tests During Build

Currently configured to skip tests for faster builds:

```yaml
run: mvn clean package -DskipTests
```

To run tests, change to:

```yaml
run: mvn clean package
```

### Change Application Port

To run on a different port:

```yaml
docker run -d --name spring-petclinic -p 9090:8080 spring-petclinic:${IMAGE_TAG}
```

Application will be accessible at `http://<SERVER_HOST>:9090`

### Add Environment Variables

To pass environment variables to the container:

```yaml
docker run -d --name spring-petclinic \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=prod \
  -e DATABASE_URL=${{ secrets.DATABASE_URL }} \
  spring-petclinic:${IMAGE_TAG}
```

### Multiple Environments

To deploy to staging and production:

1. Create separate jobs for each environment
2. Use different secrets for each (e.g., `STAGING_SERVER_HOST`, `PROD_SERVER_HOST`)
3. Add environment protection rules

## Performance Considerations

### Build Time

- **Typical build time**: 3-5 minutes
- **Factors**: Maven dependencies, Docker layer caching, network speed

### Artifact Size

- **Docker image size**: Typically 150-300 MB for Spring Boot applications
- **Transfer time**: Depends on network bandwidth between GitHub and your server

### Optimization Tips

1. **Use multi-stage Docker builds** to reduce image size
2. **Cache Maven dependencies** in GitHub Actions
3. **Use Docker layer caching** for faster builds

## Contributing

To improve this workflow:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This workflow configuration is provided as-is for use with the Spring PetClinic application.

## Support

For issues or questions:

- **GitHub Actions**: Check the Actions tab for workflow runs and logs
- **Spring PetClinic**: Visit the [official repository](https://github.com/spring-projects/spring-petclinic)
- **Docker**: Consult [Docker documentation](https://docs.docker.com)

## Version History

- **v1.0**: Initial release with basic build and deploy functionality
- Uses actions/checkout@v4
- Uses actions/setup-java@v4
- Uses appleboy/scp-action@v0.1.5
- Uses appleboy/ssh-action@v1
