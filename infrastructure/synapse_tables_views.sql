-- =============================================================================
-- Synapse Serverless SQL Pool: External Tables and Views for RWP
-- Prerequisites: Run synapse_external_objects.sql first
-- =============================================================================

USE rwp_analytics;
GO

-- =============================================================================
-- External Table: fact_results_with_pricing
-- Points to Parquet files in ADLS Gen2 gold zone
-- Partitioned by year(DateEnter) via folder structure: year=YYYY/
-- =============================================================================

IF EXISTS (SELECT * FROM sys.external_tables WHERE name = 'fact_results_with_pricing')
    DROP EXTERNAL TABLE [dbo].[fact_results_with_pricing];
GO

CREATE EXTERNAL TABLE [dbo].[fact_results_with_pricing]
(
    [ORDNO]             VARCHAR(50),
    [COMPNAME]          VARCHAR(255),
    [ExternalId]        NVARCHAR(50),
    [BirthDate]         DATETIME2,
    [ClientSampleId]    NVARCHAR(100),
    [FirstName]         NVARCHAR(100),
    [LastName]          NVARCHAR(100),
    [DateCollected]     DATETIME2,
    [SpecSource]        NVARCHAR(100),
    [DateEnter]         DATETIME2,
    [SourceTestCode]    INT,
    [ResolvedTestCode]  INT,
    [TestGroupName]     NVARCHAR(50),
    [IsPanel]           BIT,
    [Analyte]           NVARCHAR(100),
    [Final]             NVARCHAR(100),
    [NumRes]            NVARCHAR(50),
    [RN2]               NVARCHAR(50),
    [CancelStatus]      VARCHAR(10),
    [HasPendingResults] BIT,
    [Price]             DECIMAL(8,2),
    [PriceListId]       NVARCHAR(15),
    [PriceListVersion]  INT,
    [PricingMethod]     VARCHAR(10),
    [Category]          NVARCHAR(255),
    [State]             NVARCHAR(80),
    [City]              NVARCHAR(200),
    [Zip]               NVARCHAR(15),
    [LatestResultDate]  DATETIME2,
    [ETL_LoadDate]      DATETIME2
)
WITH (
    LOCATION = 'rwp/fact_results_with_pricing/**',
    DATA_SOURCE = adls_datasource,
    FILE_FORMAT = parquet_format
);
GO

-- =============================================================================
-- External Table: stg_metadata_lookup_values
-- Points to staging metadata for panel pricing lookups
-- =============================================================================

IF EXISTS (SELECT * FROM sys.external_tables WHERE name = 'stg_metadata_lookup_values')
    DROP EXTERNAL TABLE [dbo].[stg_metadata_lookup_values];
GO

CREATE EXTERNAL TABLE [dbo].[stg_metadata_lookup_values]
(
    [LOOKUP_NAME]   NVARCHAR(100),
    [VALUE]         NVARCHAR(255),
    [TEXT]          NVARCHAR(255)
)
WITH (
    LOCATION = 'rwp/METADATA_LOOKUP_VALUES/**',
    DATA_SOURCE = adls_staging,
    FILE_FORMAT = parquet_format
);
GO

-- =============================================================================
-- Statistics on key filter columns (Synapse Serverless — no indexes)
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.stats WHERE name = 'stat_DateEnter' AND object_id = OBJECT_ID('dbo.fact_results_with_pricing'))
    CREATE STATISTICS stat_DateEnter ON dbo.fact_results_with_pricing (DateEnter) WITH FULLSCAN;
IF NOT EXISTS (SELECT 1 FROM sys.stats WHERE name = 'stat_HasPendingResults' AND object_id = OBJECT_ID('dbo.fact_results_with_pricing'))
    CREATE STATISTICS stat_HasPendingResults ON dbo.fact_results_with_pricing (HasPendingResults) WITH FULLSCAN;
