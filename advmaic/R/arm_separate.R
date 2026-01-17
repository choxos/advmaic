#' @title Arm-Separate Weighting Schemes
#' @name arm_separate
#' @description Functions implementing arm-separate weighting schemes for MAIC,
#'   as described in Petto et al. (2019). These methods estimate weights
#'   separately for treatment and control arms.
NULL

#' Arm-Separate Entropy Balancing
#'
#' Estimates MAIC weights separately for each treatment arm, matching covariates
#' to arm-specific aggregate data from the comparator trial.
#'
#' @param ipd Data frame containing individual patient data from the index trial.
#' @param agd_target Named list with two elements: "treatment" and "control",
#'   each containing named numeric vectors of target moments for the respective
#'   arms in the comparator trial.
#' @param covariates Character vector of covariate names to balance.
#' @param arm_var Character string specifying the arm variable name.
#' @param treatment_value Value indicating the treatment arm.
#' @param control_value Value indicating the control arm.
#' @param method Weighting method: "entropy" or "moments".
#' @param match_variance Logical. If TRUE, also match variances.
#' @param max_iter Maximum number of iterations.
#' @param tol Convergence tolerance.
#' @param verbose Logical. If TRUE, print progress.
#'
#' @return An object of class "advmaic_weights" containing weights for all
#'   observations, with arm-specific Lagrange multipliers.
#'
#' @details
#' In standard MAIC (SigTotal), weights are estimated on the total study
#' population, matching overall covariate distributions. This can be suboptimal
#' when covariate distributions differ between arms in the comparator trial.
#'
#' Arm-separate weighting (SigArm/EbArm from Petto et al. 2019) estimates
#' weights separately for each arm, matching:
#' - Treatment arm IPD to treatment arm AgD moments
#' - Control arm IPD to control arm AgD moments
#'
#' This preserves within-arm covariate balance and can lead to more efficient
#' estimates when arm-specific aggregate data is available.
#'
#' @references
#' Petto H, et al. (2019). Alternative weighting approaches for anchored
#' matching-adjusted indirect comparisons via a common comparator.
#' Value in Health. 22:85-91.
#'
#' @examples
#' \dontrun{
#' # Simulate IPD
#' set.seed(123)
#' n <- 400
#' ipd <- data.frame(
#'   age = rnorm(n, 55, 10),
#'   male = rbinom(n, 1, 0.6),
#'   arm = rep(c("treatment", "control"), each = n/2),
#'   outcome = rnorm(n, 0, 1)
#' )
#'
#' # Arm-specific AgD targets
#' agd_target <- list(
#'   treatment = c(age = 58, male = 0.55),
#'   control = c(age = 62, male = 0.50)
#' )
#'
#' # Estimate arm-separate weights
#' weights <- eb_arm_separate(
#'   ipd = ipd,
#'   agd_target = agd_target,
#'   covariates = c("age", "male"),
#'   arm_var = "arm",
#'   treatment_value = "treatment",
#'   control_value = "control"
#' )
#' }
#'
#' @export
eb_arm_separate <- function(ipd,
                            agd_target,
                            covariates,
                            arm_var,
                            treatment_value,
                            control_value,
                            method = c("entropy", "moments"),
                            match_variance = FALSE,
                            max_iter = 1000,
                            tol = 1e-8,
                            verbose = FALSE) {

  method <- match.arg(method)

  # Validate inputs
  if (!is.data.frame(ipd)) {
    cli::cli_abort("ipd must be a data frame")
  }

  if (!is.list(agd_target) || !all(c("treatment", "control") %in% names(agd_target))) {
    cli::cli_abort("agd_target must be a list with 'treatment' and 'control' elements")
  }

  if (!(arm_var %in% names(ipd))) {
    cli::cli_abort("arm_var '{arm_var}' not found in ipd")
  }

  missing_covs <- setdiff(covariates, names(ipd))
  if (length(missing_covs) > 0) {
    cli::cli_abort("Covariates not found in ipd: {paste(missing_covs, collapse = ', ')}")
  }

  n <- nrow(ipd)
  weights <- numeric(n)
  alpha_list <- list()
  convergence_info <- list()

  # Treatment arm
  trt_idx <- which(ipd[[arm_var]] == treatment_value)
  ipd_trt <- ipd[trt_idx, , drop = FALSE]

  result_trt <- estimate_weights(
    ipd = ipd_trt,
    agd_target = agd_target$treatment,
    covariates = covariates,
    method = method,
    match_variance = match_variance,
    max_iter = max_iter,
    tol = tol,
    verbose = verbose
  )

  weights[trt_idx] <- result_trt$weights
  alpha_list$treatment <- result_trt$alpha
  convergence_info$treatment <- result_trt$convergence

  # Control arm
  ctrl_idx <- which(ipd[[arm_var]] == control_value)
  ipd_ctrl <- ipd[ctrl_idx, , drop = FALSE]

  result_ctrl <- estimate_weights(
    ipd = ipd_ctrl,
    agd_target = agd_target$control,
    covariates = covariates,
    method = method,
    match_variance = match_variance,
    max_iter = max_iter,
    tol = tol,
    verbose = verbose
  )

  weights[ctrl_idx] <- result_ctrl$weights
  alpha_list$control <- result_ctrl$alpha
  convergence_info$control <- result_ctrl$convergence

  # Rescale weights so they sum appropriately within each arm
  # Each arm's weights should sum to that arm's sample size
  n_trt <- length(trt_idx)
  n_ctrl <- length(ctrl_idx)
  weights[trt_idx] <- weights[trt_idx] * n_trt
  weights[ctrl_idx] <- weights[ctrl_idx] * n_ctrl

  # Normalize total
  weights <- weights / sum(weights)

  # Check overall convergence
  converged <- convergence_info$treatment$converged && convergence_info$control$converged

  # Create output object
  new_advmaic_weights(
    weights = weights,
    alpha = alpha_list,
    method = paste0(method, "_arm_separate"),
    covariates = covariates,
    base_weights = NULL,
    convergence = list(
      converged = converged,
      treatment = convergence_info$treatment,
      control = convergence_info$control,
      message = if (converged) "Both arms converged" else "One or both arms did not converge"
    ),
    call = match.call()
  )
}

