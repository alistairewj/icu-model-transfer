DROP TABLE IF EXISTS tr_apache CASCADE;
CREATE TABLE tr_apache AS
with aiva as
(
  select patientunitstayid, apachescore, predictedhospitalmortality
    -- actual vent days is an integer truncated at 30
    , actualventdays::INTEGER as ventdays
  from apachepatientresult
  where apacheversion = 'IVa'
)
select
  pat.patientunitstayid -- ICU stay identifier
  , pat.hospitalid
  , aiva.apachescore
  , aiva.predictedhospitalmortality
from tr_cohort co
INNER JOIN patient pat
  ON co.patientunitstayid = pat.patientunitstayid
-- apache score
left join aiva
  on co.patientunitstayid = aiva.patientunitstayid
WHERE excluded = 0;
