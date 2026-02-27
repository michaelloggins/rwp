-- =============================================================================
-- Validation Queries: Compare Old SP Output vs New Pipeline Output
-- Run these against both systems for a known date range to verify correctness
-- =============================================================================

-- =============================================================================
-- STEP 1: Generate old SP output for a test window
-- Run on StarLIMS (MIRALIMSPRDDB02\PRDLIMSSQL2019, DB: STARLIMS_DATA)
-- =============================================================================

-- Choose a date range that spans a known price list version change for best coverage
DECLARE @CalDate DATETIME = '2025-01-01';
DECLARE @CalEnd  DATETIME = '2025-01-31';

-- Capture old SP output into a temp table for comparison
EXEC sp_ResultsWithPricing @CalDate, @CalEnd;
-- (save results to a file or staging table for comparison)


-- =============================================================================
-- STEP 2: Query new pipeline output for the same window
-- Run on Synapse Serverless (rwp_analytics database)
-- =============================================================================

/*
SELECT *
FROM dbo.vw_ResultsWithPricing
WHERE DateEnter >= '2025-01-01' AND DateEnter <= '2025-01-31'
ORDER BY CompName, Ordno;
*/


-- =============================================================================
-- STEP 3: Row Count Comparison
-- =============================================================================

-- Old SP row count (run on StarLIMS after executing SP):
-- SELECT COUNT(*) AS OldRowCount FROM #ResultsTemp;

-- New pipeline row count (run on Synapse):
/*
SELECT COUNT(*) AS NewRowCount
FROM dbo.vw_ResultsWithPricing
WHERE DateEnter >= '2025-01-01' AND DateEnter <= '2025-01-31';
*/


-- =============================================================================
-- STEP 4: Price Comparison (THE CRITICAL CHECK)
-- Load both outputs into a comparison environment (e.g., Synapse staging tables)
-- =============================================================================

/*
-- Assuming old SP results are loaded into [staging].[old_rwp_output]
-- and new pipeline is in dbo.vw_ResultsWithPricing

-- Find rows where prices differ
SELECT
    o.ORDNO,
    o.CompName,
    o.TESTCODE,
    o.DATEENTER,
    o.PRICE          AS OldPrice,
    n.Price          AS NewPrice,
    o.PRICELISTID,
    n.PricingMethod,
    n.PriceListVersion AS NewPriceListVersion,
    ABS(ISNULL(o.PRICE, 0) - ISNULL(n.Price, 0)) AS PriceDiff
FROM [staging].[old_rwp_output] o
FULL OUTER JOIN dbo.vw_ResultsWithPricing n
    ON o.ORDNO = n.Ordno
    AND o.CompName = n.CompName
WHERE n.DateEnter >= '2025-01-01' AND n.DateEnter <= '2025-01-31'
    AND (
        ISNULL(o.PRICE, -1) <> ISNULL(n.Price, -1)
        OR o.ORDNO IS NULL   -- in new but not old
        OR n.Ordno IS NULL   -- in old but not new
    )
ORDER BY ABS(ISNULL(o.PRICE, 0) - ISNULL(n.Price, 0)) DESC;
*/


-- =============================================================================
-- STEP 5: Column-by-Column Spot Checks
-- =============================================================================

/*
-- TESTCODE resolution check
SELECT
    o.ORDNO,
    o.TESTCODE AS OldTestCode,
    n.TESTCODE AS NewTestCode
FROM [staging].[old_rwp_output] o
JOIN dbo.vw_ResultsWithPricing n
    ON o.ORDNO = n.Ordno AND o.CompName = n.CompName
WHERE n.DateEnter >= '2025-01-01' AND n.DateEnter <= '2025-01-31'
    AND o.TESTCODE <> n.TESTCODE;

-- CancelStatus check
SELECT
    o.ORDNO,
    o.CANCEL_STATUS AS OldCancelStatus,
    n.CANCEL_STATUS AS NewCancelStatus
FROM [staging].[old_rwp_output] o
JOIN dbo.vw_ResultsWithPricing n
    ON o.ORDNO = n.Ordno AND o.CompName = n.CompName
WHERE n.DateEnter >= '2025-01-01' AND n.DateEnter <= '2025-01-31'
    AND ISNULL(o.CANCEL_STATUS, '') <> ISNULL(n.CANCEL_STATUS, '');

-- PII fields check (RWP vs RWPCFO)
SELECT
    COUNT(*) AS CFO_Rows_With_PII_Leak
FROM dbo.vw_ResultsWithPricingCFO
WHERE BirthDate IS NOT NULL
   OR FirstName IS NOT NULL
   OR LastName IS NOT NULL
   OR ClientSampleId IS NOT NULL;
-- Should return 0 (these columns don't exist in CFO view)
*/


