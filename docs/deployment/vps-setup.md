# VPS Setup Guide for Realms Deployment

This guide walks through the one-time setup needed on a fresh VPS to enable automatic deployments from GitHub Actions.

## Prerequisites

- Fresh VPS with CentOS Stream 9 (or RHEL 9, Rocky Linux 9, AlmaLinux 9)
- Root or sudo access
- Domain name pointed to VPS IP address
- GitHub repository with Actions enabled

## Step 1: Install System Dependencies

```bash
# Update system packages
sudo dnf update -y

# Install development tools and dependencies
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y \
  vim \
  git \
  curl \
  wget \
  unzip \
  postgresql-server \
  postgresql-contrib \
  openssl \
  ncurses-devel

# Install Caddy
sudo dnf install -y dnf-plugins-core
sudo dnf copr enable -y @caddy/caddy
sudo dnf install -y caddy
```

## Step 2: Create Directory Structure

```bash
# Create application directories
sudo mkdir -p /opt/realms/app
sudo mkdir -p /etc/realms
sudo mkdir -p /var/log/realms

# Set ownership
sudo chown -R $USER:$USER /opt/realms
sudo chown -R $USER:$USER /var/log/realms
```

## Step 3: Install mise and Elixir/Erlang

The repository includes a `.tool-versions` file that specifies Elixir and Erlang versions. We'll use mise (modern asdf alternative) to install them.

```bash
# Install mise
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

# Clone the repository
cd /opt/realms
git clone https://github.com/doughsay/realms.git app
cd app

# Install Elixir and Erlang from .tool-versions
mise install

# Verify installation
elixir --version
```

## Step 4: Configure PostgreSQL

> **Note**: On CentOS, PostgreSQL needs to be initialized before first use.

```bash
# Initialize PostgreSQL database
sudo postgresql-setup --initdb

# Start and enable PostgreSQL service
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

Configure authentication by editing the pg_hba.conf file:

```bash
# Edit PostgreSQL authentication config
sudo vim /var/lib/pgsql/data/pg_hba.conf
```

Find the lines for local connections and change `ident` to `trust` for passwordless local authentication:

```
# Change from:
# host    all             all             127.0.0.1/32            ident
# host    all             all             ::1/128                 ident

# To:
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
```

Save and restart PostgreSQL:

```bash
sudo systemctl restart postgresql
```

Now create the database and user (no password needed):

```bash
# Switch to postgres user to create database
sudo -u postgres psql

# In PostgreSQL prompt, create database and user (no password):
CREATE USER realms;
CREATE DATABASE realms_prod OWNER realms;
GRANT ALL PRIVILEGES ON DATABASE realms_prod TO realms;
\q
```

Test the connection:

```bash
# Test connection (no password required)
psql -U realms -d realms_prod -h localhost
# Should connect without password prompt, then \q to exit
```

## Step 5: Create Environment File

Generate the secret key base:

```bash
cd /opt/realms/app
mix deps.get
mix phx.gen.secret
# Copy the output and paste it as SECRET_KEY_BASE in /etc/realms/env created below
```

Create the environment file with production configuration:

```bash
sudo vim /etc/realms/env
```

Add the following content (replace values as needed):

```bash
# Phoenix Configuration
PHX_SERVER=true
PHX_HOST=your-domain.com
PORT=4000
MIX_ENV=prod

# Database Configuration (no password needed with trust authentication)
DATABASE_URL=ecto://realms:@localhost/realms_prod
POOL_SIZE=10

# Security - Generate with: cd /opt/realms/app && mix phx.gen.secret
SECRET_KEY_BASE=REPLACE_WITH_GENERATED_SECRET
```

Set proper permissions:

```bash
sudo chmod 600 /etc/realms/env
sudo chown $USER:$USER /etc/realms/env
```

## Step 6: Test Deployment Script

The deployment script is located in the repository at `bin/deploy.sh` and is already executable.

> **Note**: The script must be run from within `/opt/realms/app` so mise can activate the correct Elixir/Erlang versions from `.tool-versions`. The script handles this automatically by changing to the app directory at startup.

Test it:

```bash
# Can be run from anywhere - the script will cd to the correct directory
/opt/realms/app/bin/deploy.sh

# Or run from within the app directory
cd /opt/realms/app
./bin/deploy.sh
```

## Step 7: Create Systemd Service

Copy the systemd service template:

```bash
sudo cp /opt/realms/app/docs/deployment/templates/systemd-service.template \
  /etc/systemd/system/realms.service
```

Edit the service file to replace placeholders:

```bash
sudo vim /etc/systemd/system/realms.service
```

Replace `YOUR_USERNAME` with your actual username. Save and exit.

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable realms
sudo systemctl start realms
sudo systemctl status realms
```

Verify the app is running:

```bash
curl http://localhost:4000
```

## Step 8: Configure Caddy Reverse Proxy

Create the Caddyfile configuration:

```bash
sudo vim /etc/caddy/Caddyfile
```

Replace the contents with (replace `your-domain.com` with your actual domain):

```
your-domain.com {
    reverse_proxy localhost:4000
}
```

That's it! Caddy will automatically:

- Get SSL certificates from Let's Encrypt
- Renew certificates automatically
- Redirect HTTP to HTTPS
- Handle WebSocket upgrades for LiveView

Reload Caddy to apply the configuration:

```bash
sudo systemctl enable caddy
sudo systemctl start caddy
```

Verify Caddy is running:

```bash
sudo systemctl status caddy
```

**Important**: Make sure your firewall allows HTTP and HTTPS traffic:

