-- =============================================================================
-- Synapse Serverless SQL Pool: External Data Source, File Format, Credentials
-- Run this ONCE in the Synapse Serverless SQL pool (master or target database)
-- =============================================================================

-- 1. Create a database for RWP objects
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'rwp_analytics')
BEGIN
    CREATE DATABASE rwp_analytics;
END
GO

USE rwp_analytics;
GO

-- 1b. Create a database master key (required for database-scoped credentials)
-- NOTE: Replace $(MASTER_KEY_PASSWORD) with a strong password at deploy time.
-- Do NOT commit the actual password to source control.
-- Example: sqlcmd -v MASTER_KEY_PASSWORD="<your-secure-password>" -i synapse_external_objects.sql
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$(MASTER_KEY_PASSWORD)';
END
GO

-- 2. Database-scoped credential using managed identity
--    The Synapse workspace's managed identity must have
--    "Storage Blob Data Reader" on the ADLS Gen2 account.
IF NOT EXISTS (SELECT * FROM sys.database_scoped_credentials WHERE name = 'adls_managed_identity')
BEGIN
    CREATE DATABASE SCOPED CREDENTIAL adls_managed_identity
    WITH IDENTITY = 'Managed Identity';
END
GO

-- 3. External data source pointing to the ADLS Gen2 gold container
IF NOT EXISTS (SELECT * FROM sys.external_data_sources WHERE name = 'adls_datasource')
BEGIN
    CREATE EXTERNAL DATA SOURCE adls_datasource
    WITH (
        LOCATION = 'abfss://gold@mvdcoredatalake.dfs.core.windows.net',
        CREDENTIAL = adls_managed_identity
    );
END
GO

-- 3b. External data source pointing to the ADLS Gen2 staging container
--     Used for shared StarLIMS staging tables and RWP-specific staging tables
IF NOT EXISTS (SELECT * FROM sys.external_data_sources WHERE name = 'adls_staging')
BEGIN
    CREATE EXTERNAL DATA SOURCE adls_staging
    WITH (
        LOCATION = 'abfss://staging@mvdcoredatalake.dfs.core.windows.net',
        CREDENTIAL = adls_managed_identity
    );
END
GO

-- 4. External file format for Parquet
IF NOT EXISTS (SELECT * FROM sys.external_file_formats WHERE name = 'parquet_format')
BEGIN
    CREATE EXTERNAL FILE FORMAT parquet_format
    WITH (
        FORMAT_TYPE = PARQUET,
        DATA_COMPRESSION = 'org.apache.hadoop.io.compress.SnappyCodec'
    );
END
GO
