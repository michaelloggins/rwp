SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Sean O'Connell
-- Create date: 08/1/2022
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[sp_ResultsWithPricingCFO] 
	-- Add the parameters for the stored procedure here
	@CalDate datetime,
	@CalEnd datetime
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
(Select  r.ANALYTE, cr.DATE_COLLECTED, cr.EXTERNAL_ID, cr.SPEC_SOURCE,
   rc.CATEGORY, rc.COMPNAME, r.DATEENTER, r.FINAL, r.NUMRES, r.RN2, 
   		CASE
			WHEN r.TESTCODE = '318' THEN '316'
			WHEN 1=1 THEN te.legacy_testcode
		END  AS TESTCODE 
   , rc.PRICELISTID, rtp.PRICE, r.ordno
   --, ra.ORDNO as raprdno
   --, ra.mycomment
   --, ra.rep
  --, ra.ATTACHMENT_SCOPE
  into #Mytemptable
   from CENTRALRECEIVING CR
left join RASCLIENTS RC on CR.RASCLIENTID = RC.RASCLIENTID
left join FOLDERS F on f.EXTERNAL_ID = cr.EXTERNAL_ID
left join TESTGROUPNAMES tn ON f.TESTGROUPNAME = tn.TESTGROUPNAME
left JOIN TESTS t ON tn.TESTGROUPNAME = t.TESTNO
left join RESULTS R on f.FOLDERNO = r.FOLDERNO
left JOIN TESTS te on r.TESTCODE = te.TESTCODE
left join RASTESTPRICES RTP on rtp.PRICELISTID = rc.PRICELISTID and rtp.TESTCODE = iif(t.TESTNO IS NULL OR t.TESTCODE = '', r.TESTCODE, t.TESTCODE)
left join RASPRICELIST p on rtp.PRICELISTID = p.PRICELISTID and rtp.PRICELISTVERSION = p.PRICELISTVERSION
where (r.DATEENTER BETWEEN  @CalDate AND @CalEnd) and rc.COMPNAME not in ('Test RightFax 2','Test RightFax 1', 'Test RightFax 4', 'ACCL0933', 'RESEARCH ONLY', 'MiraVista Quality System', 'Greater Than', 'Additional Positive Unconfirmed', 'ZZZ%')
and r.NUMRES not in ('QNS', 'U', 'C') 
and rc.COMPNAME like 'Santa Clara%' and r.TESTCODE = 315 and UPPER(p.STATUS) = 'RELEASED'  AND r.TESTCODE NOT IN (432,429,443,440))
	   
	SELECT DISTINCT
    MIN(cr.DATE_COLLECTED)       AS DATE_COLLECTED,
    MIN(cr.EXTERNAL_ID)          AS EXTERNAL_ID,
    MIN(cr.SPEC_SOURCE)          AS SPEC_SOURCE,
   IIF(
    MIN(f.TESTGROUPNAME) LIKE '%panel%',
    (SELECT MIN(nd.value)
     WHERE min(nd.[text]) = MIN(f.testgroupname)),
    CASE 
        WHEN MIN(t.TESTNO) IS NULL OR MIN(t.TESTCODE) = '' THEN
            CASE MIN(r.TESTCODE)
                WHEN '318' THEN '316'
                WHEN '457' THEN '331'
                WHEN '465' THEN '402'
                WHEN '459' THEN '332'
                WHEN '460' THEN '315'
                WHEN '461' THEN '316'
                WHEN '462' THEN '320'
                WHEN '463' THEN '321'
                WHEN '467' THEN '403'
                WHEN '469' THEN '404'
                WHEN '466' THEN '405'
                WHEN '468' THEN '406'
                ELSE MIN(r.TESTCODE)
            END
        ELSE MIN(t.legacy_testcode)
    END
    ) AS TESTCODE,
    MIN(rc.CATEGORY)             AS CATEGORY,
    rc.COMPNAME,
    MAX(r.DATEENTER)             AS DATEENTER,      -- max among in-range rows only
    MIN(r.FINAL)                 AS FINAL,
    MIN(r.NUMRES)                AS NUMRES,
    MIN(r.RN2)                   AS RN2,
    IIF(
        MIN(f.TESTGROUPNAME) LIKE '%panel%',
        (SELECT MIN(md.text) WHERE MIN(md.value) = MIN(f.testgroupname)),
        MIN(rtp.PRICE)
    ) AS PRICE,
    MIN(rc.PRICELISTID)          AS PRICELISTID,
    r.ordno                      AS ORDNO,
    MIN(rc.STATE)                AS STATE,
    MIN(rc.CITY)                 AS CITY,
    MIN(rc.ZIP)                  AS ZIP,
    IIF(MIN(r.S) = 'Cancel', MIN(r.S), IIF(MIN(r.RN3) = 'C', 'Cancel', ' ')) AS CANCEL_STATUS
