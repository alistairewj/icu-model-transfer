# icu-model-transfer
Evaluating methods to improve model transfer for intensive care unit models.

This code supports the following paper: [Generalizability of predictive models for intensive care unit patients](https://arxiv.org/abs/1812.02275).

> A large volume of research has considered the creation of predictive models for clinical data; however, much existing literature reports results using only a single source of data. In this work, we evaluate the performance of models trained on the publicly-available eICU Collaborative Research Database. We show that cross-validation using many distinct centers provides a reasonable estimate of model performance in new centers. We further show that a single model trained across centers transfers well to distinct hospitals, even compared to a model retrained using hospital-specific data. Our results motivate the use of multi-center datasets for model development and highlight the need for data sharing among hospitals to maximize model performance.

```
@article{johnson2018generalizability,
  author    = {Alistair E. W. Johnson and
               Tom J. Pollard and
               Tristan Naumann},
  title     = {Generalizability of predictive models for intensive care unit patients},
  journal   = {Machine Learning for Health (ML4H) Workshop at NeurIPS 2018},
  year      = {2018},
  url       = {http://arxiv.org/abs/1812.02275},
  archivePrefix = {arXiv},
  eprint    = {1812.02275},
  timestamp = {Tue, 01 Jan 2019 15:01:25 +0100},
  biburl    = {https://dblp.org/rec/journals/corr/abs-1812-02275.bib},
  bibsource = {dblp computer science bibliography, https://dblp.org}
}
```

## Install

```bash
mkvirtualenv icu-model-transfer -p python3
pip install -r requirements.txt
python -m ipykernel install --name icu-model-transfer
```
