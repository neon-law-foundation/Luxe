# AWS ALB Authentication Simulation

This Docker setup simulates AWS Application Load Balancer (ALB) authentication behavior for local development and testing.

## Overview

AWS ALB with Cognito integration automatically injects authentication headers into requests to protected routes. This
simulation uses Nginx to replicate that behavior locally, allowing developers to test ALB-based authentication without
AWS infrastructure.

## Architecture

```text
[Browser] → [Nginx ALB Simulator:8081] → [Luxe Server:8080] → [PostgreSQL:5432]
```

## ALB Headers Injected

The simulation injects these headers based on authentication mode:

- `x-amzn-oidc-data`: Base64-encoded JWT containing user claims
- `x-amzn-oidc-accesstoken`: Mock Cognito access token  
- `x-amzn-oidc-identity`: User identity (email/username)

## Usage

### Starting the Environment

```bash
# Start all services
docker-compose -f docker-compose.alb-simulation.yml up -d

# Check service status
docker-compose -f docker-compose.alb-simulation.yml ps

# View logs
docker-compose -f docker-compose.alb-simulation.yml logs -f alb-simulator
```

### Access Points

| Service | URL | Description |
|---------|-----|-------------|
| ALB Simulator | <http://localhost:8081> | Nginx proxy with header injection |
| Direct Server | <http://localhost:8080> | Direct access (no ALB simulation) |
| PostgreSQL | localhost:5432 | Database (luxe/postgres/luxe) |

### Authentication Modes

#### 1. Query Parameter Authentication

Add `?auth=<mode>` to any URL:

```bash
# Admin authentication
curl http://localhost:8081/admin?auth=admin

# Staff authentication  
curl http://localhost:8081/staff?auth=staff

# Customer authentication
curl http://localhost:8081/app?auth=customer
```

#### 2. Auto-Detection (Route-Based)

Routes automatically get appropriate headers:

```bash
# Admin routes get admin headers
curl http://localhost:8081/admin

# Staff routes get staff headers
curl http://localhost:8081/staff

# App/API routes get customer headers
curl http://localhost:8081/app
curl http://localhost:8081/api
```

#### 3. Test Endpoints

Special endpoints for testing specific scenarios:

```bash
# Always admin authentication
curl http://localhost:8081/test/admin

# Always staff authentication
curl http://localhost:8081/test/staff

# Always customer authentication
curl http://localhost:8081/test/customer

# No authentication headers
curl http://localhost:8081/test/no-auth
```

## User Roles & Permissions

### Admin User

- **Email**: <admin@neonlaw.com>
- **Groups**: admin, administrators
- **Access**: Full system access (all routes)

### Staff User

- **Email**: <staff@neonlaw.com>
- **Groups**: staff, employees  
- **Access**: Employee-level access (/staff, /reports routes)

### Customer User

- **Email**: <customer@example.com>
- **Groups**: users, customers
- **Access**: Basic user access (/app routes)

## JWT Payloads

The simulation uses pre-generated JWT payloads for each user type:

### Admin JWT (Decoded)

```json
{
  "iss": "test-cognito",
  "aud": ["test-client"], 
  "exp": 1746818400,
  "sub": "admin-user-sub",
  "email": "admin@neonlaw.com",
  "name": "Admin User",
  "cognito_groups": ["admin", "administrators"],
  "username": "admin@neonlaw.com"
}
```

### Staff JWT (Decoded)

```json
{
  "iss": "test-cognito",
  "aud": ["test-client"],
  "exp": 1746818400, 
  "sub": "staff-user-sub",
  "email": "staff@neonlaw.com",
  "name": "Staff User",
  "cognito_groups": ["staff", "employees"],
  "username": "staff@neonlaw.com"
}
```

### Customer JWT (Decoded)

```json
{
  "iss": "test-cognito",
  "aud": ["test-client"],
  "exp": 1746818400,
  "sub": "customer-user-sub", 
  "email": "customer@example.com",
  "name": "Customer User",
  "cognito_groups": ["users", "customers"],
  "username": "customer@example.com"
}
```

## Testing Scenarios

### 1. Public Routes (No Authentication)

```bash
curl http://localhost:8081/
curl http://localhost:8081/health
curl http://localhost:8081/pricing
```

### 2. Protected Routes (Require Authentication)

```bash
# These will get customer headers automatically
curl http://localhost:8081/app
curl http://localhost:8081/app/me
curl http://localhost:8081/api/users
```

### 3. Role-Based Access Control

```bash
# Admin access required
curl http://localhost:8081/admin?auth=admin        # ✅ Success
curl http://localhost:8081/admin?auth=customer     # ❌ Forbidden

# Staff access required
curl http://localhost:8081/staff?auth=staff        # ✅ Success  
curl http://localhost:8081/staff?auth=customer     # ❌ Forbidden
```

### 4. Error Cases

```bash
# No authentication headers (should fail for protected routes)
curl http://localhost:8081/test/no-auth/app/me

# Invalid authentication mode
curl http://localhost:8081/app?auth=invalid
```

## Debugging

### View Headers Being Injected

```bash
# Check nginx logs to see headers being set
docker-compose -f docker-compose.alb-simulation.yml logs alb-simulator
```

### Direct Server Access (Bypass ALB)

```bash
# Test without ALB simulation
curl http://localhost:8080/app/me
# Should return 401 Unauthorized (no ALB headers)
```

### Database Access

```bash
# Connect to PostgreSQL
docker exec -it luxe-postgres psql -U postgres -d luxe

# Check test users
SELECT u.username, u.role, p.name, p.email 
FROM auth.users u 
JOIN directory.people p ON u.person_id = p.id;
```

## Health Checks

```bash
# ALB simulator health
curl http://localhost:8081/alb-health

# Application health (through ALB)
curl http://localhost:8081/health

# Application health (direct)
curl http://localhost:8080/health

# Database health
docker-compose -f docker-compose.alb-simulation.yml exec postgres pg_isready
```

## Stopping the Environment

```bash
# Stop all services
docker-compose -f docker-compose.alb-simulation.yml down

# Stop and remove volumes (clears database)
docker-compose -f docker-compose.alb-simulation.yml down -v
```

## Integration with Development

This simulation is designed to work alongside your normal development workflow:

1. **Development**: Use direct server access (port 8080) with TestAuthMiddleware
2. **ALB Testing**: Use ALB simulator (port 8081) to test real ALB authentication
3. **Production Testing**: Deploy to AWS with actual ALB/Cognito integration

The same codebase works in all three environments without modification.
