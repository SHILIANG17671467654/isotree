#cython: auto_pickle=True

#     Isolation forests and variations thereof, with adjustments for incorporation
#     of categorical variables and missing values.
#     Writen for C++11 standard and aimed at being used in R and Python.
#     
#     This library is based on the following works:
#     [1] Liu, Fei Tony, Kai Ming Ting, and Zhi-Hua Zhou.
#         "Isolation forest."
#         2008 Eighth IEEE International Conference on Data Mining. IEEE, 2008.
#     [2] Liu, Fei Tony, Kai Ming Ting, and Zhi-Hua Zhou.
#         "Isolation-based anomaly detection."
#         ACM Transactions on Knowledge Discovery from Data (TKDD) 6.1 (2012): 3.
#     [3] Hariri, Sahand, Matias Carrasco Kind, and Robert J. Brunner.
#         "Extended Isolation Forest."
#         arXiv preprint arXiv:1811.02141 (2018).
#     [4] Liu, Fei Tony, Kai Ming Ting, and Zhi-Hua Zhou.
#         "On detecting clustered anomalies using SCiForest."
#         Joint European Conference on Machine Learning and Knowledge Discovery in Databases. Springer, Berlin, Heidelberg, 2010.
#     [5] https://sourceforge.net/projects/iforest/
#     [6] https://math.stackexchange.com/questions/3388518/expected-number-of-paths-required-to-separate-elements-in-a-binary-tree
#     [7] Quinlan, J. Ross. C4. 5: programs for machine learning. Elsevier, 2014.
# 
#     BSD 2-Clause License
#     Copyright (c) 2019, David Cortes
#     All rights reserved.
#     Redistribution and use in source and binary forms, with or without
#     modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright notice, this
#       list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
#     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#     AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#     IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#     DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
#     FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#     DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#     SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
#     CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#     OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#     OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import  numpy as np
cimport numpy as np
import pandas as pd
from scipy.sparse import issparse, isspmatrix_csc, isspmatrix_csr
from libcpp cimport bool as bool_t ###don't confuse it with Python bool
from libc.stdint cimport uint64_t
from libcpp.vector cimport vector
import ctypes

