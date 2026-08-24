# US Accidents Data Engineering & Analytics Pipeline

An end-to-end ELT data pipeline built using **Snowflake Data Warehouse**, **AWS S3**, and **Snowpark Python**, designed to process and analyze over **7.7 million US accident records**. The project implements a modern data stack approach covering raw ingestion, data cleaning, star schema dimensional modeling, automated Change Data Capture (CDC), and an interactive analytics dashboard.

---

## Architecture & Data Flow

```text
[AWS S3 Bucket] 
      │ (CSV Ingestion)
      ▼
[Snowflake: RAW_US_ACCIDENTS] (Landing Layer)
      │
      ▼
[Snowflake: US_ACCIDENTS_CLEAN] (Cleansing & Type Casting)
      │
      ├──► [DIM_LOCATION] (Dimension Table)
      ├──► [DIM_WEATHER]  (Dimension Table)
      └──► [FACT_ACCIDENTS] (Fact Table with MD5 Surrogate Keys)
      │
      ▼
[Streams & Tasks] (Automated Incremental Pipeline / CDC)
      │
      ▼
[Streamlit in Snowflake] (Interactive Analytics UI)
Technical Stack
Cloud Data Warehouse: Snowflake (Warehouses, Stages, File Formats)

Data Transformation & Modeling: SQL, Star Schema (Fact & Dimension Tables)

Automation & CDC: Snowflake Streams and scheduled Tasks

Application & Visualization: Streamlit in Snowflake (SiS), Snowpark Python, Pandas

Pipeline Execution Steps
Ingestion: Raw CSV datasets are staged from an AWS S3 bucket and loaded into a flat landing table (RAW_US_ACCIDENTS) using Snowflake's bulk copy command.

Cleansing & Standardization: Handled missing values using COALESCE, standardized timestamps (TRY_TO_TIMESTAMP), and cast data types safely (TRY_CAST) to filter out corrupted rows.

Dimensional Modeling (Star Schema):

DIM_LOCATION: Unique geographical locations normalized with MD5 surrogate keys (LOCATION_ID).

DIM_WEATHER: Normalized weather conditions mapped with MD5 keys (WEATHER_ID).

FACT_ACCIDENTS: Core transactional fact table containing metrics, severity, timestamps, and foreign keys.

Automation & CDC: Implemented a Snowflake STREAM on the raw table to track incremental insertions, orchestrated by a recurring 5-minute TASK for automated transformation.

Consumption Layer: A real-time Streamlit dashboard connected via Snowpark session context (get_active_session()) for live analytical filtering and metrics reporting.