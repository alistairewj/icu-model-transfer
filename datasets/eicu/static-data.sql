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
  from apachepatientresult
  where apacheversion = 'IVa'
)
select
  pat.patientunitstayid -- ICU stay identifier

  -- ======== --
  -- Outcomes --
  -- ======== --

  , ceil((co.dischoffset - co.admitoffset)/60.0) as dischtime_hours
  , co.deathtime_hours
  , co.hospital_expire_flag as death

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
  , case when adm.ethnicity = 'Hispanic' then 1 else 0 end as race_hispanic
  , case when adm.ethnicity = 'Asian' then 1 else 0 end as race_asian
  , case when adm.ethnicity not in
  (
      'African American', 'Hispanic', 'Asian'
  ) then 1 else 0 end as race_other

  , coalesce(apv.electivesurgery, 0) as electivesurgery

from patient pat
-- apache score
left join aiva
  on pat.patientunitstayid = aiva.patientunitstayid

-- apache comorbidity components + diabetes flag
left join APACHEPREDVAR apv
  on pat.patientunitstayid = apv.patientunitstayid;
