-- FINAL DATA TABLE!
-- This combines (1) the base cohort with (2) materialized views to get patient data
-- The result is a table which is (N*Hn)xM
--  Rows: N patients times Hn hours for each patient (hours is variable)
--  Columns: M features
-- the "hr" column is the integer hour since ICU admission
-- it can be negative since some labs are measured before ICU admission
DROP TABLE IF EXISTS tr_data CASCADE;
CREATE TABLE tr_data as
select
    tr.patientunitstayid
  , ih.hr
  , AVG(vi.HeartRate) as HeartRate
  , AVG(coalesce(vi.ibp_systolic, vi.nibp_systolic)) as SysBP
  , AVG(coalesce(vi.ibp_diastolic, vi.nibp_diastolic)) as DiasBP
  , AVG(coalesce(vi.map, vi.ibp_mean, vi.nibp_mean)) as MeanBP
  , AVG(vi.respiratoryrate) as RespRate
  , AVG(vi.temperature) as tempc
  , AVG(vi.o2saturation) as spo2
  , AVG(lab.glucose) as glucose

  -- gcs
  , CEIL(AVG(vi.GCS)) as GCS

  -- blood gases
  -- oxygen related parameters
  , AVG(bg.pao2) as bg_pao2
  , AVG(bg.paco2) as bg_paco2

  -- also calculate AADO2
  -- , bg.AADO2 as bg_AADO2
  --, AADO2_calc
  , AVG(CASE WHEN bg.pao2 IS NOT NULL
          AND bg.fio2 IS NOT NULL
        THEN bg.pao2/bg.fio2 ELSE NULL END) as bg_PaO2FiO2Ratio

  -- acid-base parameters
  , AVG(bg.ph) as bg_PH
  , AVG(bg.baseexcess) as bg_BASEEXCESS
  -- , AVG(bg.ANIONGAP) as ANIONGAP

  -- labs
  , AVG(lab.ALBUMIN) as ALBUMIN
  , AVG(lab.BANDS) as BANDS
  , AVG(lab.hco3) as BICARBONATE
  , AVG(lab.BILIRUBIN) as BILIRUBIN
  , AVG(lab.BUN) as BUN
  , AVG(lab.CALCIUM) as CALCIUM
  , AVG(lab.CREATININE) as CREATININE
  -- , AVG(lab.CHLORIDE) as CHLORIDE
  , AVG(lab.HEMATOCRIT) as HEMATOCRIT
  , AVG(lab.HEMOGLOBIN) as HEMOGLOBIN
  , AVG(lab.INR) as INR
  -- , lab.PT as PT -- PT and INR are redundant
  -- , AVG(lab.PTT) as PTT
  , AVG(lab.LACTATE) as LACTATE
  , AVG(lab.PLATELETS) as PLATELET
  , AVG(lab.POTASSIUM) as POTASSIUM
  , AVG(lab.SODIUM) as SODIUM
  , AVG(lab.WBC) as WBC

  , SUM(uo.UrineOutput) as urineoutput
-- source from our "base" cohort
from tr_cohort tr
-- add in every hour for their icu stay
inner join tr_icustay_hours ih
  on tr.patientunitstayid = ih.patientunitstayid
-- now left join to all the data tables using the hours
left join pivoted_vital vi
  on  ih.patientunitstayid = vi.patientunitstayid
  and ih.endoffset - 60 < vi.chartoffset
  and ih.endoffset >= vi.chartoffset
left join pivoted_uo uo
  on  ih.patientunitstayid = uo.patientunitstayid
  and ih.endoffset - 60 < uo.chartoffset
  and ih.endoffset >= uo.chartoffset
left join pivoted_bg bg
  on  tr.patientunitstayid = bg.patientunitstayid
  and ih.endoffset - 60 < bg.chartoffset
  and ih.endoffset >= bg.chartoffset
left join pivoted_lab lab
  on  tr.patientunitstayid = lab.patientunitstayid
  and ih.endoffset - 60 < lab.chartoffset
  and ih.endoffset >= lab.chartoffset
where tr.excluded = 0
group by tr.patientunitstayid, ih.hr
order by tr.patientunitstayid, ih.hr;
