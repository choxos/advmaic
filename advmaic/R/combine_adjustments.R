#' @title Combined Adjustment Methods
#' @name combine_adjustments
#' @description Functions implementing combined MAIC with other adjustment
#'   methods such as treatment switching correction (IPCW) and nonparametric
#'   covariate adjustment.
NULL

#' MAIC with Treatment Switching Adjustment
#'
#' Combines MAIC population adjustment with inverse probability of censoring
#' weighting (IPCW) to correct for treatment switching while adjusting for
#' cross-trial population differences.
#'
#' @param ipd Data frame containing individual patient data.
#' @param agd_target Named numeric vector of target moments.
#' @param covariates Character vector of covariate names for MAIC.
#' @param time_var Character string specifying follow-up time variable.
#' @param event_var Character string specifying event indicator.
#' @param switch_var Character string specifying switching indicator.
#' @param switch_time_var Character string specifying time of switching.
#' @param switch_covariates Character vector of covariates for switching model.
#' @param method MAIC weighting method.
#' @param use_anchored Logical. If TRUE, preserve randomization by applying
#'   IPCW before MAIC (recommended for anchored comparisons).
#' @param max_iter Maximum iterations.
#' @param tol Convergence tolerance.
#' @param verbose Print progress.
#'
#' @return An object of class "advmaic_weights" with combined weights.
#'
#' @details
#' Treatment switching occurs when patients randomized to control switch to
#' active treatment, typically due to disease progression. This violates
#' intention-to-treat and biases treatment effect estimates.
#'
#' This function implements a two-stage approach:
#' 1. Calculate IPCW weights to adjust for treatment switching
#' 2. Use IPCW weights as base weights for MAIC entropy balancing
#'
#' This approach (novel application from Phillippo 2020) allows:
#' - Correction for treatment switching bias
#' - Adjustment for cross-trial population differences
#' - Preservation of randomization benefits in anchored comparisons
#'
#' @references
#' Phillippo DM, et al. (2020). Equivalence of entropy balancing and the method
#' of moments for matching-adjusted indirect comparison. Research Synthesis
#' Methods. 11:568-572.
#'
#' Robins JM, Finkelstein DM. (2000). Correcting for noncompliance and dependent
#' censoring in an AIDS Clinical Trial. Biometrics. 56:779-788.
#'
#' @examples
#' \dontrun{
#' # Example with treatment switching
#' weights <- maic_with_treatment_switching(
#'   ipd = ipd,
#'   agd_target = agd_target,
#'   covariates = c("age", "male"),
#'   time_var = "time",
#'   event_var = "event",
#'   switch_var = "switched",
#'   switch_covariates = c("age", "biomarker")
#' )
#' }
#'
#' @export
maic_with_treatment_switching <- function(ipd,
                                          agd_target,
                                          covariates,
                                          time_var,
                                          event_var,
                                          switch_var,
                                          switch_time_var = NULL,
                                          switch_covariates,
                                          method = c("entropy", "moments"),
                                          use_anchored = TRUE,
                                          max_iter = 1000,
                                          tol = 1e-8,
                                          verbose = FALSE) {

  method <- match.arg(method)

  # Step 1: Calculate IPCW base weights
  cli::cli_alert_info("Calculating IPCW weights for treatment switching adjustment...")

  ipcw_weights <- ipcw_base_weights(
    ipd = ipd,
    time_var = time_var,
    event_var = event_var,
    switch_var = switch_var,
    switch_time_var = switch_time_var,
    covariates = switch_covariates,
    method = "cox",
    stabilize = TRUE
  )

  # Step 2: Use IPCW weights as base weights for MAIC
  cli::cli_alert_info("Estimating MAIC weights with IPCW base weights...")

  # For non-switchers only (IPCW gives weight 0 to switchers)
  non_switcher_idx <- which(ipcw_weights > 0)

  if (length(non_switcher_idx) == 0) {
    cli::cli_abort("All patients switched - cannot proceed with analysis")
  }

  # Subset data to non-switchers
  ipd_subset <- ipd[non_switcher_idx, , drop = FALSE]
  base_weights_subset <- ipcw_weights[non_switcher_idx]

  # Estimate MAIC weights using IPCW as base weights
  result <- estimate_weights(
    ipd = ipd_subset,
    agd_target = agd_target,
    covariates = covariates,
    method = method,
    base_weights = base_weights_subset,
    max_iter = max_iter,
    tol = tol,
    verbose = verbose
  )

  # Create full weight vector (zeros for switchers)
  full_weights <- numeric(nrow(ipd))
  full_weights[non_switcher_idx] <- result$weights

  # Create output object
  new_advmaic_weights(
    weights = full_weights,
    alpha = result$alpha,
    method = paste0(method, "_with_ipcw"),
    covariates = covariates,
    base_weights = ipcw_weights,
    convergence = list(
      converged = result$convergence$converged,
      n_switchers = sum(ipd[[switch_var]] == 1),
      n_non_switchers = length(non_switcher_idx),
      message = result$convergence$message
    ),
    call = match.call()
  )
}

