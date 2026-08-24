# ==============================================================================
# SECTION 1: IMPORTS AND PAGE CONFIGURATION
# ==============================================================================

import streamlit as st
from snowflake.snowpark.context import get_active_session

# Set up the wide layout and title for the Streamlit dashboard app
st.set_page_config(
    page_title="US Accidents ETL Dashboard", 
    layout="wide"
)

st.title("🚗 US Accidents Data Engineering & Analytics Dashboard")
st.write("Live data connection with Snowflake Data Warehouse")


# ==============================================================================
# SECTION 2: SNOWFLAKE SESSION & DATABASE PATH CONNECTION SETUP
# ==============================================================================

# Get the active Snowflake Snowpark session linked with the warehouse
session = get_active_session()

# Define the target Database and Schema path where clean and model tables reside
DB_PATH = "MY_FIRST_DATA.MY_SCHEMA."


# ==============================================================================
# SECTION 3: SIDEBAR FILTERS
# ==============================================================================

# Create a sidebar header for user interaction filters
st.sidebar.header("🔍 Filter Options")

# Fetch distinct state list from the Dimension Location table to populate the dropdown
states_df = session.sql(
    f"SELECT DISTINCT State FROM {DB_PATH}DIM_LOCATION WHERE State IS NOT NULL ORDER BY State"
).to_pandas()

state_list = ["All States"] + list(states_df["STATE"].dropna())

# Create a selectbox filter for choosing a specific state
selected_state = st.sidebar.selectbox("Select State:", state_list)


# ==============================================================================
# SECTION 4: DYNAMIC SQL FILTER CONDITIONS
# ==============================================================================

# Set WHERE clauses dynamically based on the state selected by the user
if selected_state != "All States":
    where_loc = f"WHERE State = '{selected_state}'"
    where_fact = f"WHERE Location_ID IN (SELECT Location_ID FROM {DB_PATH}DIM_LOCATION WHERE State = '{selected_state}')"
else:
    where_loc = ""
    where_fact = ""


# ==============================================================================
# SECTION 5: METRICS KPI CARDS
# ==============================================================================

# Display high-level performance metrics using columns layout
col1, col2, col3 = st.columns(3)

col1.metric(
    "Total Accidents", 
    f"{session.sql(f'SELECT COUNT(*) FROM {DB_PATH}FACT_ACCIDENTS {where_fact}').collect()[0][0]:,}"
)

col2.metric(
    "Total Locations", 
    f"{session.sql(f'SELECT COUNT(*) FROM {DB_PATH}DIM_LOCATION {where_loc}').collect()[0][0]:,}"
)

col3.metric(
    "Weather Conditions", 
    session.sql(f'SELECT COUNT(*) FROM {DB_PATH}DIM_WEATHER').collect()[0][0]
)

st.divider()


# ==============================================================================
# SECTION 6: DYNAMIC BAR CHART VISUALIZATION
# ==============================================================================

# Render top states or top cities chart based on the user's state selection
if selected_state == "All States":
    st.subheader("📍 Top 10 States by Accident Count")
    df_chart = session.sql(f"""
        SELECT State, COUNT(*) as ACCIDENT_COUNT 
        FROM {DB_PATH}DIM_LOCATION 
        GROUP BY State 
        ORDER BY ACCIDENT_COUNT DESC 
        LIMIT 10
    """).to_pandas()
    st.bar_chart(data=df_chart, x="STATE", y="ACCIDENT_COUNT", use_container_width=True)
else:
    st.subheader(f"📍 Top 10 Cities in {selected_state}")
    df_chart = session.sql(f"""
        SELECT City, COUNT(*) as ACCIDENT_COUNT 
        FROM {DB_PATH}DIM_LOCATION 
        WHERE State = '{selected_state}'
        GROUP BY City 
        ORDER BY ACCIDENT_COUNT DESC 
        LIMIT 10
    """).to_pandas()
    st.bar_chart(data=df_chart, x="CITY", y="ACCIDENT_COUNT", use_container_width=True)


# ==============================================================================
# SECTION 7: DATA TABLES PREVIEW (WEATHER & CLEANED DATA)
# ==============================================================================

col_left, col_right = st.columns(2)

# Left column: Weather breakdown table
with col_left:
    st.subheader("🌤️ Weather Breakdown")
    df_weather = session.sql(f"""
        SELECT Weather_Condition, COUNT(*) as TOTAL 
        FROM {DB_PATH}DIM_WEATHER 
        GROUP BY Weather_Condition 
        ORDER BY TOTAL DESC
    """).to_pandas()
    st.dataframe(df_weather, use_container_width=True)

# Right column: Cleaned data preview table
with col_right:
    st.subheader("📋 Cleaned Data Preview")
    df_preview = session.sql(f"""
        SELECT * FROM {DB_PATH}US_ACCIDENTS_CLEAN LIMIT 100
    """).to_pandas()
    st.dataframe(df_preview, use_container_width=True)