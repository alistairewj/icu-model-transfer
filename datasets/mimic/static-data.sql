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
  select cs.icustay_id
    , min(cs.charttime) as censortime
  from tr_code_status cs
  where GREATEST(cmo,dnr,dni,dncpr)>0
  group by cs.icustay_id
)
-- identify surgeries using first hospital service
, surgflag as
(
  select ie.icustay_id
    , max(case
        when lower(curr_service) like '%surg%' then 1
        when curr_service = 'ORTHO' then 1
    else 0 end) as surgical
  from icustays ie
  left join services se
    on ie.hadm_id = se.hadm_id
    and se.transfertime < ie.intime + interval '1' day
  group by ie.icustay_id
)
, vd as
(
  select icustay_id
    , LEAST(
        CEIL(sum(duration_hours)/24.0)::INTEGER
        , 30::INTEGER) as ventdays
  FROM ventdurations
  group by icustay_id
)
SELECT
  co.icustay_id
  , 0::SMALLINT as hospitalid

  -- ======== --
  -- Outcomes --
  -- ======== --

  , ceil(extract(epoch from (co.outtime - co.intime))/60.0/60.0) as dischtime_hours
  , ceil(extract(epoch from (adm.deathtime - co.intime))/60.0/60.0) as deathtime_hours
  , case when adm.deathtime is null then 0 else 1 end as death
  , COALESCE(vd.ventdays, 0) as ventdays

  -- code status
  , ceil(extract(epoch from cs.censortime-co.intime )/60.0/60.0) as censortime_hours

  -- ====================== --
  -- Patient level factors --
  -- ====================== --

  , case when pat.gender = 'F' then 1 else 0 end as is_female
  -- use lowest to replace ages > 89 with 90
  , LEAST(
      ROUND( (CAST(co.intime AS DATE) - CAST(pat.dob AS DATE))  / 365.242, 4)
      , 90
    ) AS age

  -- ethnicity flags
  -- , case when adm.ethnicity in
  -- (
  --      'WHITE' --  40996
  --    , 'WHITE - RUSSIAN' --    164
  --    , 'WHITE - OTHER EUROPEAN' --     81
  --    , 'WHITE - BRAZILIAN' --     59
  --    , 'WHITE - EASTERN EUROPEAN' --     25
  -- ) then 1 else 0 end as race_white

  , case when adm.ethnicity in
  (
        'BLACK/AFRICAN AMERICAN' --   5440
      , 'BLACK/CAPE VERDEAN' --    200
      , 'BLACK/HAITIAN' --    101
      , 'BLACK/AFRICAN' --     44
      , 'CARIBBEAN ISLAND' --      9
  ) then 1 else 0 end as race_black
  , case when adm.ethnicity in
  (
    'HISPANIC OR LATINO' --   1696
  , 'HISPANIC/LATINO - PUERTO RICAN' --    232
  , 'HISPANIC/LATINO - DOMINICAN' --     78
  , 'HISPANIC/LATINO - GUATEMALAN' --     40
  , 'HISPANIC/LATINO - CUBAN' --     24
  , 'HISPANIC/LATINO - SALVADORAN' --     19
  , 'HISPANIC/LATINO - CENTRAL AMERICAN (OTHER)' --     13
  , 'HISPANIC/LATINO - MEXICAN' --     13
  , 'HISPANIC/LATINO - COLOMBIAN' --      9
  , 'HISPANIC/LATINO - HONDURAN' --      4
  ) then 1 else 0 end as race_hispanic
  , case when adm.ethnicity in
  (
      'ASIAN' --   1509
    , 'ASIAN - CHINESE' --    277
    , 'ASIAN - ASIAN INDIAN' --     85
    , 'ASIAN - VIETNAMESE' --     53
    , 'ASIAN - FILIPINO' --     25
    , 'ASIAN - CAMBODIAN' --     17
    , 'ASIAN - OTHER' --     17
    , 'ASIAN - KOREAN' --     13
    , 'ASIAN - JAPANESE' --      7
    , 'ASIAN - THAI' --      4
  ) then 1 else 0 end as race_asian
  , case when adm.ethnicity in
  (
      'UNKNOWN/NOT SPECIFIED' --   4523
    , 'OTHER' --   1512
    , 'UNABLE TO OBTAIN' --    814
    , 'PATIENT DECLINED TO ANSWER' --    559
    , 'MULTI RACE ETHNICITY' --    130
    , 'PORTUGUESE' --     61
    , 'AMERICAN INDIAN/ALASKA NATIVE' --     51
    , 'MIDDLE EASTERN' --     43
    , 'NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER' --     18
    , 'SOUTH AMERICAN' --      8
    , 'AMERICAN INDIAN/ALASKA NATIVE FEDERALLY RECOGNIZED TRIBE' --      3
  ) then 1 else 0 end as race_other

  , case
      when adm.ADMISSION_TYPE = 'ELECTIVE' and sf.surgical = 1
        then 1
      else 0
    end as ElectiveSurgery

FROM tr_cohort co
INNER JOIN icustays ie
  ON co.icustay_id = ie.icustay_id
INNER JOIN admissions adm
  ON co.hadm_id = adm.hadm_id
INNER JOIN patients pat
  ON co.subject_id = pat.subject_id
LEFT JOIN cs
  ON co.icustay_id = cs.icustay_id
LEFT JOIN surgflag sf
  ON co.icustay_id = sf.icustay_id
LEFT JOIN vd
  ON co.icustay_id = vd.icustay_id
ORDER BY co.icustay_id;
