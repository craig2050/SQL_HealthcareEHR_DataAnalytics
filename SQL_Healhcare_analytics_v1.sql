-- ***** Demographics *****

--What is the demographic profile of the patient population, including age and gender distribution?
SELECT 
    p.gender,
    CASE 
        WHEN EXTRACT(YEAR FROM AGE(p.date_of_birth)) BETWEEN 0 AND 17 THEN 'Pediatric'
        WHEN EXTRACT(YEAR FROM AGE(p.date_of_birth)) BETWEEN 18 AND 64 THEN 'Adult'
        ELSE 'Senior'
    END AS age_group,
    COUNT(*) AS patient_count
FROM patients p
GROUP BY p.gender, age_group
ORDER BY age_group, p.gender;

-- Demographics and Diagnosis Scenario --
-- Business Question: What is the distribution of diagnoses across different gender and age groups?

SELECT 
    p.gender,
    CASE 
        WHEN EXTRACT(YEAR FROM AGE(p.date_of_birth)) BETWEEN 0 AND 17 THEN 'Pediatric'
        WHEN EXTRACT(YEAR FROM AGE(p.date_of_birth)) BETWEEN 18 AND 64 THEN 'Adult'
        ELSE 'Senior'
    END AS age_group,
    ov.diagnosis,
    COUNT(*) AS diagnosis_count
FROM patients p
JOIN outpatient_visits ov ON p.patient_id = ov.patient_id
GROUP BY p.gender, age_group, ov.diagnosis;

-----------------------------------

-- Cohort Analysis --
-- Business Question: Identify patients with chronic diseases who visited the clinic in the last year (focusing on hypertension, hyperlipidemia, and diabetes).

SELECT 
    p.patient_id,
    p.patient_name,
    ov.diagnosis,
    ov.visit_date
FROM patients p
JOIN outpatient_visits ov ON p.patient_id = ov.patient_id
WHERE ov.diagnosis IN ('Hypertension', 'Hyperlipidemia', 'Diabetes')
AND ov.visit_date >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY p.patient_id, p.patient_name, ov.diagnosis, ov.visit_date
ORDER BY p.patient_id, ov.visit_date;

-----------------------------------

-- ***** Appointments *****

-- ***** Appointment Distribution by Day of the Week *****

-- Business Question: What is the distribution of appointments across different days of the week (by day name)?

SELECT 
    TO_CHAR(appointment_date, 'Day') AS appointment_day_of_week,
    COUNT(*) AS appointment_count
FROM appointments
GROUP BY appointment_day_of_week
ORDER BY appointment_count ASC;

-- ***** Appointment Time Analysis *****

-- Business Question: What is the distribution of appointments by time of day?

SELECT 
    TO_CHAR(appointment_time, 'HH12 AM') AS appointment_hour,
    COUNT(*) AS appointment_count
FROM appointments
GROUP BY 1
ORDER BY appointment_count DESC;

-----------------------------------

-- Readmission Scenario --
-- Business Question: Identify patients who were readmitted within 15 days for reasons other than routine checkups, annual physicals, or non-urgent visits.
SELECT DISTINCT
    ov_initial.patient_id,
    ov_initial.visit_date AS initial_visit_date,
    ov_initial.reason_for_visit AS initial_visit_reason,
    ov_readmit.visit_date AS readmission_date,
    ov_readmit.reason_for_visit AS readmission_reason,
    (ov_readmit.visit_date - ov_initial.visit_date) AS days_between_visits
FROM outpatient_visits ov_initial
JOIN outpatient_visits ov_readmit 
    ON ov_initial.patient_id = ov_readmit.patient_id
    AND ov_readmit.visit_date > ov_initial.visit_date
WHERE (ov_readmit.visit_date - ov_initial.visit_date) <= 15
AND ov_initial.reason_for_visit NOT IN ('Annual physical','Diet and Exercise Counseling', 'Checkup','Medication Adjustment')
AND ov_readmit.reason_for_visit NOT IN ('Annual physical','Checkup')
ORDER BY days_between_visits DESC;

-----------------------------------

-- ***** Tests *****

-- Laboratory Scenario --
-- Business Question: What are the most commonly ordered lab tests?

SELECT 
    test_name,
    COUNT(*) AS test_count
FROM lab_results
GROUP BY test_name
ORDER BY test_count DESC;

-----------------------------------

-- ***** Risk Stratification ******

-- Diabetes Risk Stratification Scenario --
-- Business Question: Stratify individuals at high, medium, or low risk of developing diabetes based on smoker status and glucose levels.

SELECT 
    p.patient_id,
    p.patient_name,
    lr.result_value AS glucose_level,
    ov.smoker_status,
    CASE 
        WHEN ov.smoker_status = 'Y' AND lr.result_value >= 126 THEN 'High Risk'
        WHEN ov.smoker_status = 'Y' AND lr.result_value >= 100 AND lr.result_value < 126 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_level
FROM patients p
JOIN outpatient_visits ov ON p.patient_id = ov.patient_id
JOIN lab_results lr ON ov.visit_id = lr.visit_id
WHERE lr.test_name = 'Fasting Blood Sugar'
ORDER BY risk_level DESC, p.patient_id;

-----------------------------------

