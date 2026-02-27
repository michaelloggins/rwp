# RWP Data Model

## Source Tables (StarLIMS -> Staging)

These 9 tables are extracted from StarLIMS and landed in ADLS Gen2 as Parquet files.
Only the columns needed for RWP are extracted (not the full tables).

---

### RESULTS (~2.8M rows, incremental load)
The core transaction table. One row per test result.

| Column     | Type        | Role                                        |
|------------|-------------|---------------------------------------------|
| FOLDERNO   | INT         | FK to FOLDERS -- links result to its folder |
| ORDNO      | INT         | Order number -- part of the grain           |
| TESTCODE   | INT         | Test performed (may need remapping)         |
| ANALYTE    | NVARCHAR    | What was tested for                         |
| FINAL      | NVARCHAR    | Final result value                          |
| NUMRES     | NVARCHAR    | Numeric result (also used for filtering)    |
| RN2        | NVARCHAR    | Result note 2                               |
| RN3        | NVARCHAR    | Result note 3 ('C' = cancelled)             |
| S          | NVARCHAR    | Status ('Cancel', 'Logged', 'Draft', etc.)  |
| DATEENTER  | DATETIME    | When result was entered (drives pricing)    |

**Filters applied:** NUMRES NOT IN ('QNS','C','U'), TESTCODE NOT IN (432,429,443,440)

---

### FOLDERS (medium, full load)
Groups results into folders tied to a sample/order.

| Column        | Type        | Role                                      |
|---------------|-------------|-------------------------------------------|
| FOLDERNO      | INT         | PK -- joins to RESULTS.FOLDERNO          |
| EXTERNAL_ID   | NVARCHAR    | FK to CENTRALRECEIVING -- links to sample |
| TESTGROUPNAME | NVARCHAR    | Test group (used for panel detection)     |

---

### CENTRALRECEIVING (medium, full load)
Sample intake records. Contains patient/sample PII.

| Column           | Type        | Role                                   |
|------------------|-------------|----------------------------------------|
| EXTERNAL_ID      | NVARCHAR    | PK -- joins from FOLDERS               |
| RASCLIENTID      | NVARCHAR    | FK to RASCLIENTS -- which client sent it|
| BIRTH_DATE       | DATETIME    | Patient DOB (PII)                      |
| CLIENT_SAMPLE_ID | NVARCHAR    | Client's sample ID (PII)               |
| FIRST_NAME       | NVARCHAR    | Patient first name (PII)               |
| LAST_NAME        | NVARCHAR    | Patient last name (PII)                |
| DATE_COLLECTED   | DATETIME    | When sample was collected               |
| SPEC_SOURCE      | NVARCHAR    | Specimen source                        |

---

### RASCLIENTS (small, full load)
Client (company) master data. Assigns each client to a price list.

| Column      | Type        | Role                                        |
|-------------|-------------|---------------------------------------------|
| RASCLIENTID | NVARCHAR(30)| PK -- joins from CENTRALRECEIVING           |
| COMPNAME    | VARCHAR(255)| Company name -- part of the grain            |
| CATEGORY    | NVARCHAR    | Client category (filter: exclude 'Internal') |
| STATE       | NVARCHAR    | Client state                                 |
| CITY        | NVARCHAR    | Client city                                  |
| ZIP         | NVARCHAR    | Client zip code                              |
| PRICELISTID | NVARCHAR(15)| Which price list this client uses            |

**Filters applied:** COMPNAME NOT LIKE 'zzz%', NOT IN excluded list, CATEGORY <> 'Internal'

---

### TESTGROUPNAMES (small, full load)
Maps test group names to panel flags.

| Column        | Type     | Role                                    |
|---------------|----------|-----------------------------------------|
| TESTGROUPNAME | NVARCHAR | PK -- joins from FOLDERS.TESTGROUPNAME |
| TESTPANEL     | NVARCHAR | 'Y' if this group is a panel           |

---

