select setseed(0.1);

DROP TABLE IF EXISTS tr_time_random CASCADE;
CREATE TABLE tr_time_random AS
with ra as
(
  select patientunitstayid
    , excluded
    , random() as random_fraction
  from tr_cohort co
)
select
    ra.patientunitstayid
  , sd.censortime_hours, sd.deathtime_hours, sd.dischtime_hours
  , ra.random_fraction
  , GREATEST(
      FLOOR(
        ra.random_fraction*LEAST(sd.censortime_hours, sd.deathtime_hours, sd.dischtime_hours)
      ) - 2
      , 4) as windowtime
from ra
LEFT JOIN tr_static_data sd
  ON ra.patientunitstayid = sd.patientunitstayid
where ra.excluded = 0;