```bash
# If firewalld is running
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

## Step 10: Configure Sudo Permissions

Allow the deployment user to manage services and view logs without a password:

```bash
sudo visudo -f /etc/sudoers.d/realms
```

Add the following line (replace `YOUR_USERNAME` with your actual username):

```
YOUR_USERNAME ALL=(ALL) NOPASSWD: /usr/bin/systemctl, /usr/bin/journalctl
```

**Note**: This allows all systemctl and journalctl commands without password prompts.

Save and exit. Test:

```bash
sudo systemctl restart realms
# Should not prompt for password
```

## Step 11: Generate SSH Key for GitHub Actions

Generate a dedicated SSH key for deployments:

```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_actions
```

Don't set a passphrase (press Enter when prompted).

Add the public key to authorized_keys:

```bash
cat ~/.ssh/github_actions.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Display the private key (you'll add this to GitHub Secrets):

```bash
cat ~/.ssh/github_actions
```

Copy the entire output including `-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----`.

Get SSH known hosts entry:

```bash
ssh-keyscan -H your-vps-ip-address
```

Copy this output as well.

## Step 12: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions → New repository secret.

Add the following secrets:

1. **SSH_PRIVATE_KEY**: Paste the private key from `~/.ssh/github_actions`
2. **SSH_KNOWN_HOSTS**: Paste the output from `ssh-keyscan`
3. **VPS_HOST**: Your VPS IP address or domain
4. **VPS_USER**: Your username on the VPS

## Step 13: Test GitHub Actions Deployment

Make a small change to the repository and push to main:

```bash
# On your local machine
cd /path/to/realms
echo "# Deployment test" >> README.md
git add README.md
git commit -m "Test deployment"
git push origin main
```

Watch the deployment:

1. Go to GitHub → Actions tab
2. Watch the "Deploy to VPS" workflow run
3. On the VPS, monitor logs:

```bash
tail -f /var/log/realms/deploy.log
```

Verify the deployment:

```bash
curl https://your-domain.com
sudo systemctl status realms
```

## Step 14: Cleanup

Remove the generated SSH private key from the VPS (it's no longer needed locally, only in GitHub Secrets):

```bash
rm ~/.ssh/github_actions
```

Keep the public key in `authorized_keys` for GitHub Actions to authenticate.

## Monitoring and Maintenance

### View Application Logs

```bash
# Deployment logs
tail -f /var/log/realms/deploy.log

# Application stdout
tail -f /var/log/realms/stdout.log

# Application stderr
tail -f /var/log/realms/stderr.log

# Systemd journal
sudo journalctl -u realms -f
```

### Service Management

```bash
# Check status
sudo systemctl status realms

# Restart service
sudo systemctl restart realms

# Stop service
sudo systemctl stop realms

# Start service
sudo systemctl start realms
```

### Database Management

```bash
# Connect to production database
psql -U realms -d realms_prod -h localhost

# Backup database
pg_dump -U realms -d realms_prod -h localhost > backup.sql

# Restore database
psql -U realms -d realms_prod -h localhost < backup.sql
```

### Manual Rollback

If you need to rollback to a previous version:

```bash
cd /opt/realms/app
git log --oneline  # Find the commit to rollback to
git reset --hard COMMIT_HASH
/opt/realms/app/bin/deploy.sh
```

To rollback migrations:

```bash
cd /opt/realms/app
source /etc/realms/env
mix ecto.rollback --step 1
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs
sudo journalctl -u realms -n 50

# Check if port is already in use
sudo ss -tlnp | grep :4000
# Or if you have lsof installed:
# sudo lsof -i :4000

# Verify environment file
cat /etc/realms/env

# Test database connection
psql -U realms -d realms_prod -h localhost
```

### Deployment Fails

```bash
# Check deployment logs
tail -100 /var/log/realms/deploy.log

# Verify GitHub Actions can SSH
ssh -i ~/.ssh/github_actions $USER@localhost

# Check disk space
df -h

# Check permissions
ls -la /opt/realms
ls -la /var/log/realms
```

### SSL Certificate Issues

```bash
# Check Caddy status and logs
sudo systemctl status caddy
sudo journalctl -u caddy -n 50

# Verify Caddyfile syntax
sudo caddy validate --config /etc/caddy/Caddyfile

# Force certificate renewal (Caddy handles this automatically, but you can check)
sudo journalctl -u caddy | grep -i certificate
```

## Security Hardening (Optional)

### Firewall Configuration

CentOS uses firewalld by default:

```bash
# Start and enable firewalld
sudo systemctl enable firewalld
sudo systemctl start firewalld

# Allow HTTP and HTTPS (SSH is usually allowed by default)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# Verify rules
sudo firewall-cmd --list-all
```

### Fail2Ban for SSH Protection

```bash
sudo dnf install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### Regular Updates

Set up automatic security updates:

```bash
sudo dnf install -y dnf-automatic
sudo systemctl enable --now dnf-automatic.timer
```

Edit the configuration to apply updates automatically:

```bash
sudo vim /etc/dnf/automatic.conf
```

Change `apply_updates = no` to `apply_updates = yes` under the `[commands]` section.

## Summary

Your VPS is now configured for automatic deployments! Every push to the `main` branch will trigger a deployment after CI passes.

**Next Steps:**

- Monitor the first few deployments
- Set up database backups
- Configure monitoring/alerting
- Review logs regularly

**Important Files:**

- App directory: `/opt/realms/app`
- Environment config: `/etc/realms/env`
- Deployment script: `/opt/realms/app/bin/deploy.sh`
- Systemd service: `/etc/systemd/system/realms.service`
- Logs: `/var/log/realms/`
- Caddy config: `/etc/caddy/Caddyfile`
