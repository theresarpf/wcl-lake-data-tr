# 1. Install necessary packages if you haven't already
# install.packages(c("dotenv", "DBI", "RPostgres", "dplyr", "dbplyr"))

# Load required packages
library(dotenv)    # For loading .env variables
library(DBI)       # Database interface
library(RPostgres) # Driver for PostgreSQL (replace with your DB driver, e.g., RMySQL, RSQLite, odbc)
library(dplyr)     # For data manipulation
library(dbplyr)    # For dplyr translations to SQL

# --- Best Practice: Load environment variables ---
# This looks for a .env file in the current working directory
# and loads variables into R's environment.
# Ensure your .env file is NOT committed to version control!
load_dot_env()

# --- Best Practice: Securely retrieve credentials ---
# Use Sys.getenv() to access the loaded environment variables.
# Provide a default value (e.g., NA) in case the variable isn't found.
db_host <- Sys.getenv("DB_HOST", unset = NA)
db_port <- Sys.getenv("DB_PORT", unset = NA) # Ports are often numbers, but read as string
db_name <- Sys.getenv("DB_NAME", unset = NA)
db_user <- Sys.getenv("DB_USER", unset = NA)
db_password <- Sys.getenv("DB_PASSWORD", unset = NA)
db_schema <- Sys.getenv("DB_SCHEMA", unset = NA)

# --- Best Practice: Validate credentials before attempting connection ---
if (any(is.na(c(db_host, db_port, db_name, db_user, db_password)))) {
  stop("Database credentials are not fully loaded from .env file.
         Please check your .env file and ensure all variables are set.")
}

# --- Database Connection ---
# Best Practice: Use tryCatch for robust error handling during connection
con <- tryCatch({
  # Establish the database connection
  # Use dbDisconnect(con) when done or on.exit() for automatic disconnection
  dbConnect(
    RPostgres::Postgres(), # Or your specific DB driver (e.g., RMySQL::MySQL(), RSQLite::SQLite(), odbc::odbc())
    host = db_host,
    port = as.integer(db_port), # Convert port to integer if required by driver
    dbname = db_name,
    user = db_user,
    password = db_password
  )
}, error = function(e) {
  stop(paste("Failed to connect to the database:", e$message))
})

# --- Best Practice: Ensure connection is closed on exit ---
# This makes sure the connection is closed even if the script errors out.
on.exit(dbDisconnect(con), add = TRUE)

message("Successfully connected to the database!")

# --- Querying the database table using dbplyr and dplyr ---
# Best Practice: Use tbl() for lazy queries that push operations to the DB.
# This avoids pulling the entire table into R's memory unnecessarily.
table_name <- "lake_ysi_6920" # Define table name as a variable
schema_table_ref <- dbplyr::in_schema(db_schema, table_name) 

tryCatch({
  # Reference the remote table as a 'lazy' dplyr tibble
  remote_data <- tbl(con, schema_table_ref)
  
  # --- Example: Perform some dplyr operations on the remote data ---
  # These operations are translated into SQL and executed on the database
  # only when you 'collect()' the results.
  processed_data <- remote_data %>%
    # filter(temperature_celsius > 10) %>% # Example filter
    select(ts_lpk, temperature, specific_conductivity) %>% # Select specific columns
    arrange(ts_lpk) %>% # Order the data
    head(100) # Limit the results (good for previewing)
  
  # --- Best Practice: Collect the results into R's memory only when needed ---
  # This executes the SQL query on the DB and brings the final results to R.
  local_data <- processed_data %>%
    collect()
  
  message(paste("Successfully queried table '", table_name, "'. Retrieved ", nrow(local_data), " rows.", sep=""))
  print(head(local_data))
  
  # --- Alternative: If you just need the entire table without dplyr remote operations ---
  # all_data_direct <- dbReadTable(con, table_name)
  # message(paste("Successfully read entire table '", table_name, "'. Retrieved ", nrow(all_data_direct), " rows directly.", sep=""))
  # print(head(all_data_direct))
  
}, error = function(e) {
  stop(paste("Error during database query or data processing:", e$message))
})

# --- Best Practice: Explicitly disconnect when you are done ---
# The on.exit() ensures this, but it's good practice to show explicitly too.
if (dbIsValid(con)) { # Check if the connection is still valid before disconnecting
  dbDisconnect(con)
  message("Disconnected from the database.")
}