#' Arm-Separate Entropy Balancing with ILD Covariate Balancing
#'
#' Estimates MAIC weights separately for each treatment arm, with additional
#' balancing of ILD-specific covariates (covariates available only in the
#' index trial IPD) between arms within the index trial.
#'
#' @param ipd Data frame containing individual patient data from the index trial.
#' @param agd_target Named list with two elements: "treatment" and "control",
#'   each containing named numeric vectors of target moments.
#' @param common_covariates Character vector of covariate names available in
#'   both IPD and AgD (to be matched to AgD targets).
#' @param ild_covariates Character vector of ILD-specific covariate names
#'   (available only in IPD, to be balanced between arms within IPD).
#' @param arm_var Character string specifying the arm variable name.
#' @param treatment_value Value indicating the treatment arm.
#' @param control_value Value indicating the control arm.
#' @param method Weighting method: "entropy" or "moments".
#' @param max_iter Maximum number of iterations.
#' @param tol Convergence tolerance.
#' @param verbose Logical. If TRUE, print progress.
#'
#' @return An object of class "advmaic_weights".
#'
#' @details
#' EbArmILD extends arm-separate weighting by additionally balancing ILD-specific
#' covariates between treatment and control arms within the index trial. This is
#' useful when there are prognostic covariates in the IPD that are not reported
#' in the aggregate data.
#'
#' The method works in two stages:
#' 1. Match common covariates to arm-specific AgD targets (like EbArm)
#' 2. Additionally balance ILD-specific covariates between IPD arms
#'
#' This ensures that:
#' - Treatment arm IPD matches treatment arm AgD on common covariates
#' - Control arm IPD matches control arm AgD on common covariates
#' - ILD-specific covariates are balanced between IPD arms
#'
#' @references
#' Petto H, et al. (2019). Alternative weighting approaches for anchored
#' matching-adjusted indirect comparisons via a common comparator.
#' Value in Health. 22:85-91.
#'
#' @examples
#' \dontrun{
#' # Simulate IPD with ILD-specific covariates
#' set.seed(123)
#' n <- 400
#' ipd <- data.frame(
#'   age = rnorm(n, 55, 10),
#'   male = rbinom(n, 1, 0.6),
#'   biomarker = rnorm(n, 100, 20),  # ILD-specific, not in AgD
#'   arm = rep(c("treatment", "control"), each = n/2),
#'   outcome = rnorm(n, 0, 1)
#' )
#'
#' # AgD targets (only common covariates)
#' agd_target <- list(
#'   treatment = c(age = 58, male = 0.55),
#'   control = c(age = 62, male = 0.50)
#' )
#'
#' # Estimate weights with ILD balancing
#' weights <- eb_arm_ild(
#'   ipd = ipd,
#'   agd_target = agd_target,
#'   common_covariates = c("age", "male"),
#'   ild_covariates = c("biomarker"),
#'   arm_var = "arm",
#'   treatment_value = "treatment",
#'   control_value = "control"
#' )
#' }
#'
#' @export
eb_arm_ild <- function(ipd,
                       agd_target,
                       common_covariates,
                       ild_covariates,
                       arm_var,
                       treatment_value,
                       control_value,
                       method = c("entropy", "moments"),
                       max_iter = 1000,
                       tol = 1e-8,
                       verbose = FALSE) {

  method <- match.arg(method)

  # Validate inputs
  if (!is.data.frame(ipd)) {
    cli::cli_abort("ipd must be a data frame")
  }

  if (!is.list(agd_target) || !all(c("treatment", "control") %in% names(agd_target))) {
    cli::cli_abort("agd_target must be a list with 'treatment' and 'control' elements")
  }

  all_covariates <- c(common_covariates, ild_covariates)
  missing_covs <- setdiff(all_covariates, names(ipd))
  if (length(missing_covs) > 0) {
    cli::cli_abort("Covariates not found in ipd: {paste(missing_covs, collapse = ', ')}")
  }

  n <- nrow(ipd)

  # Split data by arm
  trt_idx <- which(ipd[[arm_var]] == treatment_value)
  ctrl_idx <- which(ipd[[arm_var]] == control_value)
  ipd_trt <- ipd[trt_idx, , drop = FALSE]
  ipd_ctrl <- ipd[ctrl_idx, , drop = FALSE]

  # Step 1: Match common covariates to AgD targets (arm-specific)
  # Treatment arm
  result_trt_common <- estimate_weights(
    ipd = ipd_trt,
    agd_target = agd_target$treatment,
    covariates = common_covariates,
    method = method,
    max_iter = max_iter,
    tol = tol,
    verbose = verbose
  )

  # Control arm
  result_ctrl_common <- estimate_weights(
    ipd = ipd_ctrl,
    agd_target = agd_target$control,
    covariates = common_covariates,
    method = method,
    max_iter = max_iter,
    tol = tol,
    verbose = verbose
  )

  # Step 2: Balance ILD-specific covariates between arms
  # Calculate weighted means of ILD covariates in each arm (after first stage)
  ild_means_trt <- sapply(ild_covariates, function(cov) {
    wmean(ipd_trt[[cov]], result_trt_common$weights)
  })
  names(ild_means_trt) <- ild_covariates

  ild_means_ctrl <- sapply(ild_covariates, function(cov) {
    wmean(ipd_ctrl[[cov]], result_ctrl_common$weights)
  })
  names(ild_means_ctrl) <- ild_covariates

  # Target: average of the two arm means (to balance between arms)
  ild_target <- (ild_means_trt + ild_means_ctrl) / 2
  names(ild_target) <- ild_covariates

  # Step 3: Re-estimate weights with both common and ILD constraints
  # For treatment arm: match to AgD + ILD target
  combined_target_trt <- c(agd_target$treatment, ild_target)

  result_trt_final <- estimate_weights(
    ipd = ipd_trt,
    agd_target = combined_target_trt,
    covariates = all_covariates,
    method = method,
    max_iter = max_iter,
    tol = tol,
    verbose = verbose
  )

  # For control arm: match to AgD + ILD target
  combined_target_ctrl <- c(agd_target$control, ild_target)

  result_ctrl_final <- estimate_weights(
    ipd = ipd_ctrl,
    agd_target = combined_target_ctrl,
    covariates = all_covariates,
    method = method,
    max_iter = max_iter,
    tol = tol,
    verbose = verbose
  )

  # Combine weights
  weights <- numeric(n)
  weights[trt_idx] <- result_trt_final$weights * length(trt_idx)
  weights[ctrl_idx] <- result_ctrl_final$weights * length(ctrl_idx)
  weights <- weights / sum(weights)

  # Check convergence
  converged <- result_trt_final$convergence$converged &&
    result_ctrl_final$convergence$converged

  # Create output object
  new_advmaic_weights(
    weights = weights,
    alpha = list(
      treatment = result_trt_final$alpha,
      control = result_ctrl_final$alpha
    ),
    method = paste0(method, "_arm_ild"),
    covariates = all_covariates,
    base_weights = NULL,
    convergence = list(
      converged = converged,
      treatment = result_trt_final$convergence,
      control = result_ctrl_final$convergence,
      ild_target = ild_target,
      message = if (converged) "Both arms converged" else "One or both arms did not converge"
    ),
    call = match.call()
  )
}