IF NOT EXISTS (SELECT 1 FROM sys.stats WHERE name = 'stat_ORDNO' AND object_id = OBJECT_ID('dbo.fact_results_with_pricing'))
    CREATE STATISTICS stat_ORDNO ON dbo.fact_results_with_pricing (ORDNO) WITH FULLSCAN;
IF NOT EXISTS (SELECT 1 FROM sys.stats WHERE name = 'stat_COMPNAME' AND object_id = OBJECT_ID('dbo.fact_results_with_pricing'))
    CREATE STATISTICS stat_COMPNAME ON dbo.fact_results_with_pricing (COMPNAME) WITH FULLSCAN;
IF NOT EXISTS (SELECT 1 FROM sys.stats WHERE name = 'stat_ExternalId' AND object_id = OBJECT_ID('dbo.fact_results_with_pricing'))
    CREATE STATISTICS stat_ExternalId ON dbo.fact_results_with_pricing (ExternalId) WITH FULLSCAN;
IF NOT EXISTS (SELECT 1 FROM sys.stats WHERE name = 'stat_LatestResultDate' AND object_id = OBJECT_ID('dbo.fact_results_with_pricing'))
    CREATE STATISTICS stat_LatestResultDate ON dbo.fact_results_with_pricing (LatestResultDate) WITH FULLSCAN;
GO

-- =============================================================================
-- View: vw_ResultsWithPricing (full, with PII)
-- Uses OPENROWSET + filepath() for year+month partition elimination.
-- Queries MUST filter on _partition_year (and optionally _partition_month).
-- =============================================================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_ResultsWithPricing')
    DROP VIEW [dbo].[vw_ResultsWithPricing];
GO

CREATE VIEW [dbo].[vw_ResultsWithPricing] AS
SELECT
    f.BirthDate           AS BIRTH_DATE,
    f.ClientSampleId      AS CLIENT_SAMPLE_ID,
    f.DateCollected       AS DATE_COLLECTED,
    f.ExternalId          AS EXTERNAL_ID,
    f.FirstName           AS FIRST_NAME,
    f.LastName            AS LAST_NAME,
    f.SpecSource          AS SPEC_SOURCE,
    IIF(f.IsPanel = 1, pc.VALUE, f.ResolvedTestCode) AS TESTCODE,
    f.Category            AS CATEGORY,
    f.COMPNAME,
    f.DateEnter           AS DATEENTER,
    f.[Final]             AS FINAL,
    f.NumRes              AS NUMRES,
    f.RN2,
    IIF(f.IsPanel = 1, CAST(pp.PanelPrice AS DECIMAL(8,2)), f.Price) AS PRICE,
    f.PriceListId         AS PRICELISTID,
    f.ORDNO,
    f.[State]             AS STATE,
    f.City,
    f.Zip,
    f.CancelStatus        AS CANCEL_STATUS,
    f.Analyte,
    f.IsPanel,
    f.SourceTestCode,
    f.ResolvedTestCode,
    f.PricingMethod,
    f.LatestResultDate,
    CAST(f.filepath(1) AS INT) AS _partition_year,
    CAST(f.filepath(2) AS INT) AS _partition_month
