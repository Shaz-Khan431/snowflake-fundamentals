USE ROLE USERADMIN;
CREATE ROLE terraform_role;
USE ROLE ACCOUNTADMIN;
GRANT ROLE SYSADMIN TO ROLE terraform_role;
GRANT ROLE SECURITYADMIN TO ROLE terraform_role;

USE ROLE USERADMIN;
CREATE USER terraform_svc
    TYPE = SERVICE
    DEFAULT_ROLE = terraform_role
    RSA_PUBLIC_KEY = '<paste pub key here>';
USE ROLE SECURITYADMIN;
GRANT ROLE terraform_role TO USER terraform_svc;
