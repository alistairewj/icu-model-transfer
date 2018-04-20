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
    tr.icustay_id
  , ih.hr
  -- vitals
  , AVG(vi.HeartRate) as HeartRate
  , AVG(vi.SysBP) as SysBP
  , AVG(vi.DiasBP) as DiasBP
  , AVG(vi.MeanBP) as MeanBP
  , AVG(vi.RespRate) as RespRate
  , AVG(vi.TempC) as tempc
  , AVG(vi.SpO2) as spo2
  , AVG(coalesce(lab.GLUCOSE,bg.GLUCOSE,vi.Glucose)) as glucose

  -- gcs
  , CEIL(AVG(gcs.GCS)) as GCS

  -- blood gases
  -- oxygen related parameters
  , AVG(bg.PO2) as bg_pao2
  , AVG(bg.PCO2) as bg_paco2

  -- also calculate AADO2
  , AVG(bg.PaO2FiO2Ratio) as bg_PaO2FiO2Ratio

  -- acid-base parameters
  , AVG(bg.PH) as bg_PH
  , AVG(bg.BASEEXCESS) as bg_BASEEXCESS
  , AVG(bg.TOTALCO2) as bg_TOTALCO2

  -- labs
  -- , AVG(lab.ANIONGAP) as ANIONGAP -- TODO: should this be BG?
  , AVG(lab.ALBUMIN) as ALBUMIN
  , AVG(lab.BANDS) as BANDS
  , AVG(coalesce(lab.BICARBONATE,bg.BICARBONATE)) as BICARBONATE
  , AVG(lab.BILIRUBIN) as BILIRUBIN
  , AVG(lab.BUN) as BUN
  , AVG(bg.CALCIUM) as CALCIUM
  , AVG(lab.CREATININE) as CREATININE
  -- , AVG(coalesce(lab.CHLORIDE, bg.CHLORIDE)) as CHLORIDE
  , AVG(coalesce(lab.HEMATOCRIT,bg.HEMATOCRIT)) as HEMATOCRIT
  , AVG(coalesce(lab.HEMOGLOBIN,bg.HEMOGLOBIN)) as HEMOGLOBIN
  , AVG(lab.INR) as INR
  -- , lab.PT as PT -- PT and INR are redundant
  -- , AVG(lab.PTT) as PTT
  , AVG(coalesce(lab.LACTATE,bg.LACTATE)) as LACTATE
  , AVG(lab.PLATELET) as PLATELET
  , AVG(coalesce(lab.POTASSIUM, bg.POTASSIUM)) as POTASSIUM
  , AVG(coalesce(lab.SODIUM, bg.SODIUM)) as SODIUM
  , AVG(lab.WBC) as WBC

  , SUM(uo.UrineOutput) as urineoutput
-- source from our "base" cohort
from tr_cohort tr
-- add in every hour for their icu stay
inner join icustay_hours ih
  on tr.icustay_id = ih.icustay_id
-- now left join to all the data tables using the hours
left join pivoted_vital vi
  on  ih.icustay_id = vi.icustay_id
  and ih.endtime - interval '1' hour < vi.charttime
  and ih.endtime >= vi.charttime
left join pivoted_gcs gcs
  on  ih.icustay_id = gcs.icustay_id
  and ih.endtime - interval '1' hour < gcs.charttime
  and ih.endtime >= gcs.charttime
left join pivoted_uo uo
  on  ih.icustay_id = uo.icustay_id
  and ih.endtime - interval '1' hour < uo.charttime
  and ih.endtime >= uo.charttime
left join pivoted_bg_art bg
  on  tr.hadm_id = bg.hadm_id
  and ih.endtime - interval '1' hour < bg.charttime
  and ih.endtime >= bg.charttime
left join pivoted_lab lab
  on  tr.hadm_id = lab.hadm_id
  and ih.endtime - interval '1' hour < lab.charttime
  and ih.endtime >= lab.charttime
where tr.excluded = 0
group by tr.icustay_id, ih.hr
order by tr.icustay_id, ih.hr;
