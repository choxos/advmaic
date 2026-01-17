#' @title Alternative Loss Functions for MAIC
#' @name loss_functions
#' @description Functions implementing alternative loss functions from the
#'   Cressie-Read divergence family for entropy balancing MAIC.
NULL

#' Cressie-Read Divergence
#'
#' Computes the Cressie-Read divergence between weights and base weights.
#' This is a general family of divergences that includes entropy (gamma = 0)
#' and empirical likelihood (gamma = -1) as special cases.
#'
#' @param weights Numeric vector of weights (should sum to 1).
#' @param base_weights Numeric vector of base weights (should sum to 1).
#' @param gamma Numeric parameter for the divergence family:
#'   \itemize{
#'     \item gamma = 0: Kullback-Leibler (entropy) divergence
#'     \item gamma = -1: Empirical likelihood
#'     \item gamma = 1: Chi-squared divergence
#'     \item gamma = -0.5: Hellinger distance
#'     \item gamma = -2: Modified likelihood ratio
#'   }
#'
#' @return Numeric value of the divergence.
#'
#' @details
#' The Cressie-Read divergence family is defined as:
#' \deqn{D_\gamma(w || w^{(0)}) = \frac{1}{\gamma(\gamma + 1)} \sum_i w_i^{(0)} \left[\left(\frac{w_i}{w_i^{(0)}}\right)^{\gamma + 1} - 1\right]}
#'
#' For gamma = 0 (entropy), this becomes:
#' \deqn{D_0(w || w^{(0)}) = \sum_i w_i \log\left(\frac{w_i}{w_i^{(0)}}\right)}
#'
#' For gamma = -1 (empirical likelihood), this becomes:
#' \deqn{D_{-1}(w || w^{(0)}) = -\sum_i w_i^{(0)} \log\left(\frac{w_i}{w_i^{(0)}}\right)}
#'
#' @references
#' Cressie N, Read TRC. (1984). Multinomial goodness-of-fit tests.
#' Journal of the Royal Statistical Society B. 46:440-464.
#'
#' @examples
#' # Compare divergences
#' w <- c(0.3, 0.3, 0.2, 0.2)
#' w0 <- c(0.25, 0.25, 0.25, 0.25)
#'
#' # Entropy (KL divergence)
#' cr_divergence(w, w0, gamma = 0)
#'
#' # Empirical likelihood
#' cr_divergence(w, w0, gamma = -1)
#'
#' # Chi-squared
#' cr_divergence(w, w0, gamma = 1)
#'
#' @export
cr_divergence <- function(weights, base_weights, gamma = 0) {

  # Validate inputs
  if (length(weights) != length(base_weights)) {
    cli::cli_abort("weights and base_weights must have the same length")
  }

  # Normalize just in case
  w <- weights / sum(weights)
  w0 <- base_weights / sum(base_weights)

  # Handle numerical issues
  eps <- .Machine$double.eps^0.5

  if (abs(gamma) < eps) {
    # Entropy (KL divergence): lim_{gamma -> 0}
    # D_0 = sum(w * log(w / w0))
    valid <- w > eps & w0 > eps
    return(sum(w[valid] * log(w[valid] / w0[valid])))

  } else if (abs(gamma + 1) < eps) {
    # Empirical likelihood: gamma = -1
    # D_{-1} = -sum(w0 * log(w / w0)) = sum(w0 * log(w0 / w))
    valid <- w > eps & w0 > eps
    return(sum(w0[valid] * log(w0[valid] / w[valid])))

  } else {
    # General Cressie-Read
    # D_gamma = sum(w0 * ((w/w0)^(gamma+1) - 1)) / (gamma * (gamma + 1))
    valid <- w0 > eps
    ratio <- w[valid] / w0[valid]
    ratio <- pmax(ratio, eps)  # Avoid zero

    divergence <- sum(w0[valid] * (ratio^(gamma + 1) - 1)) / (gamma * (gamma + 1))
    return(divergence)
  }
}

#' Entropy (Kullback-Leibler) Loss
#'
#' Computes the entropy (Kullback-Leibler) divergence between weights and
#' base weights. This is the standard loss function for entropy balancing.
#'
#' @param weights Numeric vector of weights.
#' @param base_weights Numeric vector of base weights.
#'
#' @return Numeric value of the KL divergence.
#'
#' @details
#' The entropy loss is the Kullback-Leibler divergence:
#' \deqn{D_{KL}(w || w^{(0)}) = \sum_i w_i \log\left(\frac{w_i}{w_i^{(0)}}\right)}
#'
#' This is equivalent to Cressie-Read divergence with gamma = 0.
#'
#' @examples
#' w <- c(0.3, 0.3, 0.2, 0.2)
#' w0 <- c(0.25, 0.25, 0.25, 0.25)
#' entropy_loss(w, w0)
#'
#' @export
entropy_loss <- function(weights, base_weights) {
  cr_divergence(weights, base_weights, gamma = 0)
}

