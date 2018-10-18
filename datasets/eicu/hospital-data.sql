DROP TABLE IF EXISTS tr_hospital_data CASCADE;
CREATE TABLE tr_hospital_data as
with aiva as
(
  select patientunitstayid, apachescore, predictedhospitalmortality
    -- actual vent days is an integer truncated at 30
    , actualventdays::INTEGER as ventdays
  from apachepatientresult
  where apacheversion = 'IVa'
)
select
      h.hospitalid
    , h.numbedscategory
    , h.teachingstatus
    , h.region
    , count(tr.patientunitstayid) as num_pat
    -- icu type
    , sum(tr.hospital_expire_flag)::NUMERIC / count(tr.patientunitstayid) as frac_mortality
    -- disease variance
    -- ethnicity
    , AVG(age) as age
    , AVG(race_black) AS race_black
    , AVG(race_hispanic) AS race_hispanic
    , AVG(race_asian) AS race_asian
    , AVG(electivesurgery) AS electivesurgery
    , AVG(is_female) AS is_female
    , AVG(apachescore) AS apachescore
-- source from our "base" cohort
from hospital h
inner join tr_cohort tr
  on h.hospitalid = tr.hospitalid
inner join tr_static_data st
  on tr.patientunitstayid = st.patientunitstayid
-- apache score
left join aiva
  on tr.patientunitstayid = aiva.patientunitstayid
where tr.excluded = 0
group by h.hospitalid, h.numbedscategory, h.teachingstatus, h.region
order by h.hospitalid;