### TESTS (small, full load)
Test code master data. Used for test code resolution.

| Column          | Type     | Role                                             |
|-----------------|----------|--------------------------------------------------|
| TESTNO          | NVARCHAR | PK -- joins from TESTGROUPNAMES.TESTGROUPNAME   |
| TESTCODE        | NVARCHAR | Current test code                                |
| LEGACY_TESTCODE | NVARCHAR | Legacy code used for price lookup                |

---

### RASPRICELIST (small, full load -- 176 rows)
Price list versions. Each price list has multiple versions over time.

| Column           | Type        | Role                                          |
|------------------|-------------|-----------------------------------------------|
| PRICELISTID      | NVARCHAR(15)| PK part 1 -- which price list                |
| PRICELISTVERSION | INT         | PK part 2 -- version number                  |
| STARTDDATE       | DATETIME    | When this version became effective            |
| STATUS           | NVARCHAR    | 'Released' or 'Retired' (IGNORED by new ETL) |

---

### RASTESTPRICES (small, full load -- 4,681 rows)
The actual prices. Maps (price list, version, test code) -> price.

| Column           | Type         | Role                               |
|------------------|--------------|-------------------------------------|
| PRICELISTID      | NVARCHAR(15) | PK part 1 -- which price list      |
| PRICELISTVERSION | INT          | PK part 2 -- which version         |
| TESTCODE         | INT          | PK part 3 -- which test            |
| PRICE            | NUMERIC(8,2) | The dollar amount                  |

(SP_CODE = 670 on all rows, ignored)

---

### METADATA_LOOKUP_VALUES (small, full load -- 54 rows for PanelPricing)
Panel pricing stored as key-value pairs. Dual-row pattern:

| Column      | Type     | Role                                              |
|-------------|----------|----------------------------------------------------|
| LOOKUP_NAME | NVARCHAR | Always 'PanelPricing' (filtered during extraction) |
| VALUE       | NVARCHAR | Either a numeric code OR a panel name              |
| TEXT        | NVARCHAR | Either a panel name OR a price                     |

**How it works:**
- Row A: VALUE = '401', TEXT = 'Histo Panel' (code -> name)
- Row B: VALUE = 'Histo Panel', TEXT = '150.00' (name -> price)
- Lookup: code 401 -> 'Histo Panel' -> $150.00

---

## Join Relationships (How the tables connect)

```
RESULTS
  |
  |-- FOLDERNO --> FOLDERS
  |                  |
  |                  |-- EXTERNAL_ID --> CENTRALRECEIVING
  |                  |                        |
  |                  |                        |-- RASCLIENTID --> RASCLIENTS
  |                  |                                             |
  |                  |                                             |-- PRICELISTID --+
  |                  |                                                              |
  |                  |-- TESTGROUPNAME --> TESTGROUPNAMES                           |
  |                                         |                                      |
  |                                         |-- TESTGROUPNAME --> TESTS            |
  |                                                (as TESTNO)                     |
  |                                                                                |
  +-- TESTCODE (resolved) ---------+                                               |
                                   |                                               |
                                   +--------> RASTESTPRICES <----------------------+
                                                   |       (PRICELISTID + TESTCODE
                                                   |        + PRICELISTVERSION)
                                                   |
                                              RASPRICELIST
                                              (point-in-time version
                                               via STARTDDATE <= DATEENTER)

  Panel tests take a different path:
  TESTGROUPNAME --> METADATA_LOOKUP_VALUES (code->name->price)
```

---

## Output: Fact Table (Gold Zone)

**`fact_results_with_pricing`** -- Parquet in ADLS, partitioned by year(DateEnter)

Grain: one row per (ORDNO, COMPNAME) -- an order at a company.