into #ResultsTemp 
FROM CENTRALRECEIVING CR
LEFT JOIN RASCLIENTS RC
    ON CR.RASCLIENTID = RC.RASCLIENTID
LEFT JOIN FOLDERS F
    ON f.EXTERNAL_ID = cr.EXTERNAL_ID
LEFT JOIN TESTGROUPNAMES tn
    ON f.TESTGROUPNAME = tn.TESTGROUPNAME
LEFT JOIN METADATA_LOOKUP_VALUES md
    ON md.VALUE = f.TESTGROUPNAME
LEFT JOIN METADATA_LOOKUP_VALUES nd
    ON nd.text = f.TESTGROUPNAME
LEFT JOIN TESTS t
    ON tn.TESTGROUPNAME = t.TESTNO
LEFT JOIN RESULTS R
    ON f.FOLDERNO = r.FOLDERNO
LEFT JOIN RASTESTPRICES RTP
    ON rtp.PRICELISTID = rc.PRICELISTID
   AND rtp.TESTCODE   = IIF(t.TESTNO IS NULL OR t.TESTCODE = '', r.TESTCODE, t.TESTCODE)
LEFT JOIN RASPRICELIST p
    ON rtp.PRICELISTID      = p.PRICELISTID
   AND rtp.PRICELISTVERSION = p.PRICELISTVERSION
WHERE
    -- Half-open window: in-range rows only participate in aggregates
    r.DATEENTER >= @CalDate
    AND r.DATEENTER <=  @CalEnd
    AND rc.COMPNAME NOT LIKE 'zzz%'
    AND rc.COMPNAME NOT IN (
        'Test RightFax 2', 'Test RightFax 1', 'Test RightFax 4',
        'ACCL0933', 'RESEARCH ONLY', 'MiraVista Quality System',
        'Greater Than', 'Additional Positive Unconfirmed'
    )
    AND r.numres NOT IN ('QNS', 'C', 'U')
    AND r.S <> 'Cancel'
    AND rc.CATEGORY <> 'Internal'
    AND rc.COMPNAME NOT LIKE 'RESEARCH ONLY%'
    AND UPPER(p.STATUS) = 'RELEASED'
    AND r.TESTCODE NOT IN (432, 429, 443, 440)
    -- Exclude ORDNOs that have ANY result after the window (allow pre-window results)
    AND NOT EXISTS (
        SELECT 1
        FROM RESULTS r_all
        JOIN FOLDERS f_all ON f_all.FOLDERNO = r_all.FOLDERNO
        WHERE r_all.ORDNO = r.ORDNO
          AND r_all.DATEENTER > @CalEnd
    )
    -- Exclude folders that still have Logged/Draft results
    AND NOT EXISTS (
        SELECT 1
        FROM RESULTS res
        WHERE res.FOLDERNO = r.FOLDERNO
          AND res.S IN ('Logged', 'Draft')
    )
GROUP BY r.ORDNO, rc.COMPNAME
ORDER BY rc.compname;

Select * from #ResultsTemp
where not exists 
(Select * from #Mytemptable
where #ResultsTemp.EXTERNAL_ID = #Mytemptable.EXTERNAL_ID)


END
GO
