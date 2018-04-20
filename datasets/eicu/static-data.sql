-- extract static vars - those which don't change over time
-- static vars contain the following:
--  - demographics (gender, age)
--  - hospital admission type
--  - hospital service
--  - race
--  - height, weight, BMI
--  - outcome

DROP TABLE IF EXISTS tr_static_data CASCADE;
CREATE TABLE tr_static_data AS
-- censor time extracted as first time code status changed
with cs as
(
  select cs.patientunitstayid
    , min(cs.chartoffset) as chartoffset
  from tr_code_status cs
  where GREATEST(cmo,dnr)>0
  group by cs.patientunitstayid
)
, aiva as
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

  -- ======== --
  -- Outcomes --
  -- ======== --

  , ceil((co.dischoffset - co.admitoffset)/60.0) as dischtime_hours
  , co.deathtime_hours
  , co.hospital_expire_flag as death
  , aiva.ventdays

  -- code status
  , ceil((cs.chartoffset-co.admitoffset)/60.0) as censortime_hours

  -- ====================== --
  -- Patient level factors --
  -- ====================== --

  -- patient features
  , case when pat.gender = 'Female' then 1 else 0 end as is_female
  , case
      when pat.age = '> 89' then 90
      when pat.age = '' then NULL
    else cast(pat.age as NUMERIC)
    end as age
  , case when pat.ethnicity = 'African American' then 1 else 0 end as race_black
  , case when pat.ethnicity = 'Hispanic' then 1 else 0 end as race_hispanic
  , case when pat.ethnicity = 'Asian' then 1 else 0 end as race_asian
  , case when pat.ethnicity not in
  (
      'African American', 'Hispanic', 'Asian'
  ) then 1 else 0 end as race_other

  , coalesce(apv.electivesurgery, 0) as electivesurgery

from tr_cohort co
INNER JOIN patient pat
  ON co.patientunitstayid = pat.patientunitstayid
LEFT JOIN cs
  ON co.patientunitstayid = cs.patientunitstayid
-- apache score
left join aiva
  on co.patientunitstayid = aiva.patientunitstayid
-- apache elective surgery flag
left join APACHEPREDVAR apv
  on co.patientunitstayid = apv.patientunitstayid;
