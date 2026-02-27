-- =============================================================================
-- Synapse Serverless SQL Pool: External Table and Views for RWP
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
    [Ordno]             INT,
    [CompName]          VARCHAR(255),
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
    [ETL_LoadDate]      DATETIME2
)
WITH (
    LOCATION = 'rwp/fact_results_with_pricing/**',
    DATA_SOURCE = adls_datasource,
    FILE_FORMAT = parquet_format
);
GO

-- =============================================================================
-- View: vw_ResultsWithPricing (full, with PII)
-- Matches the output of the original sp_ResultsWithPricing
-- =============================================================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_ResultsWithPricing')
    DROP VIEW [dbo].[vw_ResultsWithPricing];
GO

CREATE VIEW [dbo].[vw_ResultsWithPricing] AS
SELECT
    Ordno,
    ExternalId,
    BirthDate,
    ClientSampleId,
    FirstName,
    LastName,
    DateCollected,
    SpecSource,
    DateEnter,
    ResolvedTestCode    AS TESTCODE,
    Analyte,
    [Final],
    NumRes,
    RN2,
    CancelStatus        AS CANCEL_STATUS,
    Price,
    PriceListId         AS PRICELISTID,
    CompName,
    Category,
    [State],
    City,
    Zip,
    IsPanel,
    PricingMethod
FROM [dbo].[fact_results_with_pricing]
WHERE HasPendingResults = 0;
GO

-- =============================================================================
-- View: vw_ResultsWithPricingCFO (no PII)
-- Matches the output of the original sp_ResultsWithPricingCFO
-- =============================================================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_ResultsWithPricingCFO')
    DROP VIEW [dbo].[vw_ResultsWithPricingCFO];
GO

CREATE VIEW [dbo].[vw_ResultsWithPricingCFO] AS
SELECT
    Ordno,
    ExternalId,
    DateCollected,
    SpecSource,
    DateEnter,
    ResolvedTestCode    AS TESTCODE,
    Analyte,
    [Final],
    NumRes,
    RN2,
    CancelStatus        AS CANCEL_STATUS,
    Price,
    PriceListId         AS PRICELISTID,
    CompName,
    Category,
    [State],
    City,
    Zip,
    IsPanel,
    PricingMethod
FROM [dbo].[fact_results_with_pricing]
WHERE HasPendingResults = 0;
GO