cdef extern from "isotree.hpp":
    ctypedef size_t sparse_ix

    ctypedef enum NewCategAction:
        Weighted
        Smallest
        Random

    ctypedef enum MissingAction:
        Divide
        Impute
        Fail

    ctypedef enum ColType:
        Numeric
        Categorical

    ctypedef enum CategSplit:
        SubSet
        SingleCateg

    ctypedef enum GainCriterion:
        Averaged
        Pooled
        NoCrit

    ctypedef enum CoefType:
        Uniform
        Normal

    ctypedef struct IsoTree:
        ColType       col_type
        size_t        col_num
        double        num_split
        vector[char]  cat_split
        int           chosen_cat
        size_t        tree_left
        size_t        tree_right
        double        pct_tree_left
        double        score
        double        range_low
        double        range_high
        double        remainder

    ctypedef struct IsoForest:
        vector[vector[IsoTree]] trees
        NewCategAction   new_cat_action
        CategSplit       cat_split_type
        MissingAction    missing_action
        double           exp_avg_depth
        double           exp_avg_sep
        size_t           orig_sample_size;

    ctypedef struct IsoHPlane:
        vector[size_t]    col_num
        vector[ColType]   col_type
        vector[double]    coef
        vector[vector[double]] cat_coef
        vector[int]       chosen_cat
        vector[double]    fill_val
        vector[double]    fill_new

        double   split_point
        size_t   hplane_left
        size_t   hplane_right
        double   score
        double   range_low
        double   range_high
        double   remainder

    ctypedef struct ExtIsoForest:
        vector[vector[IsoHPlane]] hplanes
        NewCategAction    new_cat_action
        CategSplit        cat_split_type
        MissingAction     missing_action
        double            exp_avg_depth
        double            exp_avg_sep
        size_t            orig_sample_size;


    int fit_iforest(IsoForest *model_outputs, ExtIsoForest *model_outputs_ext,
                    double *numeric_data,  size_t ncols_numeric,
                    int    *categ_data,    size_t ncols_categ,    int *ncat,
                    double *Xc, sparse_ix *Xc_ind, sparse_ix *Xc_indptr,
                    size_t ndim, size_t ntry, CoefType coef_type,
                    double *sample_weights, bool_t with_replacement, bool_t weight_as_sample,
                    size_t nrows, size_t sample_size, size_t ntrees, size_t max_depth,
                    bool_t limit_depth, bool_t penalize_range,
                    bool_t standardize_dist, double *tmat,
                    double *output_depths, bool_t standardize_depth,
                    double *col_weights, bool_t weigh_by_kurt,
                    double prob_pick_by_gain_avg, double prob_split_by_gain_avg,
                    double prob_pick_by_gain_pl,  double prob_split_by_gain_pl,
                    CategSplit cat_split_type, NewCategAction new_cat_action, MissingAction missing_action,
                    bool_t all_perm, uint64_t random_seed, int nthreads)

    void predict_iforest(double *numeric_data, int *categ_data,
                         double *Xc, sparse_ix *Xc_ind, sparse_ix *Xc_indptr,
                         double *Xr, sparse_ix *Xr_ind, sparse_ix *Xr_indptr,
                         size_t nrows, int nthreads, bool_t standardize,
                         IsoForest *model_outputs, ExtIsoForest *model_outputs_ext,
                         double *output_depths, size_t *tree_num)

    void tmat_to_dense(double *tmat, double *dmat, size_t n, bool_t diag_to_one)

    void calc_similarity(double *numeric_data, int *categ_data,
                         double *Xc, sparse_ix *Xc_ind, sparse_ix *Xc_indptr,
                         size_t nrows, int nthreads, bool_t assume_full_distr, bool_t standardize_dist,
                         IsoForest *model_outputs, ExtIsoForest *model_outputs_ext, double *tmat)

    int add_tree(IsoForest *model_outputs, ExtIsoForest *model_outputs_ext,
                 double *numeric_data,  size_t ncols_numeric,
                 int    *categ_data,    size_t ncols_categ,    int *ncat,
                 double *Xc, sparse_ix *Xc_ind, sparse_ix *Xc_indptr,
                 size_t ndim, size_t ntry, CoefType coef_type,
                 double *sample_weights,
                 size_t nrows, size_t max_depth,
                 bool_t   limit_depth,  bool_t penalize_range,
                 double *col_weights, bool_t weigh_by_kurt,
                 double prob_pick_by_gain_avg, double prob_split_by_gain_avg,
                 double prob_pick_by_gain_pl,  double prob_split_by_gain_pl,
                 CategSplit cat_split_type, NewCategAction new_cat_action, MissingAction missing_action,
                 bool_t  all_perm, uint64_t random_seed)



cdef double* get_ptr_dbl_vec(np.ndarray[double, ndim = 1] a):
    return &a[0]

cdef int* get_ptr_int_vec(np.ndarray[int, ndim = 1] a):
    return &a[0]

cdef size_t* get_ptr_szt_vec(np.ndarray[size_t, ndim = 1] a):
    return &a[0]

cdef double* get_ptr_dbl_mat(np.ndarray[double, ndim = 2] a):
    return &a[0, 0]

cdef int* get_ptr_int_mat(np.ndarray[int, ndim = 2] a):
    return &a[0, 0]


