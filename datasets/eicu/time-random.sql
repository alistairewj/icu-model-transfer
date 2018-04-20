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
, tm as
(
  select
      ra.patientunitstayid
    , sd.censortime_hours, sd.deathtime_hours, sd.dischtime_hours
    , ra.random_fraction
    , GREATEST(FLOOR(
          ra.random_fraction*(LEAST(sd.censortime_hours, sd.deathtime_hours, sd.dischtime_hours)-2)
        ), 4) as windowtime_hours
  from ra
  LEFT JOIN tr_static_data sd
    ON ra.patientunitstayid = sd.patientunitstayid
  where ra.excluded = 0
)
-- finally, filter out patients who died/were censored before 4 hours
select
  tm.patientunitstayid
, tm.censortime_hours, tm.deathtime_hours, tm.dischtime_hours
, tm.random_fraction
, tm.windowtime_hours
FROM tm
WHERE tm.windowtime_hours <= LEAST(tm.censortime_hours, tm.deathtime_hours, tm.dischtime_hours);
