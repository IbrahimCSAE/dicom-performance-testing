# DICOM Performance Testing

This project automates the setup of a DICOM performance testing environment using AWS EC2 instances, Orthanc DICOM server, and DCMTK client tools. It provisions infrastructure with Terraform and configures the services using Ansible.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Accessing Services](#accessing-services)
- [Performance Testing](#performance-testing)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)
- [Project Structure](#project-structure)

## Overview

This project sets up a complete DICOM (Digital Imaging and Communications in Medicine) testing environment to measure transfer performance between a DICOM server (Orthanc) and a DICOM client (DCMTK). The infrastructure is provisioned on AWS using Terraform, and the services are configured using Ansible.

**Components:**
- **Orthanc Server**: A lightweight DICOM server running on port 4242 (DICOM) and 8042 (Web UI)
- **DCMTK Client**: DICOM toolkit client tools for sending DICOM files
- **AWS Infrastructure**: Two EC2 instances (t3.micro) running Ubuntu 22.04

## Architecture

```
┌─────────────────────┐         ┌─────────────────────┐
│   DICOM Client      │         │   Orthanc Server    │
│   (DCMTK)           │────────▶│   (Port 4242)       │
│   EC2 Instance      │  DICOM  │   EC2 Instance      │
│                     │         │   Web UI: 8042      │
└─────────────────────┘         └─────────────────────┘
```

## Prerequisites

Before you begin, ensure you have the following installed and configured:

### Required Software

1. **Terraform** (>= 1.4)
   - Download from [terraform.io](https://www.terraform.io/downloads)
   - Verify installation: `terraform version`

2. **Ansible** (>= 2.9)
   - Install via pip: `pip install ansible`
   - Or via package manager: `sudo apt-get install ansible` (Linux) / `brew install ansible` (macOS)
   - Verify installation: `ansible --version`

3. **AWS CLI**
   - Install from [aws.amazon.com/cli](https://aws.amazon.com/cli/)
   - Verify installation: `aws --version`

4. **SSH Key Pair**
   - You'll need an SSH key pair for accessing EC2 instances
   - Generate if needed: `ssh-keygen -t rsa -b 4096 -f aws_key`

### AWS Requirements

1. **AWS Account**
   - Active AWS account with appropriate permissions
   - IAM user/role with permissions to create EC2 instances, security groups, and key pairs

2. **AWS Credentials**
   - Configure AWS credentials using one of these methods:
     - AWS CLI: `aws configure`
     - Environment variables: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
     - IAM role (if running on EC2)

3. **AWS Region**
   - Default region is `us-east-1` (configurable in `main.tf`)
   - Ensure you have sufficient EC2 limits in your region

## Installation

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd dicom-performance-testing
```

### Step 2: Prepare SSH Key Pair

1. Generate an SSH key pair if you don't have one:
   ```bash
   ssh-keygen -t rsa -b 4096 -f aws_key
   ```
   This creates:
   - `aws_key` (private key)
   - `aws_key.pub` (public key)

2. **Important**: Do not commit the private key (`aws_key`) to version control. Add it to `.gitignore`:
   ```bash
   echo "aws_key" >> .gitignore
   ```

### Step 3: Initialize Terraform

```bash
terraform init
```

This downloads the required Terraform providers (AWS provider).

### Step 4: Review Configuration

Before provisioning, review the configuration in `main.tf`:
- **Region**: Default is `us-east-1` (line 12)
- **Instance Type**: Default is `t3.micro` (lines 55, 66)
- **AMI**: Ubuntu 22.04 AMI ID (lines 54, 65) - verify this AMI exists in your region

To find the correct Ubuntu 22.04 AMI for your region:
```bash
aws ec2 describe-images --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'Images[*].[ImageId,CreationDate]' --output table | sort -k2 -r | head -1
```

## Configuration

### Terraform Configuration

The main configuration is in `main.tf`:
- **Security Group**: Opens ports 22 (SSH), 4242 (DICOM), and 8042 (Orthanc Web UI)
- **Instances**: Two t3.micro instances (can be modified for performance testing)
- **Key Pair**: Uses `aws_key.pub` for SSH access

### Ansible Configuration

The `ansible.cfg` file configures:
- Remote user: `ubuntu`
- Private key: `./aws_key`
- Host key checking: Disabled (for dynamic inventory)

## Usage

### Step 1: Provision Infrastructure

1. **Plan the deployment** (optional but recommended):
   ```bash
   terraform plan
   ```
   Review the planned changes to ensure everything looks correct.

2. **Apply Terraform configuration**:
   ```bash
   terraform apply
   ```
   Type `yes` when prompted to confirm.

3. **Save the inventory**:
   After Terraform completes, it will output an Ansible inventory. Save it to a file:
   ```bash
   terraform output -raw inventory > inventory.ini
   ```

   Or manually create `inventory.ini` with the output:
   ```ini
   [orthanc]
   orthanc ansible_host=<ORTHANC_IP>

   [dicom_client]
   dicom_client ansible_host=<DICOM_CLIENT_IP>
   ```

### Step 2: Configure Services with Ansible

1. **Install Orthanc server**:
   ```bash
   ansible-playbook -i inventory.ini orthanc.yml
   ```

2. **Install DCMTK and run performance test**:
   ```bash
   ansible-playbook -i inventory.ini dicomtk.yml
   ```

### Step 3: Verify Installation

1. **Check Orthanc status**:
   ```bash
   ssh -i aws_key ubuntu@<ORTHANC_IP> "systemctl status orthanc"
   ```

2. **Check DICOM transfer log**:
   ```bash
   ssh -i aws_key ubuntu@<DICOM_CLIENT_IP> "cat /tmp/dicom_transfer.log"
   ```

## Accessing Services

### Orthanc Web UI

1. Get the Orthanc instance IP:
   ```bash
   terraform output
   ```
   Or check the `inventory.ini` file.

2. Open in browser:
   ```
   http://<ORTHANC_IP>:8042
   ```

3. Default credentials (if authentication is enabled):
   - Username: `orthanc`
   - Password: `orthanc`

### SSH Access

Access the instances using:
```bash
ssh -i aws_key ubuntu@<INSTANCE_IP>
```

## Performance Testing

### Automated Test

The `dicomtk.yml` playbook automatically:
1. Downloads a sample DICOM file
2. Sends it to Orthanc using `storescu`
3. Measures transfer time
4. Logs results to `/tmp/dicom_transfer.log`

### Manual Testing

1. **SSH into the DICOM client**:
   ```bash
   ssh -i aws_key ubuntu@<DICOM_CLIENT_IP>
   ```

2. **Send DICOM files manually**:
   ```bash
   # Single file
   storescu <ORTHANC_IP> 4242 /path/to/file.dcm

   # Directory
   storescu <ORTHANC_IP> 4242 /tmp/dcms --scan-directories

   # With timing
   time storescu <ORTHANC_IP> 4242 /tmp/dcms --scan-directories
   ```

3. **Check Orthanc for received files**:
   - Access the Web UI at `http://<ORTHANC_IP>:8042`
   - Navigate to the patient/study to view received DICOM files

### Advanced Performance Testing

For more comprehensive testing:

1. **Upload multiple files**:
   ```bash
   # On DICOM client
   for i in {1..10}; do
     storescu <ORTHANC_IP> 4242 /tmp/dcms/*.dcm
   done
   ```

2. **Measure network performance**:
   ```bash
   # On DICOM client
   iperf3 -c <ORTHANC_IP>
   ```

3. **Monitor system resources**:
   ```bash
   # On both instances
   htop
   # Or
   watch -n 1 'free -h && df -h'
   ```

## Troubleshooting

### Terraform Issues

**Error: No valid credential sources found**
- Solution: Configure AWS credentials using `aws configure` or environment variables

**Error: AMI not found**
- Solution: Update the AMI ID in `main.tf` for your region (see Installation Step 4)

**Error: Insufficient instance capacity**
- Solution: Try a different instance type or availability zone

### Ansible Issues

**Error: Host key verification failed**
- Solution: This is disabled in `ansible.cfg`, but if issues persist, manually accept host keys:
  ```bash
  ssh -i aws_key ubuntu@<IP> "echo 'Host key accepted'"
  ```

**Error: Permission denied (publickey)**
- Solution: Ensure `aws_key` has correct permissions:
  ```bash
  chmod 600 aws_key
  ```

**Error: Connection timeout**
- Solution: Check security group rules allow SSH (port 22) from your IP

### Service Issues

**Orthanc not accessible on port 8042**
- Check if Orthanc is running:
  ```bash
  ssh -i aws_key ubuntu@<ORTHANC_IP> "systemctl status orthanc"
  ```
- Check firewall rules:
  ```bash
  ssh -i aws_key ubuntu@<ORTHANC_IP> "sudo ufw status"
  ```
- Verify security group allows port 8042

**DICOM transfer fails**
- Verify Orthanc is running and accessible
- Check network connectivity:
  ```bash
  ssh -i aws_key ubuntu@<DICOM_CLIENT_IP> "telnet <ORTHANC_IP> 4242"
  ```
- Check Orthanc logs:
  ```bash
  ssh -i aws_key ubuntu@<ORTHANC_IP> "sudo journalctl -u orthanc -n 50"
  ```

## Cleanup

### Destroy Infrastructure

To remove all AWS resources and avoid ongoing charges:

```bash
terraform destroy
```

Type `yes` when prompted. This will:
- Terminate EC2 instances
- Delete security groups
- Remove key pairs (if not in use elsewhere)

**Warning**: This permanently deletes all resources. Ensure you've saved any important data before running this command.

### Partial Cleanup

If you want to keep the infrastructure but clean up test data:

```bash
# On DICOM client
ssh -i aws_key ubuntu@<DICOM_CLIENT_IP> "rm -rf /tmp/dcms /tmp/dicom_transfer.log"

# On Orthanc (if you want to clear received files)
ssh -i aws_key ubuntu@<ORTHANC_IP> "sudo rm -rf /var/lib/orthanc/db/*"
```

## Project Structure

```
dicom-performance-testing/
├── main.tf              # Terraform configuration for AWS infrastructure
├── ansible.cfg          # Ansible configuration
├── orthanc.yml          # Ansible playbook for Orthanc server setup
├── dicomtk.yml          # Ansible playbook for DCMTK client setup
├── aws_key              # SSH private key (not in repo, generated locally)
├── aws_key.pub          # SSH public key (used by Terraform)
├── inventory.ini         # Ansible inventory (generated from Terraform output)
└── ReadMe.md            # This file
```

## Security Considerations

1. **SSH Keys**: Never commit private keys to version control
2. **Security Groups**: The current configuration allows access from `0.0.0.0/0`. For production, restrict to specific IPs
3. **Orthanc Access**: Consider enabling authentication in Orthanc for production use
4. **AWS Credentials**: Use IAM roles with least privilege principles
5. **Instance Types**: t3.micro is suitable for testing but may not reflect production performance

## Cost Estimation

- **EC2 Instances**: 2x t3.micro instances ≈ $0.01/hour each = $0.02/hour total
- **Data Transfer**: Minimal for testing
- **Storage**: EBS volumes included with instances

**Estimated monthly cost for continuous running**: ~$15/month (varies by region and usage)

Remember to destroy resources when not in use to avoid charges.

## Additional Resources

- [Orthanc Documentation](https://book.orthanc-server.com/)
- [DCMTK Documentation](https://dicom.offis.de/dcmtk.php.en)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Ansible Documentation](https://docs.ansible.com/)
