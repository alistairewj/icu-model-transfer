DROP TABLE IF EXISTS tr_cohort CASCADE;
CREATE TABLE tr_cohort AS
with pt as
(
  select pt.patientunitstayid
  , pt.patienthealthsystemstayid
  , pt.uniquepid
  , pt.hospitalid
  , hospitaladmitoffset

  -- outcomes
  , hospitaldischargeoffset
  , unitdischargeoffset
  , hospitaldischargestatus
  , (case when hospitaldischargestatus = 'Expired' then 1 else 0 end)::smallint
      as hospital_expire_flag
  , hospitaladmityear, hospitaldischargeyear
  , case when pt.age = '' then null
      else REPLACE(age, '>','')
    end::INT as age
  from patient pt
  where
    -- only include ICUs
    lower(unittype) like '%icu%'
)
, vw1 as
(
  select
    pt.*
    , ROW_NUMBER() over
    (
      PARTITION BY uniquepid
      ORDER BY
        hospitaladmityear, hospitaldischargeyear
      , age
      , patienthealthsystemstayid -- this is temporally random but deterministic
      , hospitaladmitoffset
    ) as HOSP_NUM
    , ROW_NUMBER() over
    (
      PARTITION BY patienthealthsystemstayid
      ORDER BY hospitaladmitoffset
    ) as ICUSTAY_NUM
  from pt
)
-- extract the first heart rate time as the admission time
, adm as
(
  select
    patientunitstayid
    , min(chartoffset) as admitoffset
    , max(chartoffset) as dischoffset
  from pivoted_vital p
  WHERE heartrate IS NOT NULL
  GROUP BY patientunitstayid
)
, co as
(
  select vw1.patientunitstayid
  , vw1.hospitalid
  -- admit time is the first observed heart rate
  , adm.admitoffset
  , adm.dischoffset

  -- outcomes
  , vw1.hospital_expire_flag
  , (adm.dischoffset - adm.admitoffset)/60.0/24.0 as icu_los
  , (vw1.hospitaldischargeoffset-adm.admitoffset)/60.0/24.0 as hosp_los
  , case when vw1.hospital_expire_flag = 1
        then (vw1.hospitaldischargeoffset-adm.admitoffset)/60.0/24.0
      else null end
     as deathtime_hours

  , case when age < 16 then 1 else 0 end as exclusion_non_adult
  , case when adm.admitoffset is null then 1
        when vw1.hospitaldischargestatus is null then 1
      else 0 end
    as exclusion_bad_data
  , 0 as exclusion_organ_donor

  -- , case when HOSP_NUM != 1 then 1 else 0 end as exclusion_secondary_hospital_stay
  -- , case when ICUSTAY_NUM != 1 then 1 else 0 end as exclusion_secondary_icu_stay
  , case
        -- add first hospital stay
        when HOSP_NUM != 1 then 1
        when aiva.predictedhospitalmortality = '' then NULL
        when aiva.predictedhospitalmortality::NUMERIC > 0 then 0
      else 1 end as exclusion_by_apache

  from vw1
  -- check for apache values
  left join (select patientunitstayid, apachescore, predictedhospitalmortality from APACHEPATIENTRESULT where apacheversion = 'IVa') aiva
    on vw1.patientunitstayid = aiva.patientunitstayid
  left join adm
    on vw1.patientunitstayid = adm.patientunitstayid
)
select
    co.patientunitstayid
  , co.hospitalid

  -- admit/disch time is the first/last observed heart rate
  , co.admitoffset
  , co.dischoffset

  -- outcomes
  , co.hospital_expire_flag
  , co.icu_los
  , co.hosp_los
  , co.deathtime_hours

  , co.exclusion_non_adult
  , co.exclusion_bad_data
  , co.exclusion_organ_donor
  , co.exclusion_by_apache

  , GREATEST(
      co.exclusion_non_adult
    , co.exclusion_bad_data
    , co.exclusion_organ_donor
    , co.exclusion_by_apache
  ) as excluded
from co
order by co.patientunitstayid;
