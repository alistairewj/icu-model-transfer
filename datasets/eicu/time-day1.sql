select
    co.patientunitstayid
  , sd.censortime_hours, sd.deathtime_hours, sd.dischtime_hours
  , co.random_fraction
  , 24::SMALLINT as windowtime
from tr_cohort co
LEFT JOIN tr_static_data sd
  ON co.patientunitstayid = sd.patientunitstayid
where co.excluded = 0;
