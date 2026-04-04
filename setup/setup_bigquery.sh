#!/bin/bash

PROJECT_ID=$(gcloud config get-value project)
DATASET_NAME="mcp_medical"
LOCATION="US"

# Generate bucket name if not provided
if [ -z "$1" ]; then
    BUCKET_NAME="gs://mcp-medical-data-$PROJECT_ID"
    echo "No bucket provided. Using default: $BUCKET_NAME"
else
    BUCKET_NAME=$1
fi

echo "----------------------------------------------------------------"
echo "MCP Medical Project Setup"
echo "Project: $PROJECT_ID"
echo "Dataset: $DATASET_NAME"
echo "Bucket:  $BUCKET_NAME"
echo "----------------------------------------------------------------"

# 1. Create Bucket if it doesn't exist
echo "[1/7] Checking bucket $BUCKET_NAME..."
if gcloud storage buckets describe $BUCKET_NAME >/dev/null 2>&1; then
    echo "      Bucket already exists."
else
    echo "      Creating bucket $BUCKET_NAME..."
    gcloud storage buckets create $BUCKET_NAME --location=$LOCATION
fi

# 2. Upload Data
echo "[2/7] Uploading data to $BUCKET_NAME..."
gcloud storage cp data/*.csv $BUCKET_NAME

# 3. Create Dataset
echo "[3/7] Creating Dataset '$DATASET_NAME'..."
if bq show "$PROJECT_ID:$DATASET_NAME" >/dev/null 2>&1; then
    echo "      Dataset already exists. Skipping creation."
else    
    bq mk --location=$LOCATION --dataset \
        --description "$DATASET_DESCRIPTION" \
        "$PROJECT_ID:$DATASET_NAME"
    echo "      Dataset created."
fi

# # 4. Create Demographics Table
# echo "[4/7] Setting up Table: demographics..."
# bq query --use_legacy_sql=false \
# "CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.demographics\` (
#     zip_code STRING OPTIONS(description='5-digit US Zip Code'),
#     city STRING OPTIONS(description='City name, e.g., Los Angeles'),
#     neighborhood STRING OPTIONS(description='Common neighborhood name, e.g., Santa Monica, Silver Lake'),
#     total_population INT64 OPTIONS(description='Total population count in the zip code'),
#     median_age FLOAT64 OPTIONS(description='Median age of residents'),
#     bachelors_degree_pct FLOAT64 OPTIONS(description='Percentage of population 25+ with a Bachelors degree or higher'),
#     foot_traffic_index FLOAT64 OPTIONS(description='Index of estimated foot traffic based on commercial density and mobility data')
# )
# OPTIONS(
#     description='Census data by zip code for various California cities.'
# );"

# bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
#     "$PROJECT_ID:$DATASET_NAME.demographics" "$BUCKET_NAME/demographics.csv"

# # 5. Create Bakery Prices Table
# echo "[5/7] Setting up Table: bakery_prices..."
# bq query --use_legacy_sql=false \
# "CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.bakery_prices\` (
#     store_name STRING OPTIONS(description='Name of the competitor bakery'),
#     product_type STRING OPTIONS(description='Type of baked good, e.g., Sourdough Loaf, Croissant'),
#     price FLOAT64 OPTIONS(description='Price per unit in USD'),
#     region STRING OPTIONS(description='Geographic region, e.g., Los Angeles Metro, SF Bay Area'),
#     is_organic BOOL OPTIONS(description='Whether the product is certified organic')
# )
# OPTIONS(
#     description='Competitor pricing and product details for common baked goods.'
# );"

# bq load --source_format=CSV --skip_leading_rows=1 --replace \
#     "$PROJECT_ID:$DATASET_NAME.bakery_prices" "$BUCKET_NAME/bakery_prices.csv"

# # 6. Create Sales History Table
# echo "[6/7] Setting up Table: sales_history_weekly..."
# bq query --use_legacy_sql=false \
# "CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.sales_history_weekly\` (
#     week_start_date DATE OPTIONS(description='The start date of the sales week (Monday)'),
#     store_location STRING OPTIONS(description='Location of the bakery branch'),
#     product_type STRING OPTIONS(description='Product category: Sourdough Loaf, Croissant, etc.'),
#     quantity_sold INT64 OPTIONS(description='Total units sold this week'),
#     total_revenue FLOAT64 OPTIONS(description='Total revenue in USD for this week')
# )
# OPTIONS(
#     description='Weekly sales performance history by store and product.'
# );"

# bq load --source_format=CSV --skip_leading_rows=1 --replace \
#     "$PROJECT_ID:$DATASET_NAME.sales_history_weekly" "$BUCKET_NAME/sales_history_weekly.csv"

# # 7. Create Foot Traffic Table
# echo "[7/7] Setting up Table: foot_traffic..."
# bq query --use_legacy_sql=false \
# "CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.foot_traffic\` (
#     zip_code STRING OPTIONS(description='5-digit US Zip Code'),
#     time_of_day STRING OPTIONS(description='Time of day: morning, afternoon, evening'),
#     foot_traffic_score FLOAT64 OPTIONS(description='Score of foot traffic (1-100)')
# )
# OPTIONS(
#     description='Foot traffic scores by zip code and time of day.'
# );"

# bq load --source_format=CSV --skip_leading_rows=1 --replace \
#     "$PROJECT_ID:$DATASET_NAME.foot_traffic" "$BUCKET_NAME/foot_traffic.csv"

# echo "----------------------------------------------------------------"
# echo "Setup Complete!"
# echo "----------------------------------------------------------------"

# ==============================================================================
# [1/16] allergies
# ==============================================================================
echo ""
echo "[1/16] Setting up table: allergies..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.allergies\` (
    START       DATE    OPTIONS(description='The date the allergy was diagnosed.'),
    STOP        DATE    OPTIONS(description='The date the allergy ended, if applicable.'),
    PATIENT     STRING  OPTIONS(description='Foreign key to the Patient (UUID).'),
    ENCOUNTER   STRING  OPTIONS(description='Foreign key to the Encounter when the allergy was diagnosed (UUID).'),
    CODE        STRING  OPTIONS(description='Allergy code. RxNorm if a medication allergy, otherwise SNOMED-CT.'),
    DESCRIPTION STRING  OPTIONS(description='Description of the allergy.')
)
OPTIONS(
    description='Patient allergy data. Each row represents a diagnosed allergy linked to a patient and encounter.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.allergies" "$BUCKET_NAME/allergies.csv"
 
# ==============================================================================
# [2/16] careplans
# ==============================================================================
echo ""
echo "[2/16] Setting up table: careplans..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.careplans\` (
    Id                 STRING  OPTIONS(description='Primary Key. Unique identifier of the care plan (UUID).'),
    START              DATE    OPTIONS(description='The date the care plan was initiated.'),
    STOP               DATE    OPTIONS(description='The date the care plan ended, if applicable.'),
    PATIENT            STRING  OPTIONS(description='Foreign key to the Patient (UUID).'),
    ENCOUNTER          STRING  OPTIONS(description='Foreign key to the Encounter when the care plan was initiated (UUID).'),
    CODE               STRING  OPTIONS(description='Care plan code from SNOMED-CT.'),
    DESCRIPTION        STRING  OPTIONS(description='Description of the care plan.'),
    REASONCODE         STRING  OPTIONS(description='Diagnosis code from SNOMED-CT that this care plan addresses.'),
    REASONDESCRIPTION  STRING  OPTIONS(description='Description of the reason code.')
)
OPTIONS(
    description='Patient care plan data, including goals. Each row represents a care plan period for a patient.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.careplans" "$BUCKET_NAME/careplans.csv"
 
# ==============================================================================
# [3/16] conditions
# ==============================================================================
echo ""
echo "[3/16] Setting up table: conditions..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.conditions\` (
    START       DATE    OPTIONS(description='The date the condition was diagnosed.'),
    STOP        DATE    OPTIONS(description='The date the condition resolved, if applicable.'),
    PATIENT     STRING  OPTIONS(description='Foreign key to the Patient (UUID).'),
    ENCOUNTER   STRING  OPTIONS(description='Foreign key to the Encounter when the condition was diagnosed (UUID).'),
    CODE        STRING  OPTIONS(description='Diagnosis code from SNOMED-CT.'),
    DESCRIPTION STRING  OPTIONS(description='Description of the condition.')
)
OPTIONS(
    description='Patient conditions or diagnoses. Each row is a condition onset linked to a patient and encounter.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.conditions" "$BUCKET_NAME/conditions.csv"
 
# ==============================================================================
# [4/16] devices
# ==============================================================================
echo ""
echo "[4/16] Setting up table: devices..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.devices\` (
    START       TIMESTAMP OPTIONS(description='The date and time the device was associated to the patient (ISO 8601 UTC).'),
    STOP        TIMESTAMP OPTIONS(description='The date and time the device was removed, if applicable (ISO 8601 UTC).'),
    PATIENT     STRING    OPTIONS(description='Foreign key to the Patient (UUID).'),
    ENCOUNTER   STRING    OPTIONS(description='Foreign key to the Encounter when the device was associated (UUID).'),
    CODE        STRING    OPTIONS(description='Type of device, from SNOMED-CT.'),
    DESCRIPTION STRING    OPTIONS(description='Description of the device.'),
    UDI         STRING    OPTIONS(description='FDA Unique Device Identifier (UDI) for the device.')
)
OPTIONS(
    description='Patient-affixed permanent and semi-permanent devices. Each row represents a device implanted or attached to a patient.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.devices" "$BUCKET_NAME/devices.csv"
 
# ==============================================================================
# [5/16] encounters
# ==============================================================================
echo ""
echo "[5/16] Setting up table: encounters..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.encounters\` (
    Id                   STRING  OPTIONS(description='Primary Key. Unique identifier of the encounter (UUID).'),
    START                TIMESTAMP OPTIONS(description='The date and time the encounter started (ISO 8601 UTC).'),
    STOP                 TIMESTAMP OPTIONS(description='The date and time the encounter concluded (ISO 8601 UTC).'),
    PATIENT              STRING  OPTIONS(description='Foreign key to the Patient (UUID).'),
    ORGANIZATION         STRING  OPTIONS(description='Foreign key to the Organization (UUID).'),
    PROVIDER             STRING  OPTIONS(description='Foreign key to the Provider/Clinician (UUID).'),
    PAYER                STRING  OPTIONS(description='Foreign key to the Payer/Insurer (UUID).'),
    ENCOUNTERCLASS       STRING  OPTIONS(description='Class of the encounter: ambulatory, emergency, inpatient, wellness, or urgentcare.'),
    CODE                 STRING  OPTIONS(description='Encounter code from SNOMED-CT.'),
    DESCRIPTION          STRING  OPTIONS(description='Description of the type of encounter.'),
    BASE_ENCOUNTER_COST  FLOAT64 OPTIONS(description='Base cost of the encounter, excluding line item costs for medications, immunizations, procedures, or other services.'),
    TOTAL_CLAIM_COST     FLOAT64 OPTIONS(description='Total cost of the encounter, including all line items.'),
    PAYER_COVERAGE       FLOAT64 OPTIONS(description='The amount of cost covered by the Payer.'),
    REASONCODE           STRING  OPTIONS(description='Diagnosis code from SNOMED-CT, only if this encounter targeted a specific condition.'),
    REASONDESCRIPTION    STRING  OPTIONS(description='Description of the reason code.')
)
OPTIONS(
    description='Patient encounter data. Each row represents a single clinical encounter (visit) for a patient.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.encounters" "$BUCKET_NAME/encounters.csv"
 
# ==============================================================================
# [6/16] imaging_studies
# ==============================================================================
echo ""
echo "[6/16] Setting up table: imaging_studies..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.imaging_studies\` (
    Id                   STRING    OPTIONS(description='Non-unique identifier of the imaging study. A single study may have multiple rows (one per series/instance).'),
    DATE                 TIMESTAMP OPTIONS(description='The date and time the imaging study was conducted (ISO 8601 UTC).'),
    PATIENT              STRING    OPTIONS(description='Foreign key to the Patient (UUID).'),
    ENCOUNTER            STRING    OPTIONS(description='Foreign key to the Encounter where the imaging study was conducted (UUID).'),
    BODYSITE_CODE        STRING    OPTIONS(description='A SNOMED Body Structures code describing what part of the body was imaged.'),
    BODYSITE_DESCRIPTION STRING    OPTIONS(description='Description of the body site imaged.'),
    MODALITY_CODE        STRING    OPTIONS(description='A DICOM-DCM code describing the imaging method used, e.g. DX for Digital Radiography, CT for Computed Tomography.'),
    MODALITY_DESCRIPTION STRING    OPTIONS(description='Description of the imaging modality.'),
    SOP_CODE             STRING    OPTIONS(description='A DICOM-SOP code describing the Subject-Object Pair (SOP) that constitutes the image.'),
    SOP_DESCRIPTION      STRING    OPTIONS(description='Description of the SOP code.')
)
OPTIONS(
    description='Patient imaging study metadata. Each row represents one image series/instance from a DICOM imaging study.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.imaging_studies" "$BUCKET_NAME/imaging_studies.csv"
 
# ==============================================================================
# [7/16] immunizations
# ==============================================================================
echo ""
echo "[7/16] Setting up table: immunizations..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.immunizations\` (
    DATE        TIMESTAMP OPTIONS(description='The date and time the immunization was administered (ISO 8601 UTC).'),
    PATIENT     STRING    OPTIONS(description='Foreign key to the Patient (UUID).'),
    ENCOUNTER   STRING    OPTIONS(description='Foreign key to the Encounter where the immunization was administered (UUID).'),
    CODE        INT64     OPTIONS(description='Immunization code from CVX (CDC Vaccine Code).'),
    DESCRIPTION STRING    OPTIONS(description='Description of the immunization.'),
    BASE_COST   FLOAT64   OPTIONS(description='The line item cost of the immunization.')
)
OPTIONS(
    description='Patient immunization data. Each row represents a single vaccine administered to a patient during an encounter.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.immunizations" "$BUCKET_NAME/immunizations.csv"
 
# ==============================================================================
# [8/16] medications
# ==============================================================================
echo ""
echo "[8/16] Setting up table: medications..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.medications\` (
    START             TIMESTAMP OPTIONS(description='The date and time the medication was prescribed (ISO 8601 UTC).'),
    STOP              TIMESTAMP OPTIONS(description='The date and time the prescription ended, if applicable (ISO 8601 UTC).'),
    PATIENT           STRING    OPTIONS(description='Foreign key to the Patient (UUID).'),
    PAYER             STRING    OPTIONS(description='Foreign key to the Payer responsible for coverage (UUID).'),
    ENCOUNTER         STRING    OPTIONS(description='Foreign key to the Encounter where the medication was prescribed (UUID).'),
    CODE              INT64     OPTIONS(description='Medication code from RxNorm.'),
    DESCRIPTION       STRING    OPTIONS(description='Description of the medication.'),
    BASE_COST         FLOAT64   OPTIONS(description='The line item cost of the medication per dispense.'),
    PAYER_COVERAGE    FLOAT64   OPTIONS(description='The amount covered or reimbursed by the Payer per dispense.'),
    DISPENSES         INT64     OPTIONS(description='The number of times the prescription was filled.'),
    TOTALCOST         FLOAT64   OPTIONS(description='The total cost of the prescription across all dispenses.'),
    REASONCODE        STRING    OPTIONS(description='Diagnosis code from SNOMED-CT specifying why this medication was prescribed.'),
    REASONDESCRIPTION STRING    OPTIONS(description='Description of the reason code.')
)
OPTIONS(
    description='Patient medication data. Each row represents a prescription period, including cost and coverage details.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.medications" "$BUCKET_NAME/medications.csv"
 
# ==============================================================================
# [9/16] observations
# ==============================================================================
echo ""
echo "[9/16] Setting up table: observations..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.observations\` (
    DATE        TIMESTAMP OPTIONS(description='The date and time the observation was performed (ISO 8601 UTC).'),
    PATIENT     STRING    OPTIONS(description='Foreign key to the Patient (UUID).'),
    ENCOUNTER   STRING    OPTIONS(description='Foreign key to the Encounter where the observation was performed (UUID).'),
    CODE        STRING    OPTIONS(description='Observation or lab code from LOINC.'),
    DESCRIPTION STRING    OPTIONS(description='Description of the observation or lab test.'),
    VALUE       STRING    OPTIONS(description='The recorded value of the observation. Numeric for measurements; may be verbose text for questionnaire responses.'),
    UNITS       STRING    OPTIONS(description='The units of measure for the value, e.g. cm, kg, mmHg.'),
    TYPE        STRING    OPTIONS(description='The data type of the Value field: text or numeric.')
)
OPTIONS(
    description='Patient observations including vital signs and lab reports. Each row is one measurement or result recorded during an encounter.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.observations" "$BUCKET_NAME/observations.csv"
 
# ==============================================================================
# [10/16] organizations
# ==============================================================================
echo ""
echo "[10/16] Setting up table: organizations..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.organizations\` (
    Id          STRING  OPTIONS(description='Primary Key. Unique identifier of the organization (UUID).'),
    NAME        STRING  OPTIONS(description='Name of the healthcare organization.'),
    ADDRESS     STRING  OPTIONS(description='Organization street address without commas or newlines.'),
    CITY        STRING  OPTIONS(description='Street address city.'),
    STATE       STRING  OPTIONS(description='Street address state abbreviation.'),
    ZIP         STRING  OPTIONS(description='Street address ZIP or postal code.'),
    LAT         FLOAT64 OPTIONS(description='Latitude of the organization address.'),
    LON         FLOAT64 OPTIONS(description='Longitude of the organization address.'),
    PHONE       STRING  OPTIONS(description='Organization phone number.'),
    REVENUE     FLOAT64 OPTIONS(description='Total monetary revenue of the organization across the entire simulation.'),
    UTILIZATION INT64   OPTIONS(description='Total number of encounters performed by this organization.')
)
OPTIONS(
    description='Provider organizations including hospitals and clinics. Each row represents one healthcare organization.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.organizations" "$BUCKET_NAME/organizations.csv"
 
# ==============================================================================
# [11/16] patients
# ==============================================================================
echo ""
echo "[11/16] Setting up table: patients..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.patients\` (
    Id                   STRING  OPTIONS(description='Primary Key. Unique identifier of the patient (UUID).'),
    BIRTHDATE            DATE    OPTIONS(description='The date the patient was born.'),
    DEATHDATE            DATE    OPTIONS(description='The date the patient died, if applicable.'),
    SSN                  STRING  OPTIONS(description='Patient Social Security Number identifier.'),
    DRIVERS              STRING  OPTIONS(description='Patient Drivers License identifier.'),
    PASSPORT             STRING  OPTIONS(description='Patient Passport identifier.'),
    PREFIX               STRING  OPTIONS(description='Name prefix such as Mr., Mrs., Dr., etc.'),
    FIRST                STRING  OPTIONS(description='First name of the patient.'),
    LAST                 STRING  OPTIONS(description='Last or surname of the patient.'),
    SUFFIX               STRING  OPTIONS(description='Name suffix such as PhD, MD, JD, etc.'),
    MAIDEN               STRING  OPTIONS(description='Maiden name of the patient.'),
    MARITAL              STRING  OPTIONS(description='Marital status. M = married, S = single.'),
    RACE                 STRING  OPTIONS(description='Description of the patient primary race.'),
    ETHNICITY            STRING  OPTIONS(description='Description of the patient primary ethnicity.'),
    GENDER               STRING  OPTIONS(description='Gender. M = male, F = female.'),
    BIRTHPLACE           STRING  OPTIONS(description='Name of the town where the patient was born.'),
    ADDRESS              STRING  OPTIONS(description='Patient street address without commas or newlines.'),
    CITY                 STRING  OPTIONS(description='Patient address city.'),
    STATE                STRING  OPTIONS(description='Patient address state.'),
    COUNTY               STRING  OPTIONS(description='Patient address county.'),
    ZIP                  STRING  OPTIONS(description='Patient ZIP code.'),
    LAT                  FLOAT64 OPTIONS(description='Latitude of the patient address.'),
    LON                  FLOAT64 OPTIONS(description='Longitude of the patient address.'),
    HEALTHCARE_EXPENSES  FLOAT64 OPTIONS(description='Total lifetime cost of healthcare paid out-of-pocket by the patient.'),
    HEALTHCARE_COVERAGE  FLOAT64 OPTIONS(description='Total lifetime cost of healthcare services covered by payers (insurance).')
)
OPTIONS(
    description='Patient demographic data. Each row represents one synthetic patient with full demographic and lifetime cost information.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.patients" "$BUCKET_NAME/patients.csv"
 
# ==============================================================================
# [12/16] payer_transitions
# ==============================================================================
echo ""
echo "[12/16] Setting up table: payer_transitions..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.payer_transitions\` (
    PATIENT     STRING  OPTIONS(description='Foreign key to the Patient (UUID).'),
    START_YEAR  INT64   OPTIONS(description='The year the insurance coverage started (inclusive).'),
    END_YEAR    INT64   OPTIONS(description='The year the insurance coverage ended (inclusive).'),
    PAYER       STRING  OPTIONS(description='Foreign key to the primary Payer/Insurer (UUID).'),
    OWNERSHIP   STRING  OPTIONS(description='The owner of the insurance policy: Guardian, Self, or Spouse.')
)
OPTIONS(
    description='Payer transition data capturing changes in patient health insurance coverage over time.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.payer_transitions" "$BUCKET_NAME/payer_transitions.csv"
 
# ==============================================================================
# [13/16] payers
# ==============================================================================
echo ""
echo "[13/16] Setting up table: payers..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.payers\` (
    Id                      STRING  OPTIONS(description='Primary Key. Unique identifier of the payer/insurer (UUID).'),
    NAME                    STRING  OPTIONS(description='Name of the payer (e.g. Medicare, Medicaid, private insurer).'),
    ADDRESS                 STRING  OPTIONS(description='Payer street address without commas or newlines.'),
    CITY                    STRING  OPTIONS(description='Street address city.'),
    STATE_HEADQUARTERED     STRING  OPTIONS(description='State abbreviation where the payer is headquartered.'),
    ZIP                     STRING  OPTIONS(description='Street address ZIP or postal code.'),
    PHONE                   STRING  OPTIONS(description='Payer phone number.'),
    AMOUNT_COVERED          FLOAT64 OPTIONS(description='Total monetary amount paid to organizations across the entire simulation.'),
    AMOUNT_UNCOVERED        FLOAT64 OPTIONS(description='Total monetary amount not paid by the payer, covered out-of-pocket by patients.'),
    REVENUE                 FLOAT64 OPTIONS(description='Total monetary revenue of the payer across the entire simulation.'),
    COVERED_ENCOUNTERS      INT64   OPTIONS(description='Total number of encounters paid for by this payer.'),
    UNCOVERED_ENCOUNTERS    INT64   OPTIONS(description='Total number of encounters not paid for by this payer (paid by patients).'),
    COVERED_MEDICATIONS     INT64   OPTIONS(description='Total number of medications paid for by this payer.'),
    UNCOVERED_MEDICATIONS   INT64   OPTIONS(description='Total number of medications not paid for by this payer.'),
    COVERED_PROCEDURES      INT64   OPTIONS(description='Total number of procedures paid for by this payer.'),
    UNCOVERED_PROCEDURES    INT64   OPTIONS(description='Total number of procedures not paid for by this payer.'),
    COVERED_IMMUNIZATIONS   INT64   OPTIONS(description='Total number of immunizations paid for by this payer.'),
    UNCOVERED_IMMUNIZATIONS INT64   OPTIONS(description='Total number of immunizations not paid for by this payer.'),
    UNIQUE_CUSTOMERS        INT64   OPTIONS(description='Number of unique patients enrolled with this payer during the simulation.'),
    QOLS_AVG                FLOAT64 OPTIONS(description='Average Quality of Life Score (QOLS) for all patients enrolled with this payer.'),
    MEMBER_MONTHS           INT64   OPTIONS(description='Total months patients were enrolled with this payer and paid monthly premiums.')
)
OPTIONS(
    description='Payer organization data. Each row represents one insurance payer with aggregated financial and coverage statistics.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.payers" "$BUCKET_NAME/payers.csv"
 
# ==============================================================================
# [14/16] procedures
# ==============================================================================
echo ""
echo "[14/16] Setting up table: procedures..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.procedures\` (
    DATE              TIMESTAMP OPTIONS(description='The date and time the procedure was performed (ISO 8601 UTC).'),
    PATIENT           STRING    OPTIONS(description='Foreign key to the Patient (UUID).'),
    ENCOUNTER         STRING    OPTIONS(description='Foreign key to the Encounter where the procedure was performed (UUID).'),
    CODE              STRING    OPTIONS(description='Procedure code from SNOMED-CT.'),
    DESCRIPTION       STRING    OPTIONS(description='Description of the procedure.'),
    BASE_COST         FLOAT64   OPTIONS(description='The line item cost of the procedure.'),
    REASONCODE        STRING    OPTIONS(description='Diagnosis code from SNOMED-CT specifying why this procedure was performed.'),
    REASONDESCRIPTION STRING    OPTIONS(description='Description of the reason code.')
)
OPTIONS(
    description='Patient procedure data including surgeries and clinical interventions. Each row is a single procedure performed during an encounter.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.procedures" "$BUCKET_NAME/procedures.csv"
 
# ==============================================================================
# [15/16] providers
# ==============================================================================
echo ""
echo "[15/16] Setting up table: providers..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.providers\` (
    Id           STRING  OPTIONS(description='Primary Key. Unique identifier of the provider/clinician (UUID).'),
    ORGANIZATION STRING  OPTIONS(description='Foreign key to the Organization that employs this provider (UUID).'),
    NAME         STRING  OPTIONS(description='Full name (first and last) of the provider.'),
    GENDER       STRING  OPTIONS(description='Gender of the provider. M = male, F = female.'),
    SPECIALITY   STRING  OPTIONS(description='Medical speciality of the provider, e.g. GENERAL PRACTICE, CARDIOLOGY.'),
    ADDRESS      STRING  OPTIONS(description='Provider street address without commas or newlines.'),
    CITY         STRING  OPTIONS(description='Street address city.'),
    STATE        STRING  OPTIONS(description='Street address state abbreviation.'),
    ZIP          STRING  OPTIONS(description='Street address ZIP or postal code.'),
    LAT          FLOAT64 OPTIONS(description='Latitude of the provider address.'),
    LON          FLOAT64 OPTIONS(description='Longitude of the provider address.'),
    UTILIZATION  INT64   OPTIONS(description='Total number of encounters performed by this provider.')
)
OPTIONS(
    description='Clinician/provider data. Each row represents one healthcare provider and their affiliated organization.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.providers" "$BUCKET_NAME/providers.csv"
 
# ==============================================================================
# [16/16] supplies
# ==============================================================================
echo ""
echo "[16/16] Setting up table: supplies..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.supplies\` (
    DATE        DATE    OPTIONS(description='The date the supplies were used.'),
    PATIENT     STRING  OPTIONS(description='Foreign key to the Patient (UUID).'),
    ENCOUNTER   STRING  OPTIONS(description='Foreign key to the Encounter when the supplies were used (UUID).'),
    CODE        STRING  OPTIONS(description='Code for the type of supply used, from SNOMED-CT.'),
    DESCRIPTION STRING  OPTIONS(description='Description of the supply used.'),
    QUANTITY    INT64   OPTIONS(description='Quantity of the supply used.')
)
OPTIONS(
    description='Supplies used in the provision of patient care. Each row records a supply item consumed during an encounter.'
);"
 
bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.supplies" "$BUCKET_NAME/supplies.csv"
 
# ==============================================================================
echo ""
echo "================================================================"
echo "Setup Complete! All 16 Synthea tables created and loaded."
echo "================================================================"
echo ""
echo "Tables created in $PROJECT_ID.$DATASET_NAME:"
echo "  1.  allergies"
echo "  2.  careplans"
echo "  3.  conditions"
echo "  4.  devices"
echo "  5.  encounters"
echo "  6.  imaging_studies"
echo "  7.  immunizations"
echo "  8.  medications"
echo "  9.  observations"
echo "  10. organizations"
echo "  11. patients"
echo "  12. payer_transitions"
echo "  13. payers"
echo "  14. procedures"
echo "  15. providers"
echo "  16. supplies"