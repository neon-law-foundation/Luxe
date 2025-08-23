# Vegas - AWS Infrastructure Management Tool

Vegas is a command-line tool for managing AWS infrastructure using CloudFormation. It provides subcommands for creating
infrastructure and connecting to RDS databases.

## Infrastructure Architecture

```mermaid
graph TB
    %% Internet
    Internet[🌐 Internet]

    %% VPC
    subgraph VPC["🏢 VPC (10.111.0.0/16) - Oregon (us-west-2)"]

        %% Public Subnets
        subgraph PublicSubnets["🌍 Public Subnets"]
            SubnetAPublic["📡 Subnet A Public<br/>10.111.0.0/20<br/>AZ: us-west-2a"]
            SubnetBPublic["📡 Subnet B Public<br/>10.111.32.0/20<br/>AZ: us-west-2b"]
            SubnetCPublic["📡 Subnet C Public<br/>10.111.64.0/20<br/>AZ: us-west-2c"]
        end

        %% Private Subnets
        subgraph PrivateSubnets["🔒 Private Subnets"]
            SubnetAPrivate["🔐 Subnet A Private<br/>10.111.16.0/20<br/>AZ: us-west-2a"]
            SubnetBPrivate["🔐 Subnet B Private<br/>10.111.48.0/20<br/>AZ: us-west-2b"]
            SubnetCPrivate["🔐 Subnet C Private<br/>10.111.80.0/20<br/>AZ: us-west-2c"]
        end

        %% Application Load Balancer
        ALB["⚖️ Application Load Balancer<br/>sagebrush-alb<br/>HTTPS: 443<br/>HTTP: 80"]

        %% ECS Services
        subgraph ECSServices["🐳 ECS Fargate Services"]
            BazaarService["🏪 Bazaar Service<br/>Port: 8080<br/>Host: www.sagebrush.services<br/>Cluster:
                          bazaar-cluster"]
            DestinedService["✈️ Destined Service<br/>Port: 8080<br/>Host: www.destined.travel<br/>Cluster:
                           destined-cluster"]
        end

        %% RDS Database
        RDS["🗄️ RDS PostgreSQL<br/>Instance: oregon-rds-postgres<br/>Port: 5432<br/>Database: luxe<br/>
             Engine: PostgreSQL 17.2"]

        %% Bastion Host
        Bastion["🖥️ Bastion Host<br/>Instance: t3.nano<br/>SSM Agent Enabled<br/>Key: engineering-system-keypair"]

        %% VPC Endpoints
        subgraph VPCEndpoints["🔗 VPC Endpoints"]
            S3Endpoint["📦 S3 VPC Endpoint<br/>Gateway Type"]
            %% ECR endpoint removed - using GitHub Container Registry instead
        end

        %% Security Groups
        subgraph SecurityGroups["🛡️ Security Groups"]
            ALBSG["ALB Security Group<br/>HTTPS: 443, HTTP: 80"]
            ECSSG["ECS Security Group<br/>Port: 8080"]
            RDSSG["RDS Security Group<br/>PostgreSQL: 5432"]
            BastionSG["Bastion Security Group<br/>SSH: 22"]
        end

        %% Cognito
        Cognito["🔐 Cognito User Pool<br/>sagebrush-user-pool<br/>Domain: sagebrush-auth"]

        %% S3 Buckets
        subgraph S3Buckets["🪣 S3 Buckets"]
            PublicBucket["🌐 Public Bucket<br/>sagebrush-public"]
            PrivateBucket["🔒 Private Bucket<br/>sagebrush-private<br/>VPC-only access"]
            EmailBucket["📧 Email Bucket<br/>sagebrush-emails"]
        end

        %% SQS Queue
        SQS["📬 SQS Queue<br/>bazaar-jobs<br/>Dead Letter: bazaar-jobs_failed"]

        %% Secrets Manager
        Secrets["🔑 Secrets Manager<br/>Database credentials<br/>RDS connection string"]

        %% Container Images (GitHub Container Registry)
        subgraph ContainerImages["📦 Container Images (ghcr.io)"]
            BazaarImage["🏪 Bazaar Image<br/>ghcr.io/neon-law-foundation/bazaar"]
            DestinedImage["✈️ Destined Image<br/>ghcr.io/neon-law-foundation/destined"]
        end

        %% SSL Certificates
        subgraph SSLCerts["🔒 SSL Certificates"]
            BazaarCert["🏪 Bazaar Certificate<br/>www.sagebrush.services"]
            DestinedCert["✈️ Destined Certificate<br/>www.destined.travel"]
        end
    end

    %% External Services
    subgraph ExternalServices["🌍 External Services"]
        SES["📧 SES Email Processing<br/>Receipt Rules<br/>support@sagebrush.services<br/>
             support@neonlaw.com<br/>support@neonlaw.org"]
        %% Doppler system account removed - secrets managed directly
        %% GitHub system account removed - using public ghcr.io images
        Engineering["👨‍💻 Engineering Account<br/>Administrator Access"]
    end

    %% Connections
    Internet --> ALB
    ALB --> ALBSG
    ALBSG --> ECSSG
    ECSSG --> BazaarService
    ECSSG --> DestinedService

    BazaarService --> RDS
    DestinedService --> RDS
    Bastion --> RDS

    BazaarService --> PrivateBucket
    DestinedService --> PrivateBucket

    BazaarService --> SQS
    DestinedService --> SQS

    BazaarService --> Secrets
    DestinedService --> Secrets

    SES --> EmailBucket
    EmailBucket --> SQS

    BazaarService --> Cognito
    DestinedService --> Cognito

    %% Subnet placements
    ALB -.-> SubnetAPublic
    ALB -.-> SubnetBPublic
    ALB -.-> SubnetCPublic

    BazaarService -.-> SubnetAPublic
    BazaarService -.-> SubnetBPublic
    BazaarService -.-> SubnetCPublic

    DestinedService -.-> SubnetAPublic
    DestinedService -.-> SubnetBPublic
    DestinedService -.-> SubnetCPublic

    RDS -.-> SubnetAPrivate
    RDS -.-> SubnetBPrivate
    RDS -.-> SubnetCPrivate

    Bastion -.-> SubnetAPublic

    %% VPC Endpoint connections
    PrivateBucket -.-> S3Endpoint
    BazaarService -.-> S3Endpoint
    DestinedService -.-> S3Endpoint

    %% Services pull images from GitHub Container Registry

    %% Security group connections
    ALB --> ALBSG
    BazaarService --> ECSSG
    DestinedService --> ECSSG
    RDS --> RDSSG
    Bastion --> BastionSG

    %% External account connections
    %% Doppler integration removed
    %% GitHub publishes public images to ghcr.io - no AWS account needed
    Engineering -.-> Bastion

    %% SSL Certificate connections
    ALB --> BazaarCert
    ALB --> DestinedCert

    %% Container image connections
    BazaarService --> BazaarImage
    DestinedService --> DestinedImage

    %% Styling
    classDef vpcStyle fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef publicStyle fill:#c8e6c9,stroke:#2e7d32,stroke-width:2px
    classDef privateStyle fill:#ffcdd2,stroke:#c62828,stroke-width:2px
    classDef serviceStyle fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef databaseStyle fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef securityStyle fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef externalStyle fill:#f1f8e9,stroke:#558b2f,stroke-width:2px

    class VPC vpcStyle
    class PublicSubnets,SubnetAPublic,SubnetBPublic,SubnetCPublic publicStyle
    class PrivateSubnets,SubnetAPrivate,SubnetBPrivate,SubnetCPrivate privateStyle
    class ECSServices,BazaarService,DestinedService,ALB serviceStyle
    class RDS,Secrets databaseStyle
    class SecurityGroups,ALBSG,ECSSG,RDSSG,BastionSG securityStyle
    class ExternalServices,SES,Engineering externalStyle
```