#' Empirical Likelihood Loss
#'
#' Computes the empirical likelihood divergence between weights and base weights.
#'
#' @param weights Numeric vector of weights.
#' @param base_weights Numeric vector of base weights.
#'
#' @return Numeric value of the EL divergence.
#'
#' @details
#' The empirical likelihood loss corresponds to Cressie-Read divergence with
#' gamma = -1:
#' \deqn{D_{EL}(w || w^{(0)}) = -\sum_i w_i^{(0)} \log\left(\frac{w_i}{w_i^{(0)}}\right)}
#'
#' Empirical likelihood has some theoretical advantages over entropy,
#' particularly for inference, as it leads to second-order accurate confidence
#' intervals.
#'
#' @references
#' Owen AB. (2001). Empirical Likelihood. Chapman & Hall/CRC.
#'
#' @examples
#' w <- c(0.3, 0.3, 0.2, 0.2)
#' w0 <- c(0.25, 0.25, 0.25, 0.25)
#' el_loss(w, w0)
#'
#' @export
el_loss <- function(weights, base_weights) {
  cr_divergence(weights, base_weights, gamma = -1)
}

#' Chi-Squared Loss
#'
#' Computes the chi-squared divergence between weights and base weights.
#'
#' @param weights Numeric vector of weights.
#' @param base_weights Numeric vector of base weights.
#'
#' @return Numeric value of the chi-squared divergence.
#'
#' @details
#' The chi-squared loss corresponds to Cressie-Read divergence with gamma = 1:
#' \deqn{D_{\chi^2}(w || w^{(0)}) = \frac{1}{2} \sum_i \frac{(w_i - w_i^{(0)})^2}{w_i^{(0)}}}
#'
#' @export
chisq_loss <- function(weights, base_weights) {
  cr_divergence(weights, base_weights, gamma = 1)
}

#' Hellinger Distance Loss
#'
#' Computes the Hellinger distance (squared) between weights and base weights.
#'
#' @param weights Numeric vector of weights.
#' @param base_weights Numeric vector of base weights.
#'
#' @return Numeric value of the Hellinger distance squared.
#'
#' @details
#' The Hellinger loss corresponds to Cressie-Read divergence with gamma = -0.5:
#' \deqn{D_H(w || w^{(0)}) = 2 \sum_i \left(\sqrt{w_i} - \sqrt{w_i^{(0)}}\right)^2}
#'
#' @export
hellinger_loss <- function(weights, base_weights) {
  cr_divergence(weights, base_weights, gamma = -0.5)
}

#' SE-Minimizing Loss (Experimental)
#'
#' Computes a loss function that aims to minimize the standard error of the
#' treatment effect estimate. This is an experimental/research direction
#' mentioned in Phillippo et al. (2020).
#'
#' @param weights Numeric vector of weights.
#' @param outcome Numeric vector of outcomes (required for SE calculation).
#' @param base_weights Numeric vector of base weights.
#' @param lambda Numeric. Regularization parameter to balance between
#'   divergence minimization and SE minimization.
#'
#' @return Numeric value of the combined loss.
#'
#' @details
#' This experimental loss function combines entropy divergence with a penalty
#' for the variance of the weighted outcome:
#' \deqn{L(w) = D_{KL}(w || w^{(0)}) + \lambda \cdot Var_w(Y)}
#'
#' The idea is to find weights that balance covariates while also minimizing
#' the variance of the treatment effect estimate. However, this approach
#' requires the outcome to be observed, which may introduce bias.
#'
#' This is marked as experimental and should be used with caution.
#'
#' @note This function is experimental and not recommended for production use.
#'
#' @export
se_minimizing_loss <- function(weights, outcome, base_weights, lambda = 0.1) {

  # Validate inputs
  if (length(weights) != length(outcome)) {
    cli::cli_abort("weights and outcome must have the same length")
  }

  # Normalize weights
  w <- weights / sum(weights)

  # Entropy divergence component
  div_component <- entropy_loss(w, base_weights)

  # Variance component (weighted variance of outcome)
  mu <- sum(w * outcome)
  var_component <- sum(w * (outcome - mu)^2)

  # Combined loss
  div_component + lambda * var_component
}

#' Get Loss Function by Name
#'
#' Utility function to retrieve a loss function by its name.
#'
#' @param name Character string specifying the loss function name.
#'   Options: "entropy", "empirical_likelihood", "chisq", "hellinger".
#'
#' @return A loss function.
#'
#' @keywords internal
get_loss_function <- function(name) {
  switch(
    name,
    "entropy" = entropy_loss,
    "empirical_likelihood" = el_loss,
    "chisq" = chisq_loss,
    "hellinger" = hellinger_loss,
    cli::cli_abort("Unknown loss function: {name}")
  )
}

#' Get Cressie-Read Gamma by Name
#'
#' Utility function to get the gamma parameter for Cressie-Read divergence
#' based on a descriptive name.
#'
#' @param name Character string: "entropy", "empirical_likelihood", "chisq", "hellinger".
#'
#' @return Numeric gamma value.
#'
#' @keywords internal
get_cr_gamma <- function(name) {
  switch(
    name,
    "entropy" = 0,
    "empirical_likelihood" = -1,
    "chisq" = 1,
    "hellinger" = -0.5,
    cli::cli_abort("Unknown loss function: {name}")
  )
}
