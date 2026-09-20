-- Finding Identifiers
SELECT CURRENT_ORGANIZATION_NAME(), CURRENT_ACCOUNT_NAME(), CURRENT_REGION(), CURRENT_ROLE();
-- these are context functions built into Snowflake's SQL engine, not columns we're calling. 

-- Protect your trial credits
USE ROLE ACCOUNTADMIN;

CREATE RESOURCE MONITOR trial_guard
    WITH CREDIT_QUOTA = 50
    TRIGGERS ON 75 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND;

    -- all caps are snowflake commands
    -- Creating the RESOURCE MONITOR object
        -- a spending cap on compute. It watches how many credits your warehouses burn, and when usage crosses the thresholds you set, it either warns you or shuts the warehouses down.
    -- Setting the CREDIT_QUOTA
    -- Triggers a notification when hit 75% of usage
    -- Suspends at a 100%
        -- Suspend finishes the existing queries, then suspends
        -- SUSPEND_IMMEDIATE suspends immediately without finishing existing queries
    

ALTER ACCOUNT SET RESOURCE_MONITOR = trial_guard;
    -- Altering account
    -- Setting the RESOURCE_MONITOR property to the resource monitor we just created


-- Create Warehouse
USE ROLE SYSADMIN;
CREATE WAREHOUSE IF NOT EXISTS learn_wh
    WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;
USE WAREHOUSE learn_wh;
-- Using the SYSADMIN role
-- Creating a WAREHOUSE if it doesn’t exist
-- Setting the parameters
    -- WAREHOUSE_SIZE
        -- Size of compute, xsmall is 1 credit per hour. 1 / 2 / 4 / 8 / 16 : small / medium / large / xlarg
    -- AUTO_SUSPEND
        -- After 60. Seconds with now queries, the warehouse shuts off
    -- AUTO_RESUME
        -- If a query comes in when the warehouse is suspended, start it automatically
    -- INITIALLY_SUSPENDED
        -- Create the warehouse in the off state
-- Then using the warehouse


-- Explore
SHOW DATABASES;
SHOW SCHEMAS IN DATABASE SNOWFLAKE_SAMPLE_DATA;
SHOW TABLES IN SCHEMA SNOWFLAKE_SAMPLE_DATA.TPCH_SF1; 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER LIMIT 10;
-- Showing the db’s
-- Showing the schemas in a specific database
    -- Tables live within schemas
-- Showing the tables in the schema
-- Showing all the columns in the chosen table, limiting to top 10 results


-- Aggregations and joins (basic SQL refresh)
SELECT n.n_name AS nation, COUNT(*) AS customers, ROUND(AVG(c.c_acctbal),2) AS avg_balance
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER c
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION n ON c.c_nationkey = n.n_nationkey
GROUP BY n.n_name
ORDER BY customers DESC;
-- First need to see available columns using either snow sight, with the db explorer on the left
    -- Or if u want to see some values, run a SELECT * FROM the NATION table with a limit
-- Before executing the query, SQL reads the whole staement first
-- So In order, what’s actually happening is 
    -- FROM Customer table, nicknamed as ‘c’ so u dont have to keep writing out the whole table path
    -- Joining the NATION table, again nicknames with ’n’, ON the nation key column from both tables
        -- Purpose of joining
            -- Customer table doesn’t have the nation names, just the nation key, so when we equate those two columns, the result is one combined table,
        -- We’re grouping each row by the name of the nation
        -- Then selecting the name column, displaying as nation, 
        -- a count of however many customers match the nation, indicative of how many customers are in that nation
        -- And than taking average from the acct balance column values from the, and rounding the second decimal place, displaying as avg balance
        -- Showing the Highest number of customers in a country first then descending from there


-- Build your own objects
CREATE DATABASE analytics;
CREATE SCHEMA analytics.claims;
CREATE TABLE analytics.claims.pharmacy_claims AS
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS LIMIT 1000;
-- Create db called analytics
-- Create schema within db analytics called claims
-- Create table within schema claims called pharmacy_claims AS the orders table from the other db.schema
    -- This is called CTAS (Create Table As Select0
    -- U get the same columns, names, datatypes, rows, values, but limited to 1000 as specified
    -- Without order by, no guarantee what data you’re putting in the table you’re creating.


-- Useful snowflake-isms
SHOW WAREHOUSES;
DESCRIBE TABLE analytics.claims.pharmacy_claims;
SELECT LAST_QUERY_ID();



    
