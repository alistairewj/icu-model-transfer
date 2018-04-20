-- This query generates a row for every hour the patient is in the ICU.
-- The hours are based on clock-hours (i.e. 02:00, 03:00).
-- The hour clock starts 24 hours before the first heart rate measurement.
-- Note that the time of the first heart rate measurement is ceilinged to the hour.

-- this query extracts the cohort and every possible hour they were in the ICU
-- this table can be to other tables on ICUSTAY_ID and (ENDTIME - 1 hour,ENDTIME]
DROP TABLE IF EXISTS tr_icustay_hours CASCADE;
CREATE TABLE tr_icustay_hours as
-- get first/last measurement time
with all_hours as
(
  select
    co.patientunitstayid

    -- ceiling the intime to the nearest hour by adding 59 minutes then truncating
    , CEIL(co.admitoffset/60.0)*60.0 as endoffset

    -- create integers for each charttime in hours from admission
    -- so 0 is admission time, 1 is one hour after admission, etc, up to ICU disch
    , generate_series
    (
      -- allow up to 24 hours before ICU admission (to grab labs before admit)
      -24,
      ceil((co.dischoffset-co.admitoffset)/60.0)::INTEGER
    ) as hr

  from tr_cohort co
  WHERE excluded=0
)
SELECT
  ah.patientunitstayid
  , ah.hr
  -- add the hr series
  -- endtime now indexes the end time of every hour for each patient
  , ah.endoffset + ah.hr*60.0 as endoffset
from all_hours ah
order by ah.patientunitstayid;
