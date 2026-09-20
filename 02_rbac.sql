USE ROLE USERADMIN;
CREATE ROLE ar_claims_ro;
CREATE ROLE ar_claims_rw;
CREATE ROLE fr_data_analyst;
CREATE ROLE fr_data_engineer;
-- Using user admin role to create a bunch of access roles and functional roles

-- Hierarchy: functional roles get access roles; everything rolls up to SYSADMIN
GRANT ROLE ar_claims_ro TO ROLE fr_data_analyst;
GRANT ROLE ar_claims_rw TO ROLE fr_data_engineer;
GRANT ROLE fr_data_analyst TO ROLE SYSADMIN;
GRANT ROLE fr_data_engineer TO ROLE SYSADMIN;
-- Setting the hierarchy 
-- Access roles get assigned to functional roles
-- Functional roles got assigned to sysadmin

USE ROLE SECURITYADMIN;

-- Read-only: need USAGE on the container chain + SELECT on objects
GRANT USAGE ON DATABASE analytics TO ROLE ar_claims_ro;
GRANT USAGE ON SCHEMA analytics.claims TO ROLE ar_claims_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics.claims TO ROLE ar_claims_ro;
GRANT SELECT ON FUTURE TABLES IN SCHEMA analytics.claims TO ROLE ar_claims_ro;
-- Granting Permissions
-- USAGE
    -- you may access/enter this object
    -- database, schema, warehouse, role, function, stage
-- SELECT 
    -- You may read the rows
    -- Table, view


-- Read-write
GRANT USAGE ON DATABASE analytics TO ROLE ar_claims_rw;
GRANT USAGE, CREATE TABLE ON SCHEMA analytics.claims TO ROLE ar_claims_rw;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA analytics.claims TO ROLE ar_claims_rw;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA analytics.claims TO ROLE ar_claims_rw;
-- Always need to start with granting usage on the database
-- CREATE TABLE is a specific permission, just like all the others
-- So we always grant usage on the database, grant usage on the schema, and then we can proceed with all of the other permissions


-- Compute Access
GRANT USAGE ON WAREHOUSE learn_wh TO ROLE fr_data_analyst;
GRANT USAGE ON WAREHOUSE learn_wh TO ROLE fr_data_engineer;
-- Giving warehouse access to the following functional roles


-- A test user
USE ROLE USERADMIN;
CREATE USER test_analyst PASSWORD = '<password>' DEFAULT_ROLE = fr_data_analyst
    DEFAULT_WAREHOUSE = learn_wh MUST_CHANGE_PASSWORD = TRUE;
USE ROLE SECURITYADMIN;
GRANT ROLE fr_data_analyst TO USER test_analyst;
-- Using user admin role to create new users
-- Creating a certain user, setting the necessary parameters
-- Using the security admin role
-- Granting the analyst role to the user


-- What can a role do?
SHOW GRANTS TO ROLE fr_data_analyst;
-- Who has a role?
SHOW GRANTS OF ROLE fr_data_analyst;
-- What role does a user have 
SHOW GRANTS TO USER test_analyst;
-- Who has access to an object
SHOW GRANTS ON TABLE analytics.claims.pharmacy_claims;