-- =============================================================================
-- STEP 6: Panel Pricing Verification
-- =============================================================================

/*
-- Check that panel tests get prices from METADATA_LOOKUP_VALUES (flat pricing)
SELECT
    n.Ordno,
    n.CompName,
    n.TESTCODE,
    n.Price,
    n.PricingMethod,
    n.IsPanel
FROM dbo.vw_ResultsWithPricing n
WHERE n.DateEnter >= '2025-01-01' AND n.DateEnter <= '2025-01-31'
    AND n.IsPanel = 1
ORDER BY n.CompName, n.Ordno;

-- Cross-reference against METADATA_LOOKUP_VALUES
-- (run on StarLIMS)
SELECT mlv_code.VALUE AS PanelCode, mlv_code.TEXT AS PanelName,
       mlv_price.TEXT AS ExpectedPrice
FROM METADATA_LOOKUP_VALUES mlv_code
JOIN METADATA_LOOKUP_VALUES mlv_price
    ON mlv_code.TEXT = mlv_price.VALUE
    AND mlv_price.LOOKUP_NAME = 'PanelPricing'
WHERE mlv_code.LOOKUP_NAME = 'PanelPricing'
    AND ISNUMERIC(mlv_code.VALUE) = 1;
*/


-- =============================================================================
-- STEP 7: Edge Case Checks
-- =============================================================================

/*
-- Results on exact STARTDDATE boundary
SELECT n.Ordno, n.DateEnter, n.Price, n.PriceListId, n.PriceListVersion
FROM dbo.fact_results_with_pricing n
JOIN (
    -- Find results entered on the exact date a price version started
    SELECT DISTINCT pl.STARTDDATE
    FROM RASPRICELIST pl
) boundary ON CAST(n.DateEnter AS DATE) = CAST(boundary.STARTDDATE AS DATE)
WHERE n.DateEnter >= '2020-01-01';

-- Results with NULL prices (no matching price list version)
SELECT n.Ordno, n.CompName, n.TESTCODE, n.DateEnter, n.PriceListId, n.PricingMethod
FROM dbo.vw_ResultsWithPricing n
WHERE n.Price IS NULL
    AND n.DateEnter >= '2025-01-01' AND n.DateEnter <= '2025-01-31'
ORDER BY n.CompName;

-- Aggregation correctness: orders with multiple test codes
SELECT n.Ordno, n.CompName, COUNT(*) AS ResultCount
FROM dbo.fact_results_with_pricing n
WHERE n.DateEnter >= '2025-01-01' AND n.DateEnter <= '2025-01-31'
GROUP BY n.Ordno, n.CompName
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;
*/


-- =============================================================================
-- STEP 8: Point-in-Time Pricing Verification
-- Verify the fix: results that span a price change should show the OLD price
-- =============================================================================

/*
-- Find a price list that had a version change during our test window
-- (run on StarLIMS)
SELECT pl.PRICELISTID, pl.PRICELISTVERSION, pl.STARTDDATE, pl.STATUS
FROM RASPRICELIST pl
WHERE pl.STARTDDATE BETWEEN '2024-01-01' AND '2025-12-31'
ORDER BY pl.PRICELISTID, pl.PRICELISTVERSION;

-- For a specific price list that changed, compare prices for results before/after
-- the change date. The OLD SP would show the CURRENT price for both;
-- the NEW pipeline should show the correct historical price.
*/


-- =============================================================================
-- STEP 9: HasPendingResults Flag Validation
-- =============================================================================

/*
-- Verify that orders with pending results are excluded from views
-- but present in the fact table
SELECT
    (SELECT COUNT(*) FROM dbo.fact_results_with_pricing WHERE HasPendingResults = 1) AS PendingInFact,
    (SELECT COUNT(*) FROM dbo.vw_ResultsWithPricing) AS RowsInView,
    (SELECT COUNT(*) FROM dbo.fact_results_with_pricing) AS TotalInFact;

-- The view count should be less than or equal to the fact table count
*/
