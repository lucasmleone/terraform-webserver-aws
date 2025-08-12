# WebServer AWS (Desafío 7)

## Descripción
Implementa con Terraform el Laboratorio 2 del Desafío 7:
- VPC `/16` con 2 subredes públicas y 2 privadas en us-east-1a/b
- Internet Gateway (lab-igw)
- NAT Gateway con Elastic IP (AZ1)
- Tablas de ruteo: pública→IGW, privada→NAT
- Security Group HTTP (puerto 80 abierto)
- EC2 t2.micro (Amazon Linux 2023) en subred pública AZ2 con user_data (Apache, PHP, app demo)

## Arquitectura
```text
         Internet
            |
           IGW
            |
       ┌────────────┐
       │ Public RT  │
       └────────────┘
         /        \
Pub Subnet1      Pub Subnet2 ─── EC2 Web (HTTP)
 (AZ1)              (AZ2)
    |                 |
    |                 +---- user_data → Apache+PHP
    |
   NAT GW
    |
┌────────────┐
│ Private RT │
└────────────┘
   /      \
Priv1     Priv2
(AZ1)     (AZ2)
```

## Prerrequisitos
- Terraform instalado.
- Credenciales AWS configuradas (`~/.aws/credentials` o variables `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`).
- Par de claves EC2 **vockey** en la región us-east-1 (hardcodeado en `main.tf`).

## Recursos Creados
- VPC: **lab-vpc** (10.0.0.0/16)  
- Subred pública AZ1: **lab-subnet-public1-us-east-1a** (10.0.0.0/24)  
- Subred pública AZ2: **lab-subnet-public2** (10.0.2.0/24)  
- Subred privada AZ1: **lab-subnet-private1-us-east-1a** (10.0.1.0/24)  
- Subred privada AZ2: **lab-subnet-private2** (10.0.3.0/24)  
- Internet Gateway: **lab-igw**  
- Elastic IP NAT: **lab-nat-eip**  
- NAT Gateway AZ1: **lab-nat-public1-us-east-1a**  
- Tablas de ruteo: **lab-rtb-public**, **lab-rtb-private1-us-east-1a**  
- Security Group HTTP: **Web Security Group**  
- EC2 “Web Server 1” (t2.micro) en Subred Pública AZ2  

## Ejecución
```bash
terraform init
terraform validate
terraform plan       # revisa plan y nombres 
terraform apply      # crea todos los recursos según main.tf
```

## Destrucción
```bash
terraform destroy    # destruye todo sin variables adicionales
```