# @cython.auto_pickle(True)
cdef class isoforest_cpp_obj:
    cdef IsoForest     isoforest
    cdef ExtIsoForest  ext_isoforest

    def __init__(self):
        pass

    def get_cpp_obj(self, is_extended):
        if is_extended:
            return self.ext_isoforest
        else:
            return self.isoforest

    def fit_model(self, X_num, X_cat, ncat, sample_weights, col_weights,
                  size_t nrows, size_t ncols_numeric, size_t ncols_categ,
                  size_t ndim, size_t ntry, coef_type,
                  bool_t with_replacement, bool_t weight_as_sample,
                  size_t sample_size, size_t ntrees, size_t max_depth,
                  bool_t limit_depth, bool_t penalize_range,
                  bool_t calc_dist, bool_t standardize_dist, bool_t sq_dist,
                  bool_t calc_depth, bool_t standardize_depth,
                  bool_t weigh_by_kurt,
                  double prob_pick_by_gain_avg, double prob_split_by_gain_avg,
                  double prob_pick_by_gain_pl,  double prob_split_by_gain_pl,
                  cat_split_type, new_cat_action, missing_action,
                  bool_t all_perm, uint64_t random_seed, int nthreads):
        cdef double*     numeric_data_ptr    =  NULL
        cdef int*        categ_data_ptr      =  NULL
        cdef int*        ncat_ptr            =  NULL
        cdef double*     Xc_ptr              =  NULL
        cdef sparse_ix*  Xc_ind_ptr          =  NULL
        cdef sparse_ix*  Xc_indptr_ptr       =  NULL
        cdef double*     sample_weights_ptr  =  NULL
        cdef double*     col_weights_ptr     =  NULL

        if X_num is not None:
            if not issparse(X_num):
                numeric_data_ptr  =  get_ptr_dbl_mat(X_num)
            else:
                Xc_ptr         =  get_ptr_dbl_vec(X_num.data)
                Xc_ind_ptr     =  get_ptr_szt_vec(X_num.indices)
                Xc_indptr_ptr  =  get_ptr_szt_vec(X_num.indptr)
        if X_cat is not None:
            categ_data_ptr     =  get_ptr_int_mat(X_cat)
            ncat_ptr           =  get_ptr_int_vec(ncat)
        if sample_weights is not None:
            sample_weights_ptr =  get_ptr_dbl_vec(sample_weights)
        if col_weights is not None:
            col_weights_ptr    =  get_ptr_dbl_vec(col_weights)

        cdef CoefType        coef_type_C       =  Normal
        cdef CategSplit      cat_split_type_C  =  SubSet
        cdef NewCategAction  new_cat_action_C  =  Weighted
        cdef MissingAction   missing_action_C  =  Divide

        if coef_type == "uniform":
            coef_type_C       =  Uniform
        if cat_split_type == "single_categ":
            cat_split_type_C  =  SingleCateg
        if new_cat_action == "smallest":
            new_cat_action_C  =  Smallest
        elif new_cat_action == "random":
            new_cat_action_C  =  Random
        if missing_action == "impute":
            missing_action_C  =  Impute
        elif missing_action == "fail":
            missing_action_C  =  Fail

        cdef np.ndarray[double, ndim = 1]  tmat    =  np.empty(0, dtype = ctypes.c_double)
        cdef np.ndarray[double, ndim = 2]  dmat    =  np.empty((0, 0), dtype = ctypes.c_double)
        cdef np.ndarray[double, ndim = 1]  depths  =  np.empty(0, dtype = ctypes.c_double)
        cdef double*  tmat_ptr    =  NULL
        cdef double*  dmat_ptr    =  NULL
        cdef double*  depths_ptr  =  NULL

        if calc_dist:
            tmat      =  np.zeros(int((nrows * (nrows - 1)) / 2), dtype = ctypes.c_double)
            tmat_ptr  =  &tmat[0]
            if sq_dist:
                dmat      =  np.zeros((nrows, nrows), dtype = ctypes.c_double, order = 'F')
                dmat_ptr  =  &dmat[0, 0]
        if calc_depth:
            depths      =  np.zeros(nrows, dtype = ctypes.c_double)
            depths_ptr  =  &depths[0]

        cdef IsoForest* model_ptr         =  NULL
        cdef ExtIsoForest* ext_model_ptr  =  NULL
        if ndim == 1:
            self.isoforest      =  IsoForest()
            model_ptr           =  &self.isoforest
        else:
            self.ext_isoforest  =  ExtIsoForest()
            ext_model_ptr       =  &self.ext_isoforest


        fit_iforest(model_ptr, ext_model_ptr,
                    numeric_data_ptr,  ncols_numeric,
                    categ_data_ptr,    ncols_categ,    ncat_ptr,
                    Xc_ptr, Xc_ind_ptr, Xc_indptr_ptr,
                    ndim, ntry, coef_type_C,
                    sample_weights_ptr, with_replacement, weight_as_sample,
                    nrows, sample_size, ntrees, max_depth,
                    limit_depth, penalize_range,
                    standardize_dist, tmat_ptr,
                    depths_ptr, standardize_depth,
                    col_weights_ptr, weigh_by_kurt,
                    prob_pick_by_gain_avg, prob_split_by_gain_avg,
                    prob_pick_by_gain_pl,  prob_split_by_gain_pl,
                    cat_split_type_C, new_cat_action_C, missing_action_C,
                    all_perm, random_seed, nthreads)

        if (calc_dist) and (sq_dist):
            tmat_to_dense(tmat_ptr, dmat_ptr, nrows, <bool_t>(not standardize_dist))

        return depths, tmat, dmat

    def fit_tree(self, X_num, X_cat, ncat, sample_weights, col_weights,
                 size_t nrows, size_t ncols_numeric, size_t ncols_categ,
                 size_t ndim, size_t ntry, coef_type, size_t max_depth,
                 bool_t limit_depth, bool_t penalize_range,
                 bool_t weigh_by_kurt,
                 double prob_pick_by_gain_avg, double prob_split_by_gain_avg,
                 double prob_pick_by_gain_pl,  double prob_split_by_gain_pl,
                 cat_split_type, new_cat_action, missing_action,
                 bool_t all_perm, uint64_t random_seed):
        cdef double*     numeric_data_ptr    =  NULL
        cdef int*        categ_data_ptr      =  NULL
        cdef int*        ncat_ptr            =  NULL
        cdef double*     Xc_ptr              =  NULL
        cdef sparse_ix*  Xc_ind_ptr          =  NULL
        cdef sparse_ix*  Xc_indptr_ptr       =  NULL
        cdef double*     sample_weights_ptr  =  NULL
        cdef double*     col_weights_ptr     =  NULL

        if X_num is not None:
            if not issparse(X_num):
                numeric_data_ptr  =  get_ptr_dbl_mat(X_num)
            else:
                Xc_ptr         =  get_ptr_dbl_vec(X_num.data)
                Xc_ind_ptr     =  get_ptr_szt_vec(X_num.indices)
                Xc_indptr_ptr  =  get_ptr_szt_vec(X_num.indptr)
        if X_cat is not None:
            categ_data_ptr     =  get_ptr_int_mat(X_cat)
            ncat_ptr           =  get_ptr_int_vec(ncat)
        if sample_weights is not None:
            sample_weights_ptr  =  get_ptr_dbl_vec(sample_weights)
        if col_weights is not None:
            col_weights_ptr     =  get_ptr_dbl_vec(col_weights)

        cdef CoefType        coef_type_C       =  Normal
        cdef CategSplit      cat_split_type_C  =  SubSet
        cdef NewCategAction  new_cat_action_C  =  Weighted
        cdef MissingAction   missing_action_C  =  Divide

        if coef_type == "uniform":
            coef_type_C       =  Uniform
        if cat_split_type == "single_categ":
            cat_split_type_C  =  SingleCateg
        if new_cat_action == "smallest":
            new_cat_action_C  =  Smallest
        elif new_cat_action == "random":
            new_cat_action_C  =  Random
        if missing_action == "impute":
            missing_action_C  =  Impute
        elif missing_action == "fail":
            missing_action_C  =  Fail

        cdef IsoForest* model_ptr         =  NULL
        cdef ExtIsoForest* ext_model_ptr  =  NULL
        if ndim == 1:
            model_ptr           =  &self.isoforest
        else:
            ext_model_ptr       =  &self.ext_isoforest

        add_tree(model_ptr, ext_model_ptr,
                 numeric_data_ptr,  ncols_numeric,
                 categ_data_ptr,    ncols_categ,    ncat_ptr,
                 Xc_ptr, Xc_ind_ptr, Xc_indptr_ptr,
                 ndim, ntry, coef_type_C,
                 sample_weights_ptr,
                 nrows, max_depth,
                 limit_depth,  penalize_range,
                 col_weights_ptr, weigh_by_kurt,
                 prob_pick_by_gain_avg, prob_split_by_gain_avg,
                 prob_pick_by_gain_pl,  prob_split_by_gain_pl,
                 cat_split_type_C, new_cat_action_C, missing_action_C,
                 all_perm, random_seed)

    def predict(self, X_num, X_cat, is_extended,
                size_t nrows, int nthreads, bool_t standardize, bool_t output_tree_num):

        cdef double*     numeric_data_ptr  =  NULL
        cdef int*        categ_data_ptr    =  NULL
        cdef double*     Xc_ptr            =  NULL
        cdef sparse_ix*  Xc_ind_ptr        =  NULL
        cdef sparse_ix*  Xc_indptr_ptr     =  NULL
        cdef double*     Xr_ptr            =  NULL
        cdef sparse_ix*  Xr_ind_ptr        =  NULL
        cdef sparse_ix*  Xr_indptr_ptr     =  NULL

        if X_num is not None:
            if not issparse(X_num):
                numeric_data_ptr   =  get_ptr_dbl_mat(X_num)
            else:
                if isspmatrix_csc(X_num):
                    Xc_ptr         =  get_ptr_dbl_vec(X_num.data)
                    Xc_ind_ptr     =  get_ptr_szt_vec(X_num.indices)
                    Xc_indptr_ptr  =  get_ptr_szt_vec(X_num.indptr)
                else:
                    Xr_ptr         =  get_ptr_dbl_vec(X_num.data)
                    Xr_ind_ptr     =  get_ptr_szt_vec(X_num.indices)
                    Xr_indptr_ptr  =  get_ptr_szt_vec(X_num.indptr)

        if X_cat is not None:
            categ_data_ptr    =  get_ptr_int_mat(X_cat)

        cdef np.ndarray[double, ndim = 1] depths    =  np.zeros(nrows, dtype = ctypes.c_double)
        cdef np.ndarray[size_t, ndim = 2] tree_num  =  np.empty((0, 0), dtype = ctypes.c_size_t, order = 'F')
        cdef double* depths_ptr    =  &depths[0]
        cdef size_t* tree_num_ptr  =  NULL

        if output_tree_num:
            if is_extended:
                sz = self.ext_isoforest.hplanes.size()
            else:
                sz = self.isoforest.trees.size()
            tree_num      =  np.empty((nrows, sz), dtype = ctypes.c_size_t, order = 'F')
            tree_num_ptr  =  &tree_num[0, 0]

        cdef IsoForest* model_ptr         =  NULL
        cdef ExtIsoForest* ext_model_ptr  =  NULL
        if not is_extended:
            model_ptr      =  &self.isoforest
        else:
            ext_model_ptr  =  &self.ext_isoforest
        
        predict_iforest(numeric_data_ptr, categ_data_ptr,
                        Xc_ptr, Xc_ind_ptr, Xc_indptr_ptr,
                        Xr_ptr, Xr_ind_ptr, Xr_indptr_ptr,
                        nrows, nthreads, standardize,
                        model_ptr, ext_model_ptr,
                        depths_ptr, tree_num_ptr)

        return depths, tree_num


    def dist(self, X_num, X_cat, is_extended,
             size_t nrows, int nthreads, bool_t assume_full_distr,
             bool_t standardize_dist,    bool_t sq_dist):

        cdef double*     numeric_data_ptr  =  NULL
        cdef int*        categ_data_ptr    =  NULL
        cdef double*     Xc_ptr            =  NULL
        cdef sparse_ix*  Xc_ind_ptr        =  NULL
        cdef sparse_ix*  Xc_indptr_ptr     =  NULL

        if X_num is not None:
            if not issparse(X_num):
                numeric_data_ptr  =  get_ptr_dbl_mat(X_num)
            else:
                Xc_ptr         =  get_ptr_dbl_vec(X_num.data)
                Xc_ind_ptr     =  get_ptr_szt_vec(X_num.indices)
                Xc_indptr_ptr  =  get_ptr_szt_vec(X_num.indptr)
        if X_cat is not None:
            categ_data_ptr     =  get_ptr_int_mat(X_cat)

        cdef np.ndarray[double, ndim = 1]  tmat    =  np.empty(0, dtype = ctypes.c_double)
        cdef np.ndarray[double, ndim = 2]  dmat    =  np.empty((0, 0), dtype = ctypes.c_double)
        cdef double*  tmat_ptr    =  NULL
        cdef double*  dmat_ptr    =  NULL

        tmat      =  np.zeros(int((nrows * (nrows - 1)) / 2), dtype = ctypes.c_double)
        tmat_ptr  =  &tmat[0]
        if sq_dist:
            dmat      =  np.zeros((nrows, nrows), dtype = ctypes.c_double, order = 'F')
            dmat_ptr  =  &dmat[0, 0]

        cdef IsoForest* model_ptr         =  NULL
        cdef ExtIsoForest* ext_model_ptr  =  NULL
        if not is_extended:
            model_ptr      =  &self.isoforest
        else:
            ext_model_ptr  =  &self.ext_isoforest
        
        calc_similarity(numeric_data_ptr, categ_data_ptr,
                        Xc_ptr, Xc_ind_ptr, Xc_indptr_ptr,
                        nrows, nthreads, assume_full_distr, standardize_dist,
                        model_ptr, ext_model_ptr, tmat_ptr)

        if (sq_dist):
            tmat_to_dense(tmat_ptr, dmat_ptr, nrows, <bool_t>(not standardize_dist))

        return tmat, dmat