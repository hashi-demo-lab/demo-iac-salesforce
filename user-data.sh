#!/bin/bash
# User data script for EC2 Nginx installation
# Feature: EC2 Infrastructure with ALB and Nginx
# Reference: FR-003 (Static web server configuration)

# Log all output to cloud-init-output.log
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user-data script..."

# Update system packages
echo "Updating system packages..."
dnf update -y

# Install nginx
echo "Installing nginx..."
dnf install -y nginx

# Get instance metadata using IMDSv2
echo "Fetching instance metadata..."
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AVAILABILITY_ZONE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

echo "Instance ID: $INSTANCE_ID"
echo "Availability Zone: $AVAILABILITY_ZONE"
echo "Private IP: $PRIVATE_IP"

# Create HTML page with instance information
echo "Creating index.html..."
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EC2 ALB Nginx Infrastructure</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            border-radius: 8px;
            padding: 30px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            border-bottom: 3px solid #4CAF50;
            padding-bottom: 10px;
        }
        .info {
            margin: 20px 0;
            padding: 15px;
            background-color: #f9f9f9;
            border-left: 4px solid #4CAF50;
        }
        .label {
            font-weight: bold;
            color: #666;
        }
        .value {
            color: #333;
            margin-left: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to EC2 ALB Nginx Infrastructure</h1>
        <div class="info">
            <p><span class="label">Server:</span><span class="value">$INSTANCE_ID</span></p>
            <p><span class="label">Availability Zone:</span><span class="value">$AVAILABILITY_ZONE</span></p>
            <p><span class="label">Private IP:</span><span class="value">$PRIVATE_IP</span></p>
            <p><span class="label">Timestamp:</span><span class="value">$(date)</span></p>
        </div>
        <p>This static web server is part of a highly available infrastructure deployed with Terraform.</p>
        <p>Traffic is load balanced across multiple availability zones for redundancy.</p>
    </div>
</body>
</html>
EOF

# Disable firewalld if installed (security groups handle network security)
echo "Disabling firewalld if present..."
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true

# Enable and start nginx
echo "Starting nginx..."
systemctl enable nginx
systemctl start nginx

# Verify nginx is running
echo "Verifying nginx status..."
systemctl status nginx

echo "User-data script completed successfully!"
