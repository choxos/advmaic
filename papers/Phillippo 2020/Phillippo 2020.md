![Wiley Open Access Collection logo](https://cdn.ncbi.nlm.nih.gov/pmc/banners/logo-blackwellopen.png)

Res Synth Methods

. 2020 May 27;11(4):568–572. doi: [10.1002/jrsm.1416](https://doi.org/10.1002/jrsm.1416)

*   [Search in PMC](https://pmc.ncbi.nlm.nih.gov/search/?term=%22Res%20Synth%20Methods%22%5Bjour%5D)
*   [Search in PubMed](https://pubmed.ncbi.nlm.nih.gov/?term=%22Res%20Synth%20Methods%22%5Bjour%5D)
*   [View in NLM Catalog](https://www.ncbi.nlm.nih.gov/nlmcatalog?term=%22Res%20Synth%20Methods%22%5BTitle%20Abbreviation%5D)
*   [Add to search](?term=%22Res%20Synth%20Methods%22%5Bjour%5D)

Equivalence of entropy balancing and the method of moments for matching‐adjusted indirect comparison
====================================================================================================

[David M Phillippo](https://pubmed.ncbi.nlm.nih.gov/?term=%22Phillippo%20DM%22%5BAuthor%5D)

### David M Phillippo

1Bristol Medical School (Population Health Sciences), University of Bristol, Bristol, UK

Find articles by [David M Phillippo](https://pubmed.ncbi.nlm.nih.gov/?term=%22Phillippo%20DM%22%5BAuthor%5D)

1,✉, [Sofia Dias](https://pubmed.ncbi.nlm.nih.gov/?term=%22Dias%20S%22%5BAuthor%5D)

### Sofia Dias

1Bristol Medical School (Population Health Sciences), University of Bristol, Bristol, UK

2Centre for Reviews and Dissemination, University of York, York, UK

Find articles by [Sofia Dias](https://pubmed.ncbi.nlm.nih.gov/?term=%22Dias%20S%22%5BAuthor%5D)

1,2, [A E Ades](https://pubmed.ncbi.nlm.nih.gov/?term=%22Ades%20AE%22%5BAuthor%5D)

### A E Ades

1Bristol Medical School (Population Health Sciences), University of Bristol, Bristol, UK

Find articles by [A E Ades](https://pubmed.ncbi.nlm.nih.gov/?term=%22Ades%20AE%22%5BAuthor%5D)

1, [Nicky J Welton](https://pubmed.ncbi.nlm.nih.gov/?term=%22Welton%20NJ%22%5BAuthor%5D)

### Nicky J Welton

1Bristol Medical School (Population Health Sciences), University of Bristol, Bristol, UK

Find articles by [Nicky J Welton](https://pubmed.ncbi.nlm.nih.gov/?term=%22Welton%20NJ%22%5BAuthor%5D)

1

*   Author information
*   Article notes
*   Copyright and License information

1Bristol Medical School (Population Health Sciences), University of Bristol, Bristol, UK

2Centre for Reviews and Dissemination, University of York, York, UK

\*

**Correspondence**, David M. Phillippo, Bristol Medical School (Population Health Sciences), University of Bristol, Canynge Hall, 39 Whatley Road, Bristol BS8 2PS, UK. Email: david.phillippo@bristol.ac.uk

✉

Corresponding author.

Received 2020 Mar 9; Revised 2020 May 6; Accepted 2020 May 6; Issue date 2020 Jul.

© 2020 The Authors. _Research Synthesis Methods_ published by John Wiley & Sons Ltd.

This is an open access article under the terms of the [http://creativecommons.org/licenses/by/4.0/](http://creativecommons.org/licenses/by/4.0/) License, which permits use, distribution and reproduction in any medium, provided the original work is properly cited.

[PMC Copyright notice](/about/copyright/)

PMCID: PMC7384548  PMID: [32395870](https://pubmed.ncbi.nlm.nih.gov/32395870/)

Abstract
--------

Indirect comparisons are used to obtain estimates of relative effectiveness between two treatments that have not been compared in the same randomized controlled trial, but have instead been compared against a common comparator in separate trials. Standard indirect comparisons use only aggregate data, under the assumption that there are no differences in effect‐modifying variables between the trial populations. Population‐adjusted indirect comparisons aim to relax this assumption by using individual patient data (IPD) from one trial to adjust for differences in effect modifiers between populations. At present, the most commonly used approach is matching‐adjusted indirect comparison (MAIC), where weights are estimated that match the covariate distributions of the reweighted IPD to the aggregate trial. MAIC was originally proposed using the method of moments to estimate the weights, but more recently entropy balancing has been proposed as an alternative. Entropy balancing has an additional “optimality” property ensuring that the weights are as uniform as possible, reducing the standard error of the estimates. In this brief method note, we show that MAIC weights are mathematically identical whether estimated using entropy balancing or the method of moments. Importantly, this means that the standard MAIC (based on the method of moments) also enjoys the “optimality” property. Moreover, the additional flexibility of entropy balancing suggests several interesting avenues for further research, such as combining population adjustment via MAIC with adjustments for treatment switching or nonparametric covariate adjustment.

**Keywords:** effect modification, indirect comparison, individual patient data, matching‐adjusted indirect comparison, population adjustment

1\. INTRODUCTION
----------------

Estimates of relative treatment effects are required for health care decision‐making, for example, in health technology assessment or regulatory/reimbursement decisions. A common scenario encountered is where two treatments of interest, say _B_ and _C_, have not been compared head‐to‐head in the same randomized controlled trial, but instead are compared against a common comparator _A_ in separate _AB_ and _AC_ trials. In such scenarios, an indirect comparisons [1](#jrsm1416-bib-0001) may be used to obtain an estimate of the relative effect of _C_ vs _B_, denoted _d_ BC, by comparing the relative effect estimates reported in the _AB_ and _AC_ trials as ^𝑑𝐵𝐶 \=^𝑑𝐴𝐶 −^𝑑𝐴𝐵 (on a suitable scale, eg, log odds ratios, log hazard ratios, or mean differences). However, if there are differences in effect‐modifying variables between the two study populations, this indirect comparison will be biased.[2](#jrsm1416-bib-0002), [3](#jrsm1416-bib-0003) If individual patient data (IPD) are available from both the _AB_ and _AC_ study, standard regression or weighting methods may be used to adjust for differences in effect‐modifying variables between the study populations. However, it is common for IPD to only be available from one study and published aggregate data from the other. For example, in health technology assessment a company submits evidence of clinical and cost effectiveness to a reimbursement body such as the National Institute for Health and Care Excellence in England and Wales. The submitting company will typically have IPD from their own trial (say _AB_), but only published aggregate data from their competitor's trial (_AC_).

Methods for population‐adjusted indirect comparison have been proposed that aim to adjust for any differences in observed effect modifiers between populations, using IPD from one study and aggregate data from another.[2](#jrsm1416-bib-0002), [3](#jrsm1416-bib-0003) At present, the most commonly used approach[2](#jrsm1416-bib-0002), [4](#jrsm1416-bib-0004) is _matching‐adjusted indirect comparison_ (MAIC). [5](#jrsm1416-bib-0005) MAIC is a weighting approach, where weights _w_ _ik_ are estimated so that the weighted covariate distribution in the _AB_ study matches that of the _AC_ study. Using these weights, mean outcome on treatments _k_ = _A_, _B_ in the _AC_ population are estimated by taking a weighted average of the outcomes _y_ _ik_(_AB_) of the _N_ _k_(_AB_) individuals _i_ on treatment _k_ in the _AB_ population

^𝑦𝑘⁡(𝐴𝐶)\=∑𝑁𝑘⁡(𝐴𝐵)𝑖\=1𝑦𝑖𝑘⁡(𝐴𝐵)⁢𝑤𝑖𝑘∑𝑁𝑘⁡(𝐴𝐵)𝑖\=1𝑤𝑖𝑘.

(1)

A population‐adjusted indirect comparison is then constructed in the _AC_ study population as

^𝑑𝐵𝐶⁡(𝐴𝐶)\=^𝑑𝐴𝐶⁡(𝐴𝐶)−^𝑑𝐴𝐵⁡(𝐴𝐶),

(2)

where ^𝑑𝐴𝐵⁡(𝐴𝐶) \=𝑔⁡(^𝑦𝐵⁡(𝐴𝐶)) −𝑔⁡(^𝑦𝐴⁡(𝐴𝐶)) for a suitable link function _g_(·), and ^𝑑𝐴𝐶⁡(𝐴𝐶) is reported by the _AC_ study.

Signorovitch et al [5](#jrsm1416-bib-0005) proposed to estimate the weights _w_ _ik_ using the method of moments to balance the mean covariate values (and any included higher order terms, for example squared covariate values to balance the variance) between the weighted _AB_ population and the _AC_ population. Belger et al[6](#jrsm1416-bib-0006), [7](#jrsm1416-bib-0007) suggest another form of population reweighting based on entropy balancing, [8](#jrsm1416-bib-0008) which matches moments of the covariate distributions under the additional constraint that the optimal entropy balancing weights are those which are as close as possible to uniform weights (ie, as close as possible to no weighting at all). This additional constraint means that entropy balancing methods should (at least for homoskedastic outcomes) have equal or reduced SE (and equal or greater effective sample size) compared to MAIC, while achieving the same reduction in bias. However, as we now show, estimation of weights via entropy balancing and the method of moments are in fact entirely equivalent. This leads to an important conclusion regarding the optimality of standard MAIC weights based on the method of moments, and suggests interesting avenues for further research.

2\. EQUIVALENCE OF THE METHOD OF MOMENTS AND ENTROPY BALANCING
--------------------------------------------------------------

The estimation of weights for MAIC, whether based on the method of moments or on entropy balancing, can be formulated as a minimization problem.[5](#jrsm1416-bib-0005), [8](#jrsm1416-bib-0008) Equivalence therefore follows from consideration of the respective objective functions that are to be minimized.

Let **_x_** _ik_ be a vector of covariate values for an individual _i_ on treatment _k_ in the _AB_ study. Signorovitch et al [5](#jrsm1416-bib-0005) showed that, after centering the covariates around the means in the _AC_ study (ie, so that ¯𝒙𝐴𝐶 \=𝟎), MAIC minimizes the objective function

𝐻MM⁡(𝜶)\=∑𝑘\=𝐴,𝐵𝑁𝑘⁡(𝐴𝐵)∑𝑖\=1exp⁡(𝒙T𝑖𝑘⁢𝜶),

(3)

for a vector of parameters **_α_**. With solution ^𝜶 \=arg min⁡(𝐻MM⁡(𝜶)), the (normalized) weights _w_ _ik_ are then given by

𝑤𝑖𝑘\=exp⁡(𝒙T𝑖𝑘⁢^𝜶)∑𝑣\=𝐴,𝐵∑𝑁𝑣⁡(𝐴𝐵)𝑢\=1exp⁡(𝒙T𝑢𝑣⁢^𝜶).

(4)

(We use the normalized weights here to better show the equivalence to entropy balancing; a set of weights can be rescaled arbitrarily without affecting the estimate in Equation (1).[2](#jrsm1416-bib-0002), [5](#jrsm1416-bib-0005))

Entropy balancing also seeks weights that match the moments of covariates between studies, but that further minimize the entropy distance from uniform weights, ∑𝑘\=𝐴,𝐵∑𝑁𝑘⁡(𝐴𝐵)𝑖\=1𝑤𝑖𝑘⁢log⁡(𝑁(𝐴𝐵)⁢𝑤𝑖𝑘). Hainmueller [8](#jrsm1416-bib-0008) used Lagrange multipliers to find an unconstrained dual optimization problem, which (again after setting ¯𝒙𝐴𝐶 \=𝟎) gives the objective function

𝐻EB⁡(𝜶)\=log⁡(1𝑁(𝐴𝐵)⁢∑𝑘\=𝐴,𝐵𝑁𝑘⁡(𝐴𝐵)∑𝑖\=1exp⁡(𝒙T𝑖𝑘⁢𝜶)).

(5)

With solution ^𝜶 \=arg min⁡(𝐻EB⁡(𝜶)), the weights are again given by (4).

Comparing the objective functions (3) and (5), we see that

𝐻EB⁡(𝜶)\=log⁡(𝐻MM⁡(𝜶))−log⁡(𝑁(𝐴𝐵)).

(6)

Therefore, since the logarithm is a monotonic function and log(_N_(_AB_)) is constant, the solutions of these two minimization problems are identical; MAIC weights based on the method of moments or entropy balancing are identical up to a normalizing constant.

Example R code is provided in the [Appendix S1](#jrsm1416-supitem-0001) that implements both the method of moments and entropy balancing approaches to MAIC, applied to the simulated example given by Phillippo et al. [2](#jrsm1416-bib-0002)

3\. DISCUSSION
--------------

In this brief method note, we have shown that the MAIC weights are identical whether estimated using entropy balancing or the method of moments. In practice, entropy balancing performs the minimization on the log scale which may perform better computationally, but the estimated weights will be identical for MAIC and entropy balancing, up to optimization error. An important corollary from this result is that standard MAIC (based on the method of moments) also enjoys the additional “optimality” property that the estimated weights are as close as possible to uniform weights (no weighting at all), in an entropy sense. Alternative loss functions could be used in the entropy balancing scheme which may change the performance of the method, and would then no longer be equivalent to standard MAIC based on the method of moments. For example, it remains to be seen whether other loss functions could be used to obtain MAIC weights that are optimal in the sense that they minimize the SE of the resulting population‐adjusted estimates (or equivalently, maximize the effective sample size); this is likely of greater practical interest than pursuing optimality in the entropy sense.

For entropy balancing, Hainmueller [8](#jrsm1416-bib-0008) notes that other “base weights” for which to minimise the distance from could be used instead of uniform weights, and this would also depart from equivalence to standard MAIC based on the method of moments. With non‐uniform base weights 𝑤(0)𝑖𝑘, the entropy balancing objective function in (5) becomes

𝐻EB⁡(𝜶)\=log⁡(∑𝑘\=𝐴,𝐵𝑁𝑘⁡(𝐴𝐵)∑𝑖\=1𝑤(0)𝑖𝑘⁢exp⁡(𝒙T𝑖𝑘⁢𝜶)),

(7a)

and the weights are then given by

𝑤𝑖𝑘\=𝑤(0)𝑖𝑘⁢exp⁡(𝒙T𝑖𝑘⁢^𝜶)∑𝑣\=𝐴,𝐵∑𝑁𝑣⁡(𝐴𝐵)𝑢\=1𝑤(0)𝑢𝑣⁢exp⁡(𝒙T𝑢𝑣⁢^𝜶).

(7b)

Setting uniform base weights 𝑤(0)𝑖𝑘 \=1/𝑁(𝐴𝐵) in (7) recovers formula (5) above. Non‐uniform base weights could, for example, be used to perform nonparametric covariate adjustment, [9](#jrsm1416-bib-0009) or to adjust for treatment switching, [10](#jrsm1416-bib-0010) prior to population adjustment by weighting to match the _AC_ population. The idea is that the final weights aim to retain the initial adjustment applied by the base weights, while also applying the necessary population adjustment. This would be a novel development for MAIC, and is an interesting avenue for further research. It remains to be seen how this approach might perform in practice, for example, if the population differences are large and the final weights are far from the base weights. The example R code in the [Appendix S1](#jrsm1416-supitem-0001) also includes an implementation of entropy balancing MAIC with non‐uniform base weights.

Different schemes for applying weights have also been proposed. MAIC as described by Signorovitch et al [5](#jrsm1416-bib-0005) estimates weights for the entire _AB_ population at once to balance covariate distributions with the entire _AC_ population. Belger et al[6](#jrsm1416-bib-0006), [7](#jrsm1416-bib-0007) compare with other possible approaches, which involve splitting apart trial arms and balancing covariate distributions separately between the control arms (_A_) and between the treatment arms (_B_ and _C_) in the IPD and aggregate populations. The properties of such “splitting” approaches in comparison with a more typical population reweighting are largely unknown and require further investigation; however, some initial simulation studies have reported performance benefits over standard MAIC. [11](#jrsm1416-bib-0011) While MAIC is at present the most commonly used approach for population adjustment, other methods are available which may have advantages over MAIC.[2](#jrsm1416-bib-0002), [12](#jrsm1416-bib-0012), [13](#jrsm1416-bib-0013) Recent simulation work showed that regression‐based approaches such as multilevel network meta‐regression and simulated treatment comparison performed better than MAIC in many scenarios, and that in some cases MAIC could even increase bias compared to a standard indirect comparison. [12](#jrsm1416-bib-0012)

We have discussed an “anchored” indirect comparison scenario where a common comparator arm is available. However, a sizeable proportion of MAIC analyses published to date instead rely on an “unanchored” indirect comparison, where absolute outcomes on treatments _B_ and _C_ from single‐arm studies or in a disconnected network are compared directly as ^𝑑𝐵𝐶⁡(𝐶) \=𝑔⁡(^𝑦𝐶⁡(𝐶)) −𝑔⁡(^𝑦𝐵⁡(𝐶)), where ^𝑦𝐵⁡(𝐶) is estimated using weights and ^𝑦𝐶⁡(𝐶) is reported by the _C_ trial.[2](#jrsm1416-bib-0002), [4](#jrsm1416-bib-0004) Unanchored comparisons rely on a much stronger assumption than anchored comparisons, namely that all prognostic factors as well as all effect modifiers have been suitably adjusted for.[2](#jrsm1416-bib-0002), [3](#jrsm1416-bib-0003) The equivalence of the method of moments and entropy balancing approaches follows in exactly the same manner in an unanchored setting. Unanchored MAICs have previously been used in scenarios with a common comparator but where treatment switching is present.[2](#jrsm1416-bib-0002), [4](#jrsm1416-bib-0004) The entropy balancing approach with non‐uniform base weights, described above, provides an attractive option for combining weight‐based adjustments for treatment switching [10](#jrsm1416-bib-0010) with an anchored MAIC, while crucially retaining reliance on randomization.

Several simulation studies have compared approaches based on standard MAIC and entropy balancing and found no difference between these approaches.[6](#jrsm1416-bib-0006), [7](#jrsm1416-bib-0007), [11](#jrsm1416-bib-0011) The equivalence result given in this paper explains these findings, as we now know that these approaches are identical up to the numerical accuracy of the optimization routines. Available guidance on the use of MAIC (eg, [2](#jrsm1416-bib-0002) ) should be updated to note the equivalence of entropy balancing and standard MAIC.

In conclusion, the equivalence of MAIC weights estimated using the method of moments and entropy balancing means that standard MAIC (based on the method of moments) inherits the desirable “optimality” property that the weights are as uniform as possible. Moreover, the additional flexibility of entropy balancing suggests several interesting avenues for further research.

CONFLICT OF INTEREST
--------------------

D.M.P. reports personal fees from UCB outside of the submitted work.

Supporting information
----------------------

**Appendix** S1. Example R code implementing MAIC using the method of moments (3) and using entropy balancing with uniform base weights (5) and non‐uniform base weights (7).

[Click here for additional data file.](/articles/instance/7384548/bin/JRSM-11-568-s001.R) (9.6KB, R)

ACKNOWLEDGEMENTS
----------------

The authors wish to thank Dan Jackson, AstraZeneca, for fruitful discussions. This work was supported by the UK Medical Research Council, grants MR/P015298/1 and MR/R025223/1. N.J.W. was also supported by the the NIHR Biomedical Research Centre at University Hospitals Bristol NHS Foundation Trust and the University of Bristol. The views expressed in this publication are those of the authors and not necessarily those of the NHS, the National Institute for Health Research or the Department of Health and Social Care.

Phillippo DM, Dias S, Ades AE, Welton NJ. Equivalence of entropy balancing and the method of moments for matching‐adjusted indirect comparison. Res Syn Meth. 2020;11:568–572. 10.1002/jrsm.1416

**Funding information** Medical Research Council, Grant/Award Numbers: MR/P015298/1, MR/R025223/1; University Hospitals Bristol NHS Foundation Trust; University of Bristol

DATA AVAILABILITY STATEMENT
---------------------------

Data sharing is not applicable to this article as no new data were created or analysed.

REFERENCES
----------

*   1. Bucher HC, Guyatt GH, Griffith LE, Walter SD. The results of direct and indirect treatment comparisons in meta‐analysis of randomized controlled trials. J Clin Epidemiol. 1997;50(6):683‐691. \[[DOI](https://doi.org/10.1016/s0895-4356(97)00049-8)\] \[[PubMed](https://pubmed.ncbi.nlm.nih.gov/9250266/)\] \[[Google Scholar](https://scholar.google.com/scholar_lookup?journal=J%20Clin%20Epidemiol&title=The%20results%20of%20direct%20and%20indirect%20treatment%20comparisons%20in%20meta%E2%80%90analysis%20of%20randomized%20controlled%20trials&author=HC%20Bucher&author=GH%20Guyatt&author=LE%20Griffith&author=SD%20Walter&volume=50&issue=6&publication_year=1997&pages=683-691&pmid=9250266&doi=10.1016/s0895-4356(97)00049-8&)\]
*   2. Phillippo DM, Ades AE, Dias S, Palmer S, Abrams KR, Welton NJ. NICE DSU Technical Support Document 18: Methods for Population‐Adjusted Indirect Comparisons in Submission to NICE. London: National Institute for Health and Care Excellence; 2016. \[[Google Scholar](https://scholar.google.com/scholar_lookup?title=NICE%20DSU%20Technical%20Support%20Document%2018:%20Methods%20for%20Population%E2%80%90Adjusted%20Indirect%20Comparisons%20in%20Submission%20to%20NICE&author=DM%20Phillippo&author=AE%20Ades&author=S%20Dias&author=S%20Palmer&author=KR%20Abrams&publication_year=2016&)\]
*   3. Phillippo DM, Ades AE, Dias S, Palmer S, Abrams KR, Welton NJ. Methods for population‐adjusted indirect comparisons in health technology appraisal. Med Decis Making. 2018;38(2):200‐211. \[[DOI](https://doi.org/10.1177/0272989X17725740)\] \[[PMC free article](/articles/PMC5774635/)\] \[[PubMed](https://pubmed.ncbi.nlm.nih.gov/28823204/)\] \[[Google Scholar](https://scholar.google.com/scholar_lookup?journal=Med%20Decis%20Making&title=Methods%20for%20population%E2%80%90adjusted%20indirect%20comparisons%20in%20health%20technology%20appraisal&author=DM%20Phillippo&author=AE%20Ades&author=S%20Dias&author=S%20Palmer&author=KR%20Abrams&volume=38&issue=2&publication_year=2018&pages=200-211&pmid=28823204&doi=10.1177/0272989X17725740&)\]
*   4. Phillippo DM, Dias S, Elsada A, Ades AE, Welton NJ. Population adjustment methods for indirect comparisons: a review of National Institute for Health and Care Excellence technology appraisals. Int J Technol Assess Health Care. 2019;35(03):221‐228. \[[DOI](https://doi.org/10.1017/S0266462319000333)\] \[[PMC free article](/articles/PMC6650293/)\] \[[PubMed](https://pubmed.ncbi.nlm.nih.gov/31190671/)\] \[[Google Scholar](https://scholar.google.com/scholar_lookup?journal=Int%20J%20Technol%20Assess%20Health%20Care&title=Population%20adjustment%20methods%20for%20indirect%20comparisons:%20a%20review%20of%20National%20Institute%20for%20Health%20and%20Care%20Excellence%20technology%20appraisals&author=DM%20Phillippo&author=S%20Dias&author=A%20Elsada&author=AE%20Ades&author=NJ%20Welton&volume=35&issue=03&publication_year=2019&pages=221-228&pmid=31190671&doi=10.1017/S0266462319000333&)\]
*   5. Signorovitch JE, Wu EQ, Yu AP, et al. Comparative effectiveness without head‐to‐head trials a method for matching‐adjusted indirect comparisons applied to psoriasis treatment with adalimumab or etanercept. Pharmacoeconomics. 2010;28(10):935‐945. \[[DOI](https://doi.org/10.2165/11538370-000000000-00000)\] \[[PubMed](https://pubmed.ncbi.nlm.nih.gov/20831302/)\] \[[Google Scholar](https://scholar.google.com/scholar_lookup?journal=Pharmacoeconomics&title=Comparative%20effectiveness%20without%20head%E2%80%90to%E2%80%90head%20trials%20a%20method%20for%20matching%E2%80%90adjusted%20indirect%20comparisons%20applied%20to%20psoriasis%20treatment%20with%20adalimumab%20or%20etanercept&author=JE%20Signorovitch&author=EQ%20Wu&author=AP%20Yu&volume=28&issue=10&publication_year=2010&pages=935-945&pmid=20831302&doi=10.2165/11538370-000000000-00000&)\]
*   6. Belger M, Brnabic A, Kadziola Z, Petto H, Faries D. Inclusion of Multiple Studies in Matching Adjusted Indirect Comparisons (MAIC) Paper presented at: ISPOR 20th Annual International Meeting, Philadelphia, PA; 2015. \[[Google Scholar](https://scholar.google.com/scholar_lookup?Belger%20M,%20Brnabic%20A,%20Kadziola%20Z,%20Petto%20H,%20Faries%20D.%20Inclusion%20of%20Multiple%20Studies%20in%20Matching%20Adjusted%20Indirect%20Comparisons%20(MAIC)%20Paper%20presented%20at:%20ISPOR%2020th%20Annual%20International%20Meeting,%20Philadelphia,%20PA;%202015.)\]
*   7. Belger M, Brnabic A, Kadziola Z, Petto H, Faries D. Alternative Weighting Approaches for Matching Adjusted Indirect Comparisons (MAIC) Paper presented at: ISPOR 20th Annual International Meeting,Philadelphia, PA; 2015. \[[Google Scholar](https://scholar.google.com/scholar_lookup?Belger%20M,%20Brnabic%20A,%20Kadziola%20Z,%20Petto%20H,%20Faries%20D.%20Alternative%20Weighting%20Approaches%20for%20Matching%20Adjusted%20Indirect%20Comparisons%20(MAIC)%20Paper%20presented%20at:%20ISPOR%2020th%20Annual%20International%20Meeting,Philadelphia,%20PA;%202015.)\]
*   8. Hainmueller J. Entropy balancing for causal effects: a multivariate reweighting method to produce balanced samples in observational studies. Polit Anal.2012;20(1):25–46. \[[Google Scholar](https://scholar.google.com/scholar_lookup?journal=Polit%20Anal&title=Entropy%20balancing%20for%20causal%20effects:%20a%20multivariate%20reweighting%20method%20to%20produce%20balanced%20samples%20in%20observational%20studies&author=J%20Hainmueller&volume=20&issue=1&publication_year=2012&pages=25-46&)\]
*   9. Williamson EJ, Forbes A, White IR. Variance reduction in randomised trials by inverse probability weighting using the propensity score. Stat Med. 2013;33(5):721‐737. \[[DOI](https://doi.org/10.1002/sim.5991)\] \[[PMC free article](/articles/PMC4285308/)\] \[[PubMed](https://pubmed.ncbi.nlm.nih.gov/24114884/)\] \[[Google Scholar](https://scholar.google.com/scholar_lookup?journal=Stat%20Med&title=Variance%20reduction%20in%20randomised%20trials%20by%20inverse%20probability%20weighting%20using%20the%20propensity%20score&author=EJ%20Williamson&author=A%20Forbes&author=IR%20White&volume=33&issue=5&publication_year=2013&pages=721-737&pmid=24114884&doi=10.1002/sim.5991&)\]
*   10. Robins JM, Finkelstein DM. Correcting for noncompliance and dependent censoring in an AIDS clinical trial with inverse probability of censoring weighted (IPCW) log‐rank tests. Biometrics. 2000;56(3):779‐788. \[[DOI](https://doi.org/10.1111/j.0006-341x.2000.00779.x)\] \[[PubMed](https://pubmed.ncbi.nlm.nih.gov/10985216/)\] \[[Google Scholar](https://scholar.google.com/scholar_lookup?journal=Biometrics&title=Correcting%20for%20noncompliance%20and%20dependent%20censoring%20in%20an%20AIDS%20clinical%20trial%20with%20inverse%20probability%20of%20censoring%20weighted%20(IPCW)%20log%E2%80%90rank%20tests&author=JM%20Robins&author=DM%20Finkelstein&volume=56&issue=3&publication_year=2000&pages=779-788&pmid=10985216&doi=10.1111/j.0006-341x.2000.00779.x&)\]
*   11. Petto H, Kadziola Z, Brnabic A, Saure D, Belger M. Alternative weighting approaches for anchored matching‐adjusted indirect comparisons via a common comparator. Value Health. 2019;22(1):85‐91. \[[DOI](https://doi.org/10.1016/j.jval.2018.06.018)\] \[[PubMed](https://pubmed.ncbi.nlm.nih.gov/30661638/)\] \[[Google Scholar](https://scholar.google.com/scholar_lookup?journal=Value%20Health&title=Alternative%20weighting%20approaches%20for%20anchored%20matching%E2%80%90adjusted%20indirect%20comparisons%20via%20a%20common%20comparator&author=H%20Petto&author=Z%20Kadziola&author=A%20Brnabic&author=D%20Saure&author=M%20Belger&volume=22&issue=1&publication_year=2019&pages=85-91&pmid=30661638&doi=10.1016/j.jval.2018.06.018&)\]
*   12. Phillippo DM. Calibration of treatment effects in network meta‐analysis using individual patient data (PhD thesis). University of Bristol; 2019. Available from [https://research-information.bris.ac.uk/](https://research-information.bris.ac.uk/).
*   13. Phillippo DM, Dias S, Ades AE, et al. Multilevel network meta‐regression for population‐adjusted treatment comparisons. J Royal Stat Soc Ser A (Stat Soc). In Press. \[[DOI](https://doi.org/10.1111/rssa.12579)\] \[[PMC free article](/articles/PMC7362893/)\] \[[PubMed](https://pubmed.ncbi.nlm.nih.gov/32684669/)\] \[[Google Scholar](https://scholar.google.com/scholar_lookup?journal=J%20Royal%20Stat%20Soc%20Ser%20A%20(Stat%20Soc)&title=Multilevel%20network%20meta%E2%80%90regression%20for%20population%E2%80%90adjusted%20treatment%20comparisons&author=DM%20Phillippo&author=S%20Dias&author=AE%20Ades&pmid=32684669&doi=10.1111/rssa.12579&)\]

Associated Data
---------------

_This section collects any data citations, data availability statements, or supplementary materials included in this article._

### Supplementary Materials

**Appendix** S1. Example R code implementing MAIC using the method of moments (3) and using entropy balancing with uniform base weights (5) and non‐uniform base weights (7).

[Click here for additional data file.](/articles/instance/7384548/bin/JRSM-11-568-s001.R) (9.6KB, R)

### Data Availability Statement

Data sharing is not applicable to this article as no new data were created or analysed.

* * *

Articles from Research Synthesis Methods are provided here courtesy of **Wiley**