test_that("entropy loss equals zero for identical weights", {
  w <- c(0.25, 0.25, 0.25, 0.25)
  w0 <- c(0.25, 0.25, 0.25, 0.25)

  loss <- entropy_loss(w, w0)
  expect_equal(loss, 0, tolerance = 1e-10)
})

test_that("entropy loss is positive for different weights", {
  w <- c(0.4, 0.3, 0.2, 0.1)
  w0 <- c(0.25, 0.25, 0.25, 0.25)

  loss <- entropy_loss(w, w0)
  expect_true(loss > 0)
})

test_that("Cressie-Read divergence with gamma=0 equals entropy", {
  w <- c(0.3, 0.3, 0.2, 0.2)
  w0 <- c(0.25, 0.25, 0.25, 0.25)

  entropy <- entropy_loss(w, w0)
  cr_entropy <- cr_divergence(w, w0, gamma = 0)

  expect_equal(entropy, cr_entropy, tolerance = 1e-10)
})

test_that("Cressie-Read divergence with gamma=-1 equals EL", {
  w <- c(0.3, 0.3, 0.2, 0.2)
  w0 <- c(0.25, 0.25, 0.25, 0.25)

  el <- el_loss(w, w0)
  cr_el <- cr_divergence(w, w0, gamma = -1)

  expect_equal(el, cr_el, tolerance = 1e-10)
})

test_that("all Cressie-Read divergences are non-negative", {
  w <- c(0.4, 0.3, 0.2, 0.1)
  w0 <- c(0.25, 0.25, 0.25, 0.25)

  # Test various gamma values
  gammas <- c(-2, -1, -0.5, 0, 0.5, 1, 2)

  for (g in gammas) {
    div <- cr_divergence(w, w0, gamma = g)
    expect_true(div >= 0, info = paste("gamma =", g))
  }
})
