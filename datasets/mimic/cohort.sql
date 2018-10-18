DROP TABLE IF EXISTS tr_cohort CASCADE;
CREATE TABLE tr_cohort AS
with ce as
(
  -- adjust the intime to be based on the heart rate
  -- this handles some fuzziness associated with administrative intime/outtime
  select ce.icustay_id
    -- we ceiling this to the nearest hour
    -- we do this by adding 59 minutes then truncating
    , date_trunc('hour',min(charttime) + interval '59' minute) as intime_hr
    , date_trunc('hour',max(charttime) + interval '59' minute) as outtime_hr
  from chartevents ce
  inner join icustays ie
    on ce.icustay_id = ie.icustay_id
    and ce.charttime > ie.intime - interval '12' hour
    and ce.charttime < ie.outtime + interval '12' hour
  where itemid in (211,220045)
  group by ce.icustay_id
)
, co as
(
  select
      ie.subject_id, ie.hadm_id, ie.icustay_id
    , ce.intime_hr as intime
    , ce.outtime_hr as outtime
    , round((cast(adm.admittime as date) - cast(pat.dob as date)) / 365.242, 4) as age
    , pat.gender
    , adm.ethnicity

    -- outcomes
    , adm.HOSPITAL_EXPIRE_FLAG
    , ie.los as icu_los
    , extract(epoch from (adm.dischtime - adm.admittime))/60.0/60.0/24.0 as hosp_los
    , ceil(extract(epoch from (adm.deathtime - ce.intime_hr))/60.0/60.0) as deathtime_hours

  -- exclusions
  , case
      when round((cast(adm.admittime as date) - cast(pat.dob as date)) / 365.242, 4) <= 16
        then 1
      else 0 end
    as exclusion_non_adult
  , case when adm.HAS_CHARTEVENTS_DATA = 0 then 1
         when ie.intime is null then 1
         when ie.outtime is null then 1
         when ce.intime_hr is null then 1
         when ce.outtime_hr is null then 1
      else 0 end
    as exclusion_bad_data

  -- organ donor accounts
  , case when (
         (lower(diagnosis) like '%organ donor%' and deathtime is not null)
      or (lower(diagnosis) like '%donor account%' and deathtime is not null)
    ) then 1 else 0 end
    as exclusion_organ_donor

  , CASE
      WHEN ROW_NUMBER() OVER (PARTITION BY ie.subject_id ORDER BY ie.intime) > 1 THEN 1
      WHEN (ce.outtime_hr-ce.intime_hr) <= interval '4' hour then 1
    else 0 end as exclusion_by_apache

  -- metavision flag
  , (CASE
      WHEN ie.dbsource = 'metavision'
        THEN 1
      ELSE 0
    END)::SMALLINT as metavision

  -- the above flags are used to summarize patients excluded
  -- below flag is used to actually exclude patients in future queries
  , case  when round((cast(adm.admittime as date) - cast(pat.dob as date)) / 365.242, 4) <= 16 then 1
          when adm.HAS_CHARTEVENTS_DATA = 0 then 1
          when ie.intime is null then 1
          when ie.outtime is null then 1
          when ce.intime_hr is null then 1
          when ce.outtime_hr is null then 1
          when (ce.outtime_hr-ce.intime_hr) <= interval '4' hour then 1
          when ((lower(diagnosis) like '%organ donor%' and deathtime is not null)
              or (lower(diagnosis) like '%donor account%' and deathtime is not null)) then 1
        else 0 end as excluded
  from icustays ie
  inner join admissions adm
    on ie.hadm_id = adm.hadm_id
  inner join patients pat
    on ie.subject_id = pat.subject_id
  left join ce
    on ie.icustay_id = ce.icustay_id
)
select
co.subject_id, co.hadm_id, co.icustay_id
-- hospitalid=1 is metavision
-- hospitalid=0 is carevue
, co.metavision as hospitalid
, co.intime
, co.outtime
, co.age
, co.gender
, co.ethnicity

-- outcomes
, co.hospital_expire_flag
, co.icu_los
, co.hosp_los
, co.deathtime_hours

-- exclusions
, co.exclusion_non_adult
, co.exclusion_bad_data
, co.exclusion_organ_donor
, co.exclusion_by_apache

-- the above flags are used to summarize patients excluded
-- below flag is used to actually exclude patients in future queries
, GREATEST(
    co.exclusion_non_adult
  , co.exclusion_bad_data
  , co.exclusion_organ_donor
  , co.exclusion_by_apache
) as excluded
from co
order by co.icustay_id;