#' Method of Moments with Variance Matching (SigTotalVar)
#'
#' Estimates MAIC weights matching both means and variances of covariates
#' to the aggregate data targets. This is an extension of standard MAIC
#' (SigTotal) that provides better matching when variance information
#' is available.
#'
#' @param ipd Data frame containing individual patient data.
#' @param agd_target Named numeric vector of target moments. Should include
#'   both means (covariate names) and variances (covariate names with "_var"
#'   suffix).
#' @param covariates Character vector of covariate names to match means for.
#' @param method Weighting method: "entropy" or "moments".
#' @param max_iter Maximum number of iterations.
#' @param tol Convergence tolerance.
#' @param verbose Logical. If TRUE, print progress.
#'
#' @return An object of class "advmaic_weights".
#'
#' @details
#' Standard MAIC (SigTotal) matches only the means of covariates. SigTotalVar
#' extends this by also matching variances (or second moments), which can
#' provide better population matching when variance information is available
#' in the aggregate data.
#'
#' The constraints for matching variance of covariate X to target variance
#' sigma^2 are:
#' \deqn{\sum_i w_i X_i = \mu}
#' \deqn{\sum_i w_i X_i^2 = \mu^2 + \sigma^2}
#'
#' @references
#' Petto H, et al. (2019). Alternative weighting approaches for anchored
#' matching-adjusted indirect comparisons via a common comparator.
#' Value in Health. 22:85-91.
#'
#' @examples
#' \dontrun{
#' # Simulate IPD
#' set.seed(123)
#' n <- 200
#' ipd <- data.frame(
#'   age = rnorm(n, 55, 10),
#'   male = rbinom(n, 1, 0.6)
#' )
#'
#' # AgD targets including variances
#' agd_target <- c(
#'   age = 60,
#'   age_var = 64,  # variance of age
#'   male = 0.5
#' )
#'
#' # Estimate weights with variance matching
#' weights <- sig_total_var(
#'   ipd = ipd,
#'   agd_target = agd_target,
#'   covariates = c("age", "male")
#' )
#' }
#'
#' @export
sig_total_var <- function(ipd,
                          agd_target,
                          covariates,
                          method = c("entropy", "moments"),
                          max_iter = 1000,
                          tol = 1e-8,
                          verbose = FALSE) {

  method <- match.arg(method)

  # Call estimate_weights with match_variance = TRUE
  estimate_weights(
    ipd = ipd,
    agd_target = agd_target,
    covariates = covariates,
    method = method,
    match_variance = TRUE,
    max_iter = max_iter,
    tol = tol,
    verbose = verbose
  )
}