## Prerequisites

Before using Vegas, ensure you have the following environment variables configured:

- `AWS_ACCESS_KEY_ID` - Your AWS access key ID

- `AWS_SECRET_ACCESS_KEY` - Your AWS secret access key

- `LUXE_PASSWORD` - Password for the RDS PostgreSQL database

## Usage

Vegas supports the following commands:

### Infrastructure Command

Create and manage AWS infrastructure using CloudFormation:

```bash
swift run Vegas infrastructure
```

This command will create or update the following AWS resources:

- VPC networks in Oregon (us-west-2) and Ohio (us-east-2) regions
- Public S3 bucket for static content
- RDS PostgreSQL database in Oregon region
- AWS Secrets Manager for database credentials
- Container images stored in GitHub Container Registry (ghcr.io)
- SSL certificates for various domains
- Cognito User Pool for authentication
- Application Load Balancer with authentication
- ECS Fargate services for the unified Bazaar application (serves both API and web content)

### Update Services Command

Update ECS services with the latest container images from GitHub Container Registry:

```bash
swift run Vegas update-services
```

This command will:
- Update both Bazaar and Destined ECS services with the latest images from ghcr.io
- Pull the latest container versions from GitHub Container Registry
- Force new deployments even if the task definition hasn't changed
- Wait for deployments to complete successfully

You can specify a custom timeout (default: 300 seconds):

```bash
swift run Vegas update-services --timeout 600
```

### Elephants Command

Connect to the RDS PostgreSQL database and get connection information:

```bash
swift run Vegas elephants
```

**Prerequisites**: This command requires the AWS Session Manager plugin to establish a secure tunnel connection:

```bash
brew install session-manager-plugin
```

This command will:

- Retrieve the RDS endpoint from CloudFormation stack outputs

- Display connection information for the PostgreSQL database

- Run basic exploration queries to show database structure

#### Interactive Mode

To get a live psql terminal session where you can run SQL commands interactively:

```bash
swift run Vegas elephants -i
```

This interactive mode will:

- Establish a secure tunnel to the RDS database through the bastion host

- Launch a psql terminal session connected to the database

- Allow you to run SQL commands directly as if you were connected locally

- Clean up the tunnel when you exit psql (type `\q` to exit)

Example usage:

```bash
# Launch interactive psql session
swift run Vegas elephants -i

# Once connected, you can run SQL commands:
# \dt                    -- List all tables
# \d table_name         -- Describe a specific table
# SELECT * FROM users;   -- Run queries
# \q                     -- Exit psql
```

#### Non-Interactive Mode

Without the `-i` flag, the command runs in non-interactive mode and will:

- Connect to the database

- Run basic table exploration queries

- Display the results and exit

Example output:

```text
🐘 Connecting to RDS PostgreSQL database...
📍 Database endpoint: oregon-rds-database.abc123.us-west-2.rds.amazonaws.com
🔗 Connection URL: postgresql://postgres:****@oregon-rds-database.abc123.us-west-2.rds.amazonaws.com:5432/luxe

📊 To explore tables, run these queries once connected:
   \dt                   -- List all tables
   \d table_name         -- Describe a specific table
   SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';
   SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
```

## Help

To see all available commands:

```bash
swift run Vegas --help
```

To get help for a specific command:

```bash
swift run Vegas infrastructure --help
swift run Vegas elephants --help
```
