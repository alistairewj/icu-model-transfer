# Import libraries
import numpy as np
import pandas as pd
import psycopg2
import sys
import datetime as dt
from sklearn import metrics
import matplotlib.pyplot as plt

def vars_of_interest():
    """
    Define feature extraction method for each variable.
    This is done with hard-coded lists of features for simple feature extractions.
    e.g. var_min is a list of variables where we will extract the minimum.
    """
    # we extract the min/max for these covariates
    var_min = ['heartrate', 'sysbp', 'diasbp', 'meanbp',
                'resprate', 'tempc', 'spo2']
    var_max = var_min
    var_min.append('gcs')

    # we extract the first/last value for these covariates
    var_first = ['heartrate', 'sysbp', 'diasbp', 'meanbp',
                'resprate', 'tempc', 'spo2',
                'bg_pao2', 'bg_paco2',
                'bg_pao2fio2ratio', 'bg_ph', 'bg_baseexcess',
                'albumin', 'bands', 'bicarbonate', 'bilirubin', 'bun',
                'calcium', 'creatinine',
                'glucose', 'hematocrit', 'hemoglobin', 'inr',
                'lactate', 'platelet', 'potassium', 'sodium',  'wbc']

    var_last = var_first
    var_last.append('gcs')

    # for UO, sum all values in window
    var_sum = ['urineoutput']

    # extend the window backward by W hours (user specified) for these variables
    var_extend = ['bg_pao2', 'bg_paco2',
            'bg_pao2fio2ratio', 'bg_ph', 'bg_baseexcess',
            'albumin', 'bands', 'bicarbonate', 'bilirubin', 'bun',
            'calcium', 'creatinine',
            'glucose', 'hematocrit', 'hemoglobin', 'inr',
            'lactate', 'platelet', 'potassium', 'sodium',  'wbc']


    return var_min, var_max, var_first, var_last, var_sum, var_extend

def drop_patients(co):
    """
    Drop rows (patients) using exclusion columns and, if present, windowtime_hours.
    """
    # drop patients as appropriate
    idxRem = np.zeros(co.shape[0], dtype=bool)
    for c in co.columns:
        if 'exclusion_' in c:
            idxRemCurrent = co[c]==1
            print('{:6d} removed due to {}'.format(
                    idxRemCurrent.sum(), c))
            idxRem = idxRem | idxRemCurrent

    print('')
    print('{:6d} ({:4.2f}%) removed so far.'.format(
            idxRem.sum(),idxRem.mean()*100.0, c))

    if 'windowtime_hours' in co.columns:
        idxRemCurrent = co['windowtime_hours'].isnull()
        print('  extra {:6d} removed due to window time.'.format(
                (~idxRem & idxRemCurrent).sum(), c))
        idxRem = idxRem | idxRemCurrent

    co = co.loc[~idxRem, :]
    print('\n{:6d} ({:4.2f}%) - final cohort size.'.format(
            co.shape[0],(~idxRem).mean()*100.0, c))

    return co

def get_design_matrix(df, time_dict, pt_id_col='icustay_id', W=8, W_extra=24):
    """
    For the given dataframe with a patient and hour column ("hr"), extract
    features from a fixed window ending according to time_dict
    and beginning time_dict[patient]-W, or time_dict[patient]-W-W_extra,
    as appropriate.
    """
    # W_extra is the number of extra hours to look backward for labs
    # e.g. if W_extra=24 we look back an extra 24 hours for lab values

    # timing info for icustay_id < 200100:
    #   5 loops, best of 3: 877 ms per loop

    # timing info for all icustay_id:
    #   5 loops, best of 3: 1.48 s per loop

    # get the hardcoded variable names
    var_min, var_max, var_first, var_last, var_sum, var_extend = vars_of_interest()

    tmp = np.asarray(time_dict.items()).astype(int)
    N = tmp.shape[0]

    M = W+W_extra
    # create a vector of [0,...,M] to represent the hours we need to subtract for each icustay_id
    hr = np.linspace(0,M,M+1,dtype=int)
    hr = np.reshape(hr,[1,M+1])
    hr = np.tile(hr,[N,1])
    hr = np.reshape(hr, [N*(M+1),], order='F')

    # duplicate tmp to M+1, as we will be creating T+1 rows for each icustay_id
    tmp = np.tile(tmp,[M+1,1])

    # adding hr to tmp[:,1] gives us what we want: integers in the range [Tn-T, Tn]
    tmp = np.column_stack([tmp[:,0], tmp[:,1]-hr, hr>W])

    # create dataframe with tmp
    df_time = pd.DataFrame(data=tmp, index=None, columns=[pt_id_col,'hr','early_flag'])
    df_time.sort_values([pt_id_col,'hr'],inplace=True)

    # merge df_time with df to filter down to a subset of rows
    df = df.merge(df_time, left_on=[pt_id_col,'hr'], right_on=[pt_id_col,'hr'],how='inner')

    df_grp = df.groupby(pt_id_col)

    # figure out which variables we need to extend get extended variables
    var_first_early = [x for x in var_first if x in var_extend]
    var_last_early = [x for x in var_last if x in var_extend]
    var_min_early = [x for x in var_min if x in var_extend]
    var_max_early = [x for x in var_max if x in var_extend]

    # apply functions to groups of vars
    df_first_early = None
    df_last_early = None
    df_min_early = None
    df_max_early = None

    if len(var_first_early)>0:
        df_first_early = df_grp[var_first_early].first()
        df_first_early.columns = [x + '_first_early' for x in df_first_early.columns]
        # remove these columns from the original variable list
        # this avoids a double data extraction
        var_first = [x for x in var_first if x not in var_first_early]

    if len(var_last_early)>0:
        df_last_early  = df_grp[var_last_early].last()
        df_last_early.columns = [x + '_last_early' for x in df_last_early.columns]
        var_last = [x for x in var_last if x not in var_last_early]

    if len(var_min_early)>0:
        df_min_early   = df_grp[var_min_early].min()
        df_min_early.columns = [x + '_min_early' for x in df_min_early.columns]
        var_min = [x for x in var_min if x not in var_min_early]

    if len(var_max_early)>0:
        df_max_early   = df_grp[var_max_early].max()
        df_max_early.columns = [x + '_max_early' for x in df_max_early.columns]
        var_max = [x for x in var_max if x not in var_max_early]

    # slice down df_time by removing early times
    # isolate only have data from [t - W, t - W + 1, ..., t]
    df = df.loc[df['early_flag']==0,:]
    df_grp = df.groupby(pt_id_col)

    df_first = df_grp[var_first].first()
    df_last  = df_grp[var_last].last()
    df_min = df_grp[var_min].min()
    df_max = df_grp[var_max].max()
    df_sum = df_grp[var_sum].sum()

    # update the column names
    df_first.columns = [x + '_first' for x in df_first.columns]
    df_last.columns = [x + '_last' for x in df_last.columns]
    df_min.columns = [x + '_min' for x in df_min.columns]
    df_max.columns = [x + '_max' for x in df_max.columns]
    df_sum.columns = [x + '_sum' for x in df_sum.columns]

    # now combine all the arrays together
    df_data = pd.concat([
    df_first, df_first_early, df_last, df_last_early,
    df_min, df_min_early, df_max, df_max_early,
    df_sum], axis=1)

    return df_data
