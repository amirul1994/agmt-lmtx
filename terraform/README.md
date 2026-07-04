**For Task 4 and Task 5 I have used Terraform**

## Complete Diagram

![alt text](logicmatrix_full_diagram.png)

## RDS

![alt text](logicmatrix_rds_diagram.png)

EKS and RDS are both placed in the same vpc. EKS worker nodes are deployed in private subnets 10.0.10.0/24, 10.0.11.0/24. RDS instance is deployed in separate priavte subnets 10.0.20.0/24 and 10.0.21.0/24. 

A VPC endpoint allows private connectivity to the aws services (e.g s3, dynamodb) without traversing to the internet. Aws rds doesn't support vpc endpoints (aws privatelink) for database conections. In this architecture, rds is deployed directly inside private subnets. RDS has no public ip assigned, nat gateways are configured for outbound internet access from private subnets.

A route 53 private hosted zone is created and associated with the vpc. It provides the internal dns resolution for the rds database. EKS pods and bastion need a consistent way to locate the rds endpoint. The dns name works with the underlying rds instance, so the ip of the rds instance can be updated without changing the application code. As it is a private hosted zone, the dns name resolves only within the vpc.

The security groups provide the necessary isolation for inbound and outbound traffic. The rds security group allows incoming traffic only from bastion security group and eks node security group on port 5432. All outbound traffic are allowed.

The backend can access to the databse through a combination of network isolation, security group rules, private dns and credential management.

The primary mechanism is the rds security group, there are two inbound rules
a) Inbound rule 1 - allows traffic on port 5432 only from eks node security group
b) Inbound rule 2 - allows traffic on port 5432 only from the bastion security group

So only resources that are in the eks cluster node sg and bastion sg can connect to the database.  

RDS resolves to a private dns name only within the vpc. The route 53 hosted zone is associated only with this vpc. The database username and password are stored in the aws secret manager. The backend retrieve these credentials at runtime via IAM roles and the secret manager api. EKS pods use iam roles for service accounts (irsa) to authenticate to aws service. Only the backend service account has permission to read secret from secrets manager. In the code, it is needed to add aws sdk, and in the backend service account add the following annotations.

```bash
annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT-ID>:role/myapp-production-backend-sa-irsa
```

The database credential are stored in aws secret manager. The secrets are stored in json format.

```bash
aws secretsmanager create-secret \
 --name "myapp-production-rds-credentials" \
 --secret-string '{"db_name":"mydb","username":"admin","password":"passwordwithuppercaselowercasenumberspecialcharacter"}' \
 --region us-east-1
```
The secret is encrypted when it is stored via aws kms. The terraform execution role has permission to read the secret during 'terraform apply'. The backend pods are given irsa that grants read-only permission to secrets manager for the rds credentials. The eks backend doesn't store the credentials on persistent volume, environment variables or in kubenetes secrets. The app retrieves the secret at startup using aws sdk and irsa. The secret value held in the applications memory for the lifetime of the pod.


