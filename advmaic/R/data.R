#' @title Example Datasets for advmaic
#' @name data
#' @description Example datasets demonstrating MAIC analysis workflows.
NULL

#' Example MAIC Scenario Data
#'
#' A simulated dataset for demonstrating MAIC analysis, representing a
#' two-trial indirect comparison scenario.
#'
#' @format A list with the following elements:
#' \describe{
#'   \item{AB_ipd}{Data frame with 300 rows (IPD from index trial A vs B):
#'     \describe{
#'       \item{id}{Patient identifier}
#'       \item{age}{Age in years (continuous)}
#'       \item{male}{Sex (1 = male, 0 = female)}
#'       \item{biomarker}{Biomarker value (continuous)}
#'       \item{treatment}{Treatment arm (0 = A, 1 = B)}
#'       \item{outcome}{Binary outcome (0/1)}
#'     }
#'   }
#'   \item{AC_agd}{Named vector of aggregate statistics from comparator trial (A vs C):
#'     \describe{
#'       \item{age}{Mean age}
#'       \item{male}{Proportion male}
#'       \item{biomarker}{Mean biomarker value}
#'     }
#'   }
#'   \item{AC_effect}{Log odds ratio for C vs A from aggregate data}
#'   \item{AC_var}{Variance of log odds ratio}
#' }
#'
#' @source Simulated data for package demonstration
#'
#' @examples
#' # Load example data
#' data(maic_example)
#'
#' # View IPD structure
#' head(maic_example$AB_ipd)
#'
#' # View AgD targets
#' maic_example$AC_agd
#'
#' # Run MAIC analysis
#' weights <- estimate_weights(
#'   ipd = maic_example$AB_ipd,
#'   agd_target = maic_example$AC_agd,
#'   covariates = c("age", "male", "biomarker")
#' )
#'
"maic_example"

#' Create Example MAIC Dataset
#'
#' Internal function to generate the example dataset.
#'
#' @return List with example data
#' @keywords internal
create_maic_example <- function() {

  set.seed(20260117)

  n <- 300

  # Generate IPD for AB trial
  AB_ipd <- data.frame(
    id = 1:n,
    age = rnorm(n, 55, 10),
    male = rbinom(n, 1, 0.6),
    biomarker = rnorm(n, 100, 20),
    treatment = rep(c(0, 1), each = n/2)
  )

  # Generate outcomes
  linear_pred <- with(AB_ipd,
    -1 +                          # Intercept
    0.02 * (age - 55) +           # Prognostic
    0.3 * male +                  # Prognostic
    0.01 * (biomarker - 100) +    # Prognostic
    -0.5 * treatment +            # Treatment effect (B vs A)
    -0.02 * (age - 55) * treatment  # Effect modification
  )

  AB_ipd$outcome <- rbinom(n, 1, plogis(linear_pred))

  # Generate AgD for AC trial (different population)
  AC_agd <- c(
    age = 60,        # Older population
    male = 0.5,      # Different sex distribution
    biomarker = 110  # Higher biomarker
  )

  # Effect of C vs A (from AC trial)
  AC_effect <- -0.7  # Log OR
  AC_var <- 0.05     # Variance

  list(
    AB_ipd = AB_ipd,
    AC_agd = AC_agd,
    AC_effect = AC_effect,
    AC_var = AC_var
  )
}
