-- ==============================================================================
-- SECTION 1: DATABASE, SCHEMA & WAREHOUSE SETUP
-- ==============================================================================

USE WAREHOUSE MY_COMPUTER_WH;
CREATE DATABASE IF NOT EXISTS MY_FIRST_DATA;
CREATE SCHEMA IF NOT EXISTS MY_FIRST_DATA.MY_SCHEMA;
USE SCHEMA MY_FIRST_DATA.MY_SCHEMA;


-- ==============================================================================
-- SECTION 2: FILE FORMAT & S3 STAGE CREATION
-- ==============================================================================

CREATE OR REPLACE FILE FORMAT US_DATA_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('NULL', 'null', '')
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

CREATE OR REPLACE STAGE MY_S3_STAGE
    URL = 's3://snowflake-accident-data-divyansh/'
    FILE_FORMAT = US_DATA_FORMAT;


-- ==============================================================================
-- SECTION 3: RAW LANDING TABLE & INITIAL INGESTION
-- ==============================================================================

CREATE OR REPLACE TABLE RAW_US_ACCIDENTS (
    ID VARCHAR, 
    Source VARCHAR, 
    Severity VARCHAR, 
    Start_Time VARCHAR, 
    End_Time VARCHAR, 
    Start_Lat VARCHAR, 
    Start_Lng VARCHAR, 
    City VARCHAR, 
    State VARCHAR, 
    Zipcode VARCHAR, 
    Weather_Condition VARCHAR
);

COPY INTO RAW_US_ACCIDENTS
FROM @MY_S3_STAGE/US_Accidents_March23.csv.gz
FILE_FORMAT = (FORMAT_NAME = 'US_DATA_FORMAT')
ON_ERROR = 'CONTINUE'
FORCE = TRUE;


-- ==============================================================================
-- SECTION 4: CLEAN LAYER (Data Cleaning, Null Handling & Type Casting)
-- ==============================================================================

CREATE OR REPLACE TABLE US_ACCIDENTS_CLEAN AS
SELECT 
    ID AS ACCIDENT_ID,
    COALESCE(Source, 'Unknown') AS SOURCE,
    TRY_CAST(Severity AS INT) AS SEVERITY,
    TRY_TO_TIMESTAMP(Start_Time) AS START_TIME,
    TRY_TO_TIMESTAMP(End_Time) AS END_TIME,
    TRY_CAST(Start_Lat AS FLOAT) AS START_LAT,
    TRY_CAST(Start_Lng AS FLOAT) AS START_LNG,
    COALESCE(City, 'Unknown') AS CITY,
    COALESCE(State, 'NA') AS STATE,
    Zipcode AS ZIPCODE,
    COALESCE(Weather_Condition, 'Clear/Unknown') AS WEATHER_CONDITION
FROM RAW_US_ACCIDENTS
WHERE ID IS NOT NULL;


-- ==============================================================================
-- SECTION 5: DATA MODELING (Star Schema: Fact & Dimensions)
-- ==============================================================================

-- Dimension Table 1: Location
CREATE OR REPLACE TABLE DIM_LOCATION AS
SELECT DISTINCT 
    MD5(CONCAT_WS('-', STATE, CITY, ZIPCODE)) AS LOCATION_ID,
    STATE, 
    CITY, 
    ZIPCODE
FROM US_ACCIDENTS_CLEAN;

-- Dimension Table 2: Weather
CREATE OR REPLACE TABLE DIM_WEATHER AS
SELECT DISTINCT 
    MD5(WEATHER_CONDITION) AS WEATHER_ID,
    WEATHER_CONDITION
FROM US_ACCIDENTS_CLEAN;

-- Fact Table: Accidents Metrics & Foreign Keys
CREATE OR REPLACE TABLE FACT_ACCIDENTS AS
SELECT 
    ACCIDENT_ID,
    MD5(CONCAT_WS('-', STATE, CITY, ZIPCODE)) AS LOCATION_ID,
    MD5(WEATHER_CONDITION) AS WEATHER_ID,
    SEVERITY, 
    START_TIME, 
    END_TIME, 
    START_LAT, 
    START_LNG
FROM US_ACCIDENTS_CLEAN;


-- ==============================================================================
-- SECTION 6: CHANGE DATA CAPTURE (Stream on Raw Table)
-- ==============================================================================

-- This stream monitors the RAW_US_ACCIDENTS table to track new incoming data inserts from S3
CREATE OR REPLACE STREAM US_ACCIDENTS_RAW_STREAM 
ON TABLE RAW_US_ACCIDENTS;


-- ==============================================================================
-- SECTION 7: PIPELINE AUTOMATION (Scheduled Task)
-- ==============================================================================

-- This task checks every 5 minutes if the stream has data, 
-- and automatically transforms and inserts the new records into the clean layer table
CREATE OR REPLACE TASK PROCESS_ACCIDENTS_TASK
    WAREHOUSE = MY_COMPUTER_WH
    SCHEDULE = '5 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('US_ACCIDENTS_RAW_STREAM')
AS
INSERT INTO US_ACCIDENTS_CLEAN
SELECT 
    ID AS ACCIDENT_ID,
    COALESCE(Source, 'Unknown') AS SOURCE,
    TRY_CAST(Severity AS INT) AS SEVERITY,
    TRY_TO_TIMESTAMP(Start_Time) AS START_TIME,
    TRY_TO_TIMESTAMP(End_Time) AS END_TIME,
    TRY_CAST(Start_Lat AS FLOAT) AS START_LAT,
    TRY_CAST(Start_Lng AS FLOAT) AS START_LNG,
    COALESCE(City, 'Unknown') AS CITY,
    COALESCE(State, 'NA') AS STATE,
    Zipcode AS ZIPCODE,
    COALESCE(Weather_Condition, 'Clear/Unknown') AS WEATHER_CONDITION
FROM US_ACCIDENTS_RAW_STREAM
WHERE METADATA$ACTION = 'INSERT';

-- Command to resume/start the scheduled task:
-- ALTER TASK PROCESS_ACCIDENTS_TASK RESUME;