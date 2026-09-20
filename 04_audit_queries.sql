USE ROLE ACCOUNTADMIN;
-- ACCOUNT_USAGE views: historical, account-wide, some latency, minutes to a few hours
-- Every user holding ACCOUNTADMIN (classic audit control)
SELECT grantee_name AS user_name, created_on
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
WHERE role = 'ACCOUNTADMIN' AND deleted_on IS NULL;
-- Selecting grantee_name column and showing it as user_name
-- Also selecting the created_on column, notice the comma
-- From the specified VIEW not table
    -- A table stores data
    -- A view is a saved query being executed to pull data that u want
-- Where the role is ACCOUNTADMIN (case sensitive) AND deleted_on value IS NULL
    -- You must IS NULL not = NULL
        -- = NULL returns neither true nor false, so nothing is returned


-- Failed logins in the last 7 days
SELECT event_timestamp, user_name, client_ip, error_message
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE is_success = 'NO' AND event_timestamp > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY event_timestamp DESC;
-- Self explanatory 
-- The > means AFTER the time that was supposed, so in the case above, the line is saying AND show everything after 7 days ago
-- We would use before for example if we say > 7 days ago and < 1 day ago, to create a time window.


-- Users without MFA / still using passwords / stale users
SELECT name, type, has_password, has_rsa_public_key, has_mfa, last_success_login, disabled
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE deleted_on IS NULL
ORDER BY last_success_login NULLS FIRST;
-- Self explanatory
-- Purpose of WHERE line is so that it only shows the rows that have never been deleted. 


-- Privilege changes (who granted what, when)
SELECT query_text, user_name, role_name, start_time
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_type IN ('GRANT','REVOKE') AND start_time > DATEADD(day,-30,CURRENT_TIMESTAMP())
ORDER BY start_time DESC;
-- Self explanatory, other than the fact it will pull rows from grants that we didn’t even do
    -- Snowflake's own internal services run grants during account setup and maintenance


-- Credit burn by warehouse (cost ops)
SELECT warehouse_name, SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time > DATEADD(day,-30,CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY 2;
-- credits_used actually shows credits used per hour, so each row is a new hour
-- That’s why we use sum, and group by 1
    -- Group by 1 meaning, grouping the outputs with the value from the first column we selected
    -- Summing together all of the credits used for that warehouse in the last 30 days 


-- Long-running queries (operartional support)
SELECT query_id, user_name, warehouse_name, total_elapsed_time/1000 AS seconds, query_text
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time > DATEADD(day,-1,CURRENT_TIMESTAMP())
ORDER BY total_elapsed_time DESC 
LIMIT 20;
-- Selecting those columns
-- Total elapsed time is mentioned ms so, dividing by 1000 gives us seconds
