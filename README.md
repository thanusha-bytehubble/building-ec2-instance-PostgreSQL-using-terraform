# building-ec2-instance-PostgreSQL-using-terraform

This project uses **Terraform** to provision an **Ubuntu EC2 instance** on AWS and automatically:

- Installs **PostgreSQL** on the instance
- Configures PostgreSQL to allow remote connections (for demo)
- Creates:
  - A database: `appdb`
  - A user: `appuser` with password `AppUser123!`

It uses the **default VPC and subnets** in your AWS account and creates a security group that allows SSH and PostgreSQL access.

> ⚠️ This setup is for **learning/demo** only. Security is intentionally relaxed (0.0.0.0/0). Do **not** use as-is in production.

---

## 🏗️ What Terraform Creates

From `main.tf`, the following are created:

1. **AWS Provider config**
   - Uses `var.aws_region` to set the AWS region.

2. **Networking (via data sources)**
   - Uses your **default VPC**:
     ```hcl
     data "aws_vpc" "default" { default = true }
     ```
   - Fetches all **subnets** in that VPC:
     ```hcl
     data "aws_subnets" "default" { ... }
     ```

3. **Security Group `ec2-postgres-sg`**
   - Attached to default VPC
   - Ingress rules:
     - `22/tcp` → SSH from **anywhere** (`0.0.0.0/0`)
     - `5432/tcp` → PostgreSQL from **anywhere** (`0.0.0.0/0`)
   - Egress:
     - All traffic allowed out (`0.0.0.0/0`)

4. **EC2 Instance `aws_instance.demo_ec2`**
   - AMI: `ami-0b8d527345fdace59` (Ubuntu-based AMI in your chosen region)
   - Instance type: `var.instance_type`
   - Key pair: `var.key_name`
   - Uses first default subnet: `data.aws_subnets.default.ids[0]`
   - Public IP associated
   - Uses `user_data` (cloud-init) to:
     - Install PostgreSQL server + client
     - Update `postgresql.conf` & `pg_hba.conf`
     - Allow external connections
     - Create `appuser` and `appdb`

---

## 📁 Project Structure

```txt
.
├── main.tf            # Main Terraform configuration (provider, SG, EC2, PostgreSQL setup)
├── variables.tf       # Input variables (region, instance type, key name, etc.)
├── outputs.tf         # Terraform outputs (e.g. EC2 public IP)
├── terraform.tfvars   # Your actual values for variables (NOT committed)