| Column            | Type          | Source                          | Description                          |
|-------------------|---------------|---------------------------------|--------------------------------------|
| **Ordno**         | INT           | RESULTS.ORDNO                   | Order number (grain)                 |
| **CompName**      | VARCHAR(255)  | RASCLIENTS.COMPNAME             | Company name (grain)                 |
| ExternalId        | NVARCHAR(50)  | CENTRALRECEIVING.EXTERNAL_ID    | Sample external ID                   |
| BirthDate         | DATETIME2     | CENTRALRECEIVING.BIRTH_DATE     | Patient DOB (PII)                    |
| ClientSampleId    | NVARCHAR(100) | CENTRALRECEIVING.CLIENT_SAMPLE_ID| Client sample ID (PII)              |
| FirstName         | NVARCHAR(100) | CENTRALRECEIVING.FIRST_NAME     | Patient first name (PII)             |
| LastName          | NVARCHAR(100) | CENTRALRECEIVING.LAST_NAME      | Patient last name (PII)              |
| DateCollected     | DATETIME2     | CENTRALRECEIVING.DATE_COLLECTED | When sample was collected             |
| SpecSource        | NVARCHAR(100) | CENTRALRECEIVING.SPEC_SOURCE    | Specimen source                      |
| DateEnter         | DATETIME2     | MAX(RESULTS.DATEENTER)          | Latest result entry date (drives pricing + partition) |
| SourceTestCode    | INT           | RESULTS.TESTCODE                | Original test code before remapping  |
| ResolvedTestCode  | INT           | Derived                         | After mapping (318->316, etc.)       |
| TestGroupName     | NVARCHAR(50)  | FOLDERS.TESTGROUPNAME           | Test group                           |
| IsPanel           | BIT           | Derived                         | 1 = panel test                       |
| Analyte           | NVARCHAR(100) | RESULTS.ANALYTE                 | What was tested for                  |
| Final             | NVARCHAR(100) | RESULTS.FINAL                   | Final result value                   |
| NumRes            | NVARCHAR(50)  | RESULTS.NUMRES                  | Numeric result                       |
| RN2               | NVARCHAR(50)  | RESULTS.RN2                     | Result note 2                        |
| CancelStatus      | VARCHAR(10)   | Derived                         | 'Cancel' or ''                       |
| HasPendingResults | BIT           | Derived                         | 1 = folder still has Logged/Draft results |
| **Price**         | DECIMAL(8,2)  | RASTESTPRICES or METADATA       | **Point-in-time resolved price**     |
| PriceListId       | NVARCHAR(15)  | RASCLIENTS.PRICELISTID          | Which price list was used            |
| PriceListVersion  | INT           | Derived                         | Which version was matched            |
| PricingMethod     | VARCHAR(10)   | Derived                         | 'TEST' or 'PANEL'                   |
| Category          | NVARCHAR(255) | RASCLIENTS.CATEGORY             | Client category                      |
| State             | NVARCHAR(80)  | RASCLIENTS.STATE                | Client state                         |
| City              | NVARCHAR(200) | RASCLIENTS.CITY                 | Client city                          |
| Zip               | NVARCHAR(15)  | RASCLIENTS.ZIP                  | Client zip                           |
| ETL_LoadDate      | DATETIME2     | System                          | When this row was loaded             |

---

## Semantic Model (Views)

Two views sit on top of the single fact table, served by Synapse Serverless:

```
                    fact_results_with_pricing
                    (Parquet in ADLS Gen2)
                              |
                   +----------+----------+
                   |                     |
        vw_ResultsWithPricing   vw_ResultsWithPricingCFO
           (ALL columns)          (NO PII columns)
                   |                     |
              Azure Function         Azure Function
          ReportType = 'RWP'     ReportType = 'RWPCFO'
```

### vw_ResultsWithPricing (full, with PII)
All columns from the fact table, filtered to `HasPendingResults = 0`.

### vw_ResultsWithPricingCFO (no PII)
Same as above but **excludes**: BirthDate, ClientSampleId, FirstName, LastName.

Both views are queried with a simple:
```sql
SELECT * FROM <view> WHERE DateEnter BETWEEN @start AND @end ORDER BY CompName, Ordno
```