-- Risk Scenario --
-- Business Question: Stratify patients into high, medium, and low-risk categories based on their smoking status and diagnosis of hypertension or diabetes.

SELECT 
    CASE 
        WHEN ov.smoker_status = 'Y' 
             AND (ov.diagnosis = 'Hypertension' OR ov.diagnosis = 'Diabetes') THEN 'High Risk'
        WHEN ov.smoker_status = 'N' 
             AND (ov.diagnosis = 'Hypertension' OR ov.diagnosis = 'Diabetes') THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_category,
    COUNT(*) AS patient_count
FROM outpatient_visits ov
GROUP BY risk_category;

-----------------------------------

-- ***** Workflow Optimization *****

-- Healthcare Workflow Punctuality Analysis --
-- Business Question: How does patient arrival punctuality vary across different departments, and what is the average delay (in minutes) for late arrivals?

SELECT 
    a.patient_id,
    a.appointment_date,
    a.appointment_time,
    a.arrival_time,
    a.admission_time,
    CASE 
        WHEN a.arrival_time <= a.appointment_time THEN 'Early'
        ELSE 'Late'
    END AS arrival_status,
    CASE
        WHEN a.arrival_time <= a.appointment_time THEN 
            ROUND(EXTRACT(EPOCH FROM (a.appointment_time - a.arrival_time)) / 60, 2)
        ELSE NULL
    END AS minutes_early,
    CASE
        WHEN a.arrival_time > a.appointment_time THEN 
            ROUND(EXTRACT(EPOCH FROM (a.arrival_time - a.appointment_time)) / 60, 2)
        ELSE NULL
    END AS minutes_late
FROM appointments a
WHERE a.arrival_time IS NOT NULL
AND a.appointment_time IS NOT NULL
ORDER BY a.department_name, a.appointment_date, a.arrival_time;

-----------------------------------

-- Departmental Punctuality Trends --
-- Business Question: Which departments have the highest percentage of late arrivals, and what is the average time patients are late or early in these departments?

SELECT 
    a.department_name,
    COUNT(a.patient_id) AS total_appointments,
    SUM(CASE WHEN a.arrival_time <= a.appointment_time THEN 1 ELSE 0 END) AS early_arrivals,
    SUM(CASE WHEN a.arrival_time > a.appointment_time THEN 1 ELSE 0 END) AS late_arrivals,
    ROUND(AVG(CASE WHEN a.arrival_time <= a.appointment_time THEN 
                    EXTRACT(EPOCH FROM (a.appointment_time - a.arrival_time)) / 60 
               ELSE NULL END), 2) AS avg_minutes_early,
    ROUND(AVG(CASE WHEN a.arrival_time > a.appointment_time THEN 
                    EXTRACT(EPOCH FROM (a.arrival_time - a.appointment_time)) / 60 
               ELSE NULL END), 2) AS avg_minutes_late,
    ROUND((SUM(CASE WHEN a.arrival_time <= a.appointment_time THEN 1 ELSE 0 END)::decimal / 
           COUNT(a.patient_id)) * 100, 2) AS early_percentage,
    ROUND((SUM(CASE WHEN a.arrival_time > a.appointment_time THEN 1 ELSE 0 END)::decimal / 
           COUNT(a.patient_id)) * 100, 2) AS late_percentage
FROM appointments a
WHERE a.arrival_time IS NOT NULL
AND a.appointment_time IS NOT NULL
GROUP BY a.department_name
ORDER BY total_appointments DESC;

-----------------------------------

-- Time Difference Between Outpatient Visits and Lab Test Dates --
-- Business Question: How many days difference are there between the outpatient visit date and lab test date for each patient?

SELECT 
    ov.patient_id,
    ov.visit_date AS outpatient_visit_date,
    lr.test_name,
    lr.test_date,
    CASE 
        WHEN ov.visit_date = lr.test_date THEN 0
        ELSE EXTRACT(DAY FROM AGE(lr.test_date, ov.visit_date))
    END AS days_difference
FROM outpatient_visits ov
JOIN lab_results lr ON ov.visit_id = lr.visit_id
JOIN patients p ON ov.patient_id = p.patient_id
ORDER BY days_difference DESC;

-----------------------------------

-- ****** Diagnosis and Prescription Analysis ******

-- Diagnosis Frequency and Associated Lab Tests Analysis --
-- Business Question: What is the frequency of diagnoses, and what are the associated lab tests for each diagnosis?

SELECT 
    ov.diagnosis,
    COUNT(ov.diagnosis) AS diagnosis_frequency,
    STRING_AGG(DISTINCT lr.test_name, ', ') AS unique_tests_conducted
FROM outpatient_visits ov
JOIN lab_results lr ON ov.visit_id = lr.visit_id
GROUP BY ov.diagnosis
ORDER BY diagnosis_frequency DESC;

-----------------------------------

-- Business Question: What is the frequency of prescriptions for each diagnosis, and which medications are most commonly prescribed?

SELECT 
    ov.diagnosis,
    ov.medication_prescribed,
    COUNT(*) AS prescription_count
FROM outpatient_visits ov
WHERE diagnosis IS NOT NULL
GROUP BY ov.diagnosis, ov.medication_prescribed
ORDER BY ov.diagnosis, prescription_count DESC;