FROM OPENROWSET(
    BULK 'rwp/fact_results_with_pricing/year=*/month=*/*.parquet',
    DATA_SOURCE = 'adls_datasource',
    FORMAT = 'PARQUET'
) AS f
LEFT JOIN (
    -- Panel test code: TEXT=TestGroupName -> VALUE=panel test code (numeric)
    SELECT DISTINCT [TEXT], CAST([VALUE] AS INT) AS VALUE
    FROM [dbo].[stg_metadata_lookup_values]
    WHERE LOOKUP_NAME = 'PanelPricing'
      AND TRY_CAST([VALUE] AS INT) IS NOT NULL
      AND TRY_CAST([TEXT] AS INT) IS NULL
) pc ON pc.[TEXT] = f.TestGroupName AND f.IsPanel = 1
LEFT JOIN (
    -- Panel price: VALUE=TestGroupName -> TEXT=panel price (decimal)
    SELECT DISTINCT [VALUE] AS PanelName, [TEXT] AS PanelPrice
    FROM [dbo].[stg_metadata_lookup_values]
    WHERE LOOKUP_NAME = 'PanelPricing'
      AND TRY_CAST([VALUE] AS INT) IS NULL
      AND TRY_CAST([TEXT] AS DECIMAL(8,2)) IS NOT NULL
) pp ON pp.PanelName = f.TestGroupName AND f.IsPanel = 1
WHERE f.HasPendingResults = 0
  AND IIF(f.IsPanel = 1, CAST(pp.PanelPrice AS DECIMAL(8,2)), f.Price) IS NOT NULL;
GO

-- =============================================================================
-- View: vw_ResultsWithPricingCFO (no PII: excludes BIRTH_DATE, CLIENT_SAMPLE_ID,
-- FIRST_NAME, LAST_NAME)
-- Uses OPENROWSET + filepath() for year+month partition elimination.
-- =============================================================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_ResultsWithPricingCFO')
    DROP VIEW [dbo].[vw_ResultsWithPricingCFO];
GO

CREATE VIEW [dbo].[vw_ResultsWithPricingCFO] AS
SELECT
    f.DateCollected       AS DATE_COLLECTED,
    f.ExternalId          AS EXTERNAL_ID,
    f.SpecSource          AS SPEC_SOURCE,
    IIF(f.IsPanel = 1, pc.VALUE, f.ResolvedTestCode) AS TESTCODE,
    f.Category            AS CATEGORY,
    f.COMPNAME,
    f.DateEnter           AS DATEENTER,
    f.[Final]             AS FINAL,
    f.NumRes              AS NUMRES,
    f.RN2,
    IIF(f.IsPanel = 1, CAST(pp.PanelPrice AS DECIMAL(8,2)), f.Price) AS PRICE,
    f.PriceListId         AS PRICELISTID,
    f.ORDNO,
    f.[State]             AS STATE,
    f.City,
    f.Zip,
    f.CancelStatus        AS CANCEL_STATUS,
    f.Analyte,
    f.IsPanel,
    f.SourceTestCode,
    f.ResolvedTestCode,
    f.PricingMethod,
    f.LatestResultDate,
    CAST(f.filepath(1) AS INT) AS _partition_year,
    CAST(f.filepath(2) AS INT) AS _partition_month
FROM OPENROWSET(
    BULK 'rwp/fact_results_with_pricing/year=*/month=*/*.parquet',
    DATA_SOURCE = 'adls_datasource',
    FORMAT = 'PARQUET'
) AS f
LEFT JOIN (
    SELECT DISTINCT [TEXT], CAST([VALUE] AS INT) AS VALUE
    FROM [dbo].[stg_metadata_lookup_values]
    WHERE LOOKUP_NAME = 'PanelPricing'
      AND TRY_CAST([VALUE] AS INT) IS NOT NULL
      AND TRY_CAST([TEXT] AS INT) IS NULL
) pc ON pc.[TEXT] = f.TestGroupName AND f.IsPanel = 1
LEFT JOIN (
    SELECT DISTINCT [VALUE] AS PanelName, [TEXT] AS PanelPrice
    FROM [dbo].[stg_metadata_lookup_values]
    WHERE LOOKUP_NAME = 'PanelPricing'
      AND TRY_CAST([VALUE] AS INT) IS NULL
      AND TRY_CAST([TEXT] AS DECIMAL(8,2)) IS NOT NULL
) pp ON pp.PanelName = f.TestGroupName AND f.IsPanel = 1
WHERE f.HasPendingResults = 0
  AND IIF(f.IsPanel = 1, CAST(pp.PanelPrice AS DECIMAL(8,2)), f.Price) IS NOT NULL;
GO