#' MAIC with Nonparametric Covariate Adjustment
#'
#' Combines MAIC population adjustment with nonparametric covariate adjustment
#' (NPCA) to achieve both cross-trial population matching and within-trial
#' variance reduction.
#'
#' @param ipd Data frame containing individual patient data.
#' @param agd_target Named numeric vector of target moments.
#' @param population_covariates Character vector of covariate names for MAIC
#'   (effect modifiers requiring population adjustment).
#' @param efficiency_covariates Character vector of covariate names for NPCA
#'   (prognostic variables for variance reduction).
#' @param treatment_var Character string specifying treatment variable name.
#' @param method MAIC weighting method.
#' @param max_iter Maximum iterations.
#' @param tol Convergence tolerance.
#' @param verbose Print progress.
#'
#' @return An object of class "advmaic_weights" with combined weights.
#'
#' @details
#' This function implements a two-stage approach:
#' 1. Calculate NPCA weights using propensity score weighting to balance
#'    prognostic variables between treatment arms within the trial
#' 2. Use NPCA weights as base weights for MAIC entropy balancing
#'
#' Following Williamson et al. (2013), NPCA uses IPTW to achieve the same
#' variance reduction as ANCOVA while remaining nonparametric.
#'
#' When combined with MAIC (novel application from Phillippo 2020), this allows:
#' - Adjustment for cross-trial population differences (via MAIC)
#' - Variance reduction through prognostic covariate balance (via NPCA)
#'
#' This can be particularly valuable when the effective sample size from
#' MAIC alone is small, as NPCA can help recover some precision.
#'
#' @references
#' Williamson EJ, Forbes A, White IR. (2014). Variance reduction in randomised
#' trials by inverse probability weighting using the propensity score.
#' Statistics in Medicine. 33:721-737.
#'
#' Phillippo DM, et al. (2020). Equivalence of entropy balancing and the method
#' of moments for matching-adjusted indirect comparison. Research Synthesis
#' Methods. 11:568-572.
#'
#' @examples
#' \dontrun{
#' # Example: adjust for population (age, sex) and efficiency (biomarker)
#' weights <- maic_with_npca(
#'   ipd = ipd,
#'   agd_target = c(age = 60, male = 0.5),
#'   population_covariates = c("age", "male"),
#'   efficiency_covariates = c("biomarker"),
#'   treatment_var = "treatment"
#' )
#' }
#'
#' @export
maic_with_npca <- function(ipd,
                           agd_target,
                           population_covariates,
                           efficiency_covariates,
                           treatment_var,
                           method = c("entropy", "moments"),
                           max_iter = 1000,
                           tol = 1e-8,
                           verbose = FALSE) {

  method <- match.arg(method)

  # Step 1: Calculate NPCA base weights
  cli::cli_alert_info("Calculating NPCA weights for variance reduction...")

  npca_weights <- npca_base_weights(
    ipd = ipd,
    covariates = efficiency_covariates,
    treatment_var = treatment_var,
    stabilize = TRUE
  )

  # Step 2: Use NPCA weights as base weights for MAIC
  cli::cli_alert_info("Estimating MAIC weights with NPCA base weights...")

  result <- estimate_weights(
    ipd = ipd,
    agd_target = agd_target,
    covariates = population_covariates,
    method = method,
    base_weights = npca_weights,
    max_iter = max_iter,
    tol = tol,
    verbose = verbose
  )

  # Create output object
  new_advmaic_weights(
    weights = result$weights,
    alpha = result$alpha,
    method = paste0(method, "_with_npca"),
    covariates = population_covariates,
    base_weights = npca_weights,
    convergence = result$convergence,
    call = match.call()
  )
}

#' Combined MAIC with Multiple Adjustments
#'
#' A flexible function for combining MAIC with any type of base weights,
#' allowing users to implement custom adjustment strategies.
#'
#' @param ipd Data frame containing individual patient data.
#' @param agd_target Named numeric vector of target moments.
#' @param covariates Character vector of covariate names for MAIC.
#' @param base_weight_fn Function that takes ipd as input and returns
#'   a vector of base weights.
#' @param method MAIC weighting method.
#' @param ... Additional arguments passed to base_weight_fn.
#'
#' @return An object of class "advmaic_weights".
#'
#' @details
#' This is a generic function that allows users to implement custom
#' base weight generators for novel combined adjustment approaches.
#'
#' The base_weight_fn should:
#' - Take the ipd data frame as its first argument
#' - Return a numeric vector of the same length as nrow(ipd)
#' - Return weights that sum to a positive number (will be normalized)
#'
#' @examples
#' \dontrun{
#' # Custom base weight function
#' my_base_weights <- function(ipd) {
#'   # Some custom weighting logic
#'   rep(1, nrow(ipd))
#' }
#'
#' weights <- maic_with_custom_base_weights(
#'   ipd = ipd,
#'   agd_target = agd_target,
#'   covariates = covariates,
#'   base_weight_fn = my_base_weights
#' )
#' }
#'
#' @export
maic_with_custom_base_weights <- function(ipd,
                                          agd_target,
                                          covariates,
                                          base_weight_fn,
                                          method = c("entropy", "moments"),
                                          ...) {

  method <- match.arg(method)

  # Calculate base weights using custom function
  base_weights <- base_weight_fn(ipd, ...)

  # Validate
  if (length(base_weights) != nrow(ipd)) {
    cli::cli_abort("base_weight_fn must return vector of length {nrow(ipd)}")
  }

  # Estimate MAIC weights
  estimate_weights(
    ipd = ipd,
    agd_target = agd_target,
    covariates = covariates,
    method = method,
    base_weights = base_weights
  )
}
