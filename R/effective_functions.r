### Auxiliary Functions for Effective Presentation of Statistical Results ###
### Dave Armstrong
### 2-28-2021





#' Kernel Density with Normal Density Overlay
#'
#' Calculates a kernel density estimate of the data along with confidence bounds.
#' It also computes a normal density and confidence bounds for the normal density
#' with the same mean and variance as the observed data.
#'
#' @param x A vector of values whose density is to be calculated
#' @param ... Other arguments to be passed down to \code{sm.density}.
#' @details The function is largely cribbed from the \pkg{sm} package by
#' Bowman and Azzalini
#' @return A named vector of scalar measures of fit
#' @author Dave Armstrong, A.W. Bowman and A. Azzalini
#' @references A.W> Bowman and A. Azzalini, R package sm: nonparametric smoothing methods
#' (verstion 5.6).
#'
#' @export
#' @importFrom stats density sd na.omit dnorm
#' @importFrom sm sm.density
normBand <- function (x, ...){
  x <- na.omit(x)
  d <- density(x, ...)
  s <- sm::sm.density(x, h=d$bw, model="none", eval.points=d$x, display="none")
  x.points <- d$x
  xbar <- mean(x, na.rm=TRUE)
  sx <- sd(x, na.rm=TRUE)
  hm <- d$bw
  dmean <- dnorm(x.points, xbar, sqrt(sx^2 + hm^2))
  dvar <- (dnorm(0, 0, sqrt(2 * hm^2)) * dnorm(x.points, xbar,
                                               sqrt(sx^2 + 0.5 * hm^2)) - (dmean)^2)/length(x)
  upper <- dmean + 2 * sqrt(dvar)
  lower <- dmean - 2 * sqrt(dvar)
  out <- data.frame(
    eval.points = x.points,
    obsden = s$estimate,
    lwd_od = s$lower,
    upr_od = s$upper,
    normden = dmean,
    lwr = lower,
    upr = upper)
  return(out)
}

#' Quantile Comparison Data
#'
#' Makes data that can be used in quantile comparison plots.
#'
#' @param x vector of values whose quantiles will be calculated.
#' @param distribution String giving the theoretical distribution
#' against which the quantiles of the observed data will be compared.
#' These need to be functions that have \code{q} and \code{d} functions
#' in R.  Defaults to "norm".
#' @param line String giving the nature of the line that should be drawn
#' through the points.  If "quartiles", the line is drawn connecting the 25th
#' and 75th percentiles.  If "robust" a robust linear model is used to fit
#' the line.
#' @param conf Confidence level to be used.
#' @param ... Other parameters to be passed down to the quantile function.
#'
#' @return A data frame with variables \code{x} observed quantiles,
#' \code{theo} the theoretical quantiles and \code{lwr} and \code{upr}
#' the confidence bounds.  The slope and intercept of the line running
#' through the points are returned as \code{a} and \code{b} as an
#' attribute of the data.a
#'
#' @export
#'
#' @importFrom stats qnorm dnorm quantile coef ppoints
#' @importFrom MASS rlm
#' @importFrom ggplot2 ggplot aes geom_ribbon geom_segment geom_point theme_classic labs
#'
#' @examples
#' x <- rchisq(100, 3)
#' qqdf <- qqPoints(x)
#' a <- attr(qqdf, "ab")[1]
#' b <- attr(qqdf, "ab")[2]
#' l <- min(qqdf$theo) * b + a
#' u <- max(qqdf$theo) * b + a
#' library(ggplot2)
#' ggplot(qqdf, aes(x=theo, y=x)) +
#'   geom_ribbon(aes(ymin=lwr, ymax=upr), alpha=.15) +
#'   geom_segment(aes(x=min(qqdf$theo), xend=max(qqdf$theo), y = l, yend=u)) +
#'   geom_point(shape=1) +
#'   theme_classic() +
#'   labs(x="Theoretical Quantiles",
#'        y="Observed Quantiles")
qqPoints <- function (x,
                      distribution = "norm",
                      line = c("quartiles", "robust", "none"),
                      conf=.95, ...) {
  ## Taken from car:::qqPlot.default with some minor modifications
  line = match.arg(line)
  index <- seq(along = x)
  good <- !is.na(x)
  ord <- order(x[good])
  ord.x <- x[good][ord]
  q.function <- eval(parse(text = paste("q", distribution,
                                        sep = "")))
  d.function <- eval(parse(text = paste("d", distribution,
                                        sep = "")))
  n <- length(ord.x)
  P <- ppoints(n)
  z <- q.function(P, ...)
  #  points(z, ord.x, col = col, pch = pch, cex = cex)
  if (line == "quartiles" || line == "none") {
    Q.x <- quantile(ord.x, c(0.25, 0.75))
    Q.z <- q.function(c(0.25, 0.75), ...)
    b <- (Q.x[2] - Q.x[1])/(Q.z[2] - Q.z[1])
    a <- Q.x[1] - b * Q.z[1]
  }
  if (line == "robust") {
    coef <- coef(rlm(ord.x ~ z))
    a <- coef[1]
    b <- coef[2]
  }
  zz <- qnorm(1 - (1 - conf)/2)
  SE <- (b/d.function(z, ...)) * sqrt(P * (1 - P)/n)
  fit.value <- a + b * z
  upper <- fit.value + zz * SE
  lower <- fit.value - zz * SE
  outdf <- data.frame(
    x=ord.x,
    theo = z,
    lwr = lower,
    upr = upper
  )
  attr(outdf, "ab") <- c(a=a, b=b)
  return(outdf)
}

#' Transform Variables to Normality
#'
#' Uses the method proposed by Velez, Correa and Marmolejo-Ramos
#' to normalize variables using Box-Cox or Yeo-Johnson transformations.
#'
#' @param x Vector of values to be transformed to normality
#' @param start Positive value to be added to variable to ensure
#' all values are positive.  This follows the transformation of the variable
#' to have its minimum value be zero.
#' @param family Family of test - Box-Cox or Yeo-Johnson.
#' @param lams A vector of length 2 giving the range of values for the
#' transformation parameter.
#' @param combine.method String giving the method used to to combine
#' p-values from normality tests.
#' @param ... Other arguments, currently unimplemented.
#'
#' @return A scalar giving the optimal transformation parameter.
#'
#' @references
#' Velez Jorge I., Correa Juan C., Marmolejo-Ramos Fernando.  (2015)
#' "A new approach to the Box-Cox Transformation" Frontiers in Applied
#' Mathematics and Statistics.
#'
#' @export
#'
#' @importFrom stats na.omit shapiro.test
#' @importFrom car bcPower yjPower
#' @importFrom nortest lillie.test sf.test ad.test
#' @importFrom lawstat rjb.test
#' @importFrom normwhn.test normality.test1
transNorm <- function(x, start = .01, family=c("bc", "yj"), lams,
                      combine.method = c("Stouffer", "Fisher", "Average"), ...){
  family <- match.arg(family)
  cm <- match.arg(combine.method)
  x <- na.omit(x)
  if(any(x <=0) & family == "bc"){
    x <- x-min(x) + start
  }
  lambda <- seq(lams[1], lams[2], length=50)
  ptfun <- switch(family, bc = bcPower, yj = yjPower)

  trans_vals <- sapply(lambda, function(l)ptfun(x, lambda=l))
  novar <- which(apply(trans_vals, 2, sd) == 0)
  if(length(novar) > 0){
    trans_vals <- trans_vals[,-novar]
    lambda <- lambda[-novar]
  }
  trans_vals <- scale(trans_vals)
  p1 <- sapply(1:ncol(trans_vals), function(i)lillie.test(trans_vals[,i])$p.value)
  p2 <- sapply(1:ncol(trans_vals), function(i)sf.test(trans_vals[,i])$p.value)
  p3 <- sapply(1:ncol(trans_vals), function(i)ad.test(trans_vals[,i])$p.value)
  p4 <- sapply(1:ncol(trans_vals), function(i)shapiro.test(trans_vals[,i])$p.value)
  p5 <- sapply(1:ncol(trans_vals), function(i)rjb.test(trans_vals[,i])$p.value)
  sink(tempfile())
  p6 <- sapply(1:ncol(trans_vals), function(i)c(normality.test1(trans_vals[,i, drop=FALSE])[1,1]))
  sink()
  allp <- cbind(p1, p2, p3, p4, p5, p6)
  pcfun <- switch(cm, Stouffer = metap::sumz, Fisher = metap::sumlog, Average = metap::meanp)
  if(any(allp < 0.0000001)){
    allp[which(allp < 0.0000001, arr.ind= TRUE)] <- 0.0000001
  }
  p.combine <- apply(allp, 1, function(x)pcfun(x)$p)
  c(lambda = lambda[which.max(p.combine)])
}

#' Dot Plot with Leter Display
#'
#' Produces an dot plot with error bars along with a compact letter display
#'
#' @param fits Output from \code{ggpredict} from the \pkg{ggeffects}
#' @param letters A matrix of character strings giving the letters from a
#' compact letter display.  This is most often from a call to \code{cld} from the
#' \pkg{multcomp} package.
#'
#' @importFrom ggplot2 geom_errorbarh ggplot_build aes_string geom_vline scale_x_continuous coord_cartesian ylab
#' @importFrom tibble as_tibble
#' @importFrom dplyr left_join
letter_plot <- function(fits, letters){
  if(!(all(c("x", "predicted", "conf.low", "conf.high") %in% names(fits))))stop("x, predicted, conf.low and conf.high need to be variables in the 'fits' data frame.")
  lmat <- letters
  g1 <- ggplot(fits, aes_string(y="x")) +
    geom_errorbarh(aes_string(xmin="conf.low", xmax="conf.high"),
                   height=0) +
    geom_point(aes_string(x="predicted"))
  p <- ggplot_build(g1)
  rgx <- p$layout$panel_params[[1]]$x.range
  diffrg <- diff(rgx)
  prty <- pretty(rgx, 4)
  if(prty[length(prty)] > rgx[2]){
    prty <- prty[-length(prty)]
  }
  labs <- as.character(prty)
  diffrg <- diff(range(c(rgx, prty)))
  firstlet <- max(c(max(prty), rgx[2])) + .075*diffrg
  vl <- max(rgx) + .0375*diffrg
  letbrk <- firstlet + (0:(ncol(lmat)-1))*.05*diffrg
  prty <- c(prty, letbrk)
  labs <- c(labs, LETTERS[1:ncol(lmat)])
  lmat <- t(apply(lmat, 1, function(x)x*letbrk))
  if(any(lmat == 0)){
    lmat[which(lmat == 0, arr.ind=TRUE)] <- NA
  }
  ldat <- as_tibble(lmat, rownames="x")
  dat <- left_join(fits, ldat)
  out <- ggplot(dat, aes_string(y="x")) +
    geom_errorbarh(aes_string(xmin="conf.low", xmax="conf.high"), height=0) +
    geom_point(aes_string(x="predicted"))
  obs_lets <- colnames(lmat)
  for(i in 1:length(obs_lets)){
    out <- out + geom_point(mapping=aes_string(x=obs_lets[i]), size=2.5)
  }
  out <- out + geom_vline(xintercept=vl, lty=2)+
    scale_x_continuous(breaks=prty,
                       labels=labs) +
    theme_classic() +
    coord_cartesian(clip='off') +
    ylab("")
  out
}

#' Calculate Simple Slopes
#'
#' Calculates Simple Slopes from an interaction between a categorical
#' and quantitative variable.
#'
#' @param mod A model object that contains an interaction between a
#' quantitative variable and a factor.
#' @param quant_var A character string giving the name of the quantitative
#' variable ine the interaction.
#' @param cat_var A character string giving the name of the factor
#' variable ine the interaction.
#'
#' @return A data frame giving the conditional partial effect
#' along with standard errors, t-statistics and p-values.
#'
#' @importFrom tibble tibble
#' @importFrom dplyr mutate
#' @importFrom stats pt vcov
#' @importFrom utils combn
#'
#' @export
simple_slopes <- function(mod, quant_var, cat_var){
  inds <- grep(quant_var, names(coef(mod)))
  me <- which(names(coef(mod)) == quant_var)
  inds <- c(me, setdiff(inds, me))
  levs <- mod$xlevels[[cat_var]]
  c1 <- matrix(0, nrow=length(levs), ncol=length(coef(mod)))
  rownames(c1) <- levs
  c1[1,inds[1]] <- 1
  for(i in 2:length(levs)){
    c1[i, inds[c(1,i)]] <- 1
  }
  est <-  c1 %*% coef(mod)
  v.est <- c1 %*% vcov(mod) %*% t(c1)
  df1 <- tibble(
    group = levs,
    slope = c(est),
    se = sqrt(diag(v.est)))
  df1 <- df1 %>% mutate(t = .data$slope/.data$se,
                        p = 2*pt(abs(.data$t),
                                     mod$df.residual,
                                     lower.tail=FALSE))
  combs <- combn(length(levs), 2)
  c2 <- matrix(0, ncol = ncol(combs), nrow=length(est))
  c2[cbind(combs[1,], 1:ncol(combs))] <- 1
  c2[cbind(combs[2,], 1:ncol(combs))] <- -1
  labs <- paste(levs[combs[1,]], levs[combs[2,]], sep="-")
  colnames(c2) <- labs
  df2 <- tibble(
    comp = labs,
    diff = c(t(c2) %*% est),
    se = sqrt(diag(t(c2) %*% v.est %*% c2)))
  df2 <- df2 %>% mutate(
    t = .data$diff/.data$se,
    p = 2*pt(abs(.data$t), mod$df.residual, lower.tail=FALSE))
  res <- list(est = df1, comp=df2)
  class(res) <- "ss"
  res
}

#' Print Method for Simple Slopes
#'
#' Prints the results of the Simple Slopes function
#'
#' @param x An object of class \code{ss}.
#' @param ... Other arguments passed down to \code{print}
#'
#' @return Printed output
#'
#' @export
#' @method print ss
print.ss <- function(x, ...){
  cat("Simple Slopes:\n")
  print(x$est, ...)
  cat("\nPairwise Comparisons:\n")
  print(x$comp, ...)
}

#' Compact Letter Display for Simple Slopes
#'
#' Calculates a letter matrix for a simple-slopes output.
#'
#' @param x An object of class `ss`
#' @param level Confidence level used for the letters.
#' @param ... Other arguments to be passed to generic function.
#'
#' @return A compact letter matrix
#'
#' @importFrom magrittr %>%
#' @importFrom dplyr arrange select pull
#' @importFrom tidyr separate
#' @importFrom utils getFromNamespace
#' @importFrom multcomp cld
#' @importFrom rlang .data
#'
#' @export
#' @method cld ss
cld.ss <- function(x, level=.05, ...){
  ord <- x$est %>% arrange(.data$slope) %>% select("group") %>% pull
  signif <- x$comp$p < level
  comps <- x$comp %>% select("comp") %>% separate(.data$comp, sep="-", into=c("g1", "g2")) %>% as.matrix()
  rownames(comps) <- x$comp$comp
  ia <- getFromNamespace("insert_absorb", "multcomp")
  ia(signif, comps=comps, lvl_order = ord)$LetterMatrix
}

#' BCn Power Transformation of Variable
#'
#' @param x variable to be transformed
#' @noRd
#'
#' @importFrom car powerTransform bcnPower
trans_fun <- function(x){
  p <- powerTransform(x, family="bcnPower")
  trans <- bcnPower(x, p$lambda, gamma=p$gamma)
  trans
}

#' Association Function
#'
#' Calculates the R-squared from a LOESS regression of
#' y on x.  Can be used with \code{outer} to produce the
#' a non-parametric correlation matrix.
#'
#' @param xind column index of the x-variable
#' @param yind column index of the y-variable
#' @param data data frame from which to pull the variables.
#'
#' @return a squared correlation.
#'
#' @importFrom fANCOVA loess.as
#' @importFrom stats cor
#'
#' @export
assocfun <- function(xind,yind, data){
  d <- data.frame(x=data[,xind],
                  y=data[,yind])
  d <- na.omit(d)
  l <- loess.as(d$x, d$y, criterion="gcv")
  cor(d$y, l$fitted, use="pair")^2
}

#' Linear Scatterplot Array
#'
#' Produces a linear scatterplot array with marginal histograms
#'
#' @param formula Formula giving the variables to be plotted.
#' @param xlabels Vector of character strings giving the labs of
#' variables to be used in place of the variable names.
#' @param ylab Character string giving y-variable label to be
#' used instead of variable name.
#' @param data A data frame that holds the variables to be plotted.
#'
#' @importFrom ggplot2 geom_smooth facet_wrap theme_bw theme
#' element_blank element_text geom_histogram element_line coord_flip
#' @importFrom grid rectGrob gpar
#' @importFrom cowplot plot_grid
#' @importFrom stats as.formula terms
#'
#' @return A \code{cowplot} object.
#'
#' @export


lsa <- function(formula, xlabels=NULL, ylab = NULL, data){
  if (!attr(terms(as.formula(formula)), which = 'response'))
    stop("No DV in formula.\n")
  avf <- all.vars(formula)
  tmp <- data %>%
    select(avf)
  dv <- avf[1]
  ivs <- avf[-1]
  if(is.null(ylab))ylab <- dv
  if(is.null(xlabels))xlabels <- ivs
  if(length(ivs) != length(xlabels))stop("Labels and #IVs are not the same\n")
  slist <- hlist <- list()
  for(i in 1:length(ivs)){
    if(i == 1){
      slist[[i]] <- ggplot(tmp, aes_string(y=dv, x=ivs[i])) +
      geom_point(size=.5, shape=1) +
      geom_smooth(method="loess", size=.5, se=FALSE, col="black") +
      facet_wrap(as.formula(paste0('~"', xlabels[i], '"')))+
      theme_bw() +
      theme(panel.grid=element_blank()) +
      labs(x="", y=ylab[1])

      hlist[[i]] <- ggplot(tmp, aes_string(x=ivs[i])) +
      geom_histogram(fill="gray75", col="white", bins=15) +
      theme(panel.grid=element_blank(),
            panel.background = element_blank(),
            axis.text.x = element_blank(),
            axis.title.x=element_blank(),
            axis.ticks.x = element_blank(),
            axis.title.y = element_text(colour="transparent"),
            axis.text.y=element_text(colour="transparent"),
            axis.ticks.y = element_line(colour="transparent")) +
      labs(y="Histogram")
    }else{
      slist[[i]] <- ggplot(tmp, aes_string(y=dv, x=ivs[i])) +
        geom_point(size=.5, shape=1) +
        geom_smooth(method="loess", size=.5, se=FALSE, col="black") +
        facet_wrap(as.formula(paste0('~"', xlabels[i], '"')))+
        theme_bw() +
        theme(panel.grid=element_blank(),
              axis.text.y=element_blank(),
              axis.ticks.y = element_blank(),
              axis.title.y = element_blank()) +
        labs(x="", y="Y")
      hlist[[i]] <- ggplot(tmp, aes_string(x=ivs[i])) +
        geom_histogram(fill="gray75", col="white", bins=15) +
        theme(panel.grid=element_blank(),
              panel.background = element_blank(),
              axis.text.x = element_blank(),
              axis.title.x=element_blank(),
              axis.ticks.x = element_blank(),
              axis.title.y = element_blank(),
              axis.text.y=element_blank(),
              axis.ticks.y = element_blank())

    }
  }
    hlist[[(length(ivs)+1)]] <- rectGrob(gp=gpar(col="white")) # make a white spacer grob
    slist[[(length(ivs)+1)]] <- ggplot(tmp, aes_string(x=dv)) +
      geom_histogram(fill="gray75", col="white", bins=15) +
      theme(panel.grid=element_blank(),
            panel.background = element_blank(),
            axis.text.y = element_blank(),
            axis.ticks.y = element_blank(),
            axis.title.y=element_blank(),
            axis.text.x=element_text(colour="transparent"),
            axis.ticks.x = element_line(colour="transparent"),
            axis.title.x=element_blank()
      ) +
      labs(x="", y="") +
      coord_flip()

  l <- c(hlist, slist)
  l[["nrow"]] = 2
  l[["rel_heights"]] = rel_heights=c(1,5)
  l[["rel_widths"]] = rel_widths=c(1.25, rep(1, length(ivs)-1), .5)
  do.call(plot_grid, l)
}

#' Caption Grob
#'
#' Create a caption grob
#'
#' @param lab Text giving the caption text.
#' @param x Scalar giving the horizontal position of the label in \code{[0,1]}.
#' @param y Scalar giving the vertical position of the label in \code{[0,1]}.
#' @param hj Scalar giving horizontal justification parameter.
#' @param vj Scalar giving vertical justification parameter.
#' @param cx Character expansion factor
#' @param fs Font size
#' @param ft Font type
#'
#' @return A text grob.
#'
#' @importFrom grid textGrob unit
#'
#' @export
caption <- function(lab, x=.5, y=1, hj=.5, vj=1, cx=1, fs=12, ft="Arial"){
  textGrob(label=lab,
           x=unit(x, "npc"), y=unit(y, "npc"),
           hjust=hj, vjust=vj,
           gp=gpar(fontsize=fs, fontfamily=ft))

}

#' Bootstrap Importance Function
#'
#' Function to calculate bootstrap measures of importance.
#' This function must be passed to the \code{boot} function.
#'
#' @param data A data frame
#' @param inds Indices to be passed into the function.
#' @param obj An object of class \code{lm}.
#'
#' @return A vector of standard deviation of predictions for
#' each term in the model.
#'
#' @importFrom stats predict update
#'
#' @export
boot_imp <- function(data, inds, obj){
  tmp <- update(obj, data=data[inds, ])
  apply(predict(tmp, type="terms"), 2, sd)
}

#' Absolute Importance Measure
#'
#' Calculates absolute importance along the lines consistent with
#' relative importance as defined by Silber, Rosenbaum and Ross (1995)
#'
#' @param obj Model object, must be able to use \code{predict(obj, type="terms")}.
#' @param data A data frame used to estiamte the model.
#' @param boot Logical indicating whether bootstrap confidence intervals should
#' be produced and included.
#' @param R If \code{boot=TRUE}, the number of bootstrap samples to be used.
#' @param level Cofidence level used for the confidence interval.
#' @param ci_method Character string giving the method for calculating the
#' bootstrapped confidence interval.
#' @param ... Other arguments being passed down to \code{boot}.
#'
#' @return A data frame of importance measures with optimal bootstrapped confidence intervals.
#'
#' @importFrom boot boot boot.ci
#'
#' @references Silber, J. H., Rosenbaum, P. R. and Ross, R N (1995) Comparing the Contributions of Groups of Predictors: Which Outcomes Vary with Hospital Rather than Patient Characteristics? JASA 90, 7–18.
#'
#' @export
srr_imp <- function(obj,
                    data,
                    boot=TRUE,
                    R=250,
                    level = .95,
                    ci_method=c("perc", "norm", "bca"),
                    ...){
  cim <- match.arg(ci_method)
  trms <- predict(obj, type="terms")
  out <- do.call(data.frame, list(importance=apply(trms, 2, sd)))
  out$var <- rownames(out)
  rownames(out) <- NULL
  out <- out[,c("var", "importance")]
  if(boot){
    b_out <- boot(data, boot_imp, R=R, obj=obj, ...)
    b_ci <- t(sapply(1:ncol(b_out$t), function(i)boot.ci(b_out, conf=level, type=cim, index=i)[[4]]))[,4:5]
    colnames(b_ci) <- c("lwr", "upr")
    out <- cbind(out, b_ci)
  }
  return(out)
}

#' Importace Measure for Generalized Linear Models
#'
#' Calculates importance along the lines of Greenwell et al (2018)
#' using partial dependence plots.
#'
#' @param obj Model object, must be able to use \code{predict(obj, type="terms")}.
#' @param data A data frame used to estiamte the model.
#' @param varname Character string giving the name of the variable whose importance
#' will be calculated.
#' @param level Cofidence level used for the confidence interval.
#' @param ci_method Character string giving the method for calculating the
#' confidence interval - normal or percentile.
#' @param ... Other arguments being passed down to \code{aveEffPlot} from the \pkg{\link{DAMisc}} package.
#'
#' @return A data frame of importance measures with optimal bootstrapped confidence intervals.
#'
#' @references Greenwell, Brandon M., Bradley C. Boehmke and Andrew J. McCarthy.  (2018). “A Simple and Effective Model-Based Variable Importance Measure.”  arXiv1805.04755 [stat.ML]
#'
#' @importFrom DAMisc aveEffPlot
#'
#' @export
glmImp <- function(obj,
                   varname,
                   data,
                   level=.95,
                   ci_method = c("perc", "norm"),
                   ...){
  cit <- match.arg(ci_method)
  a <- (1-level)/2
  fac <- is.factor(data[[varname]])
  eff <- aveEffPlot(obj, varname, data, return = "sim", ...)
  re <- apply(eff$sim, 1, sd)
  ce <- colMeans(eff$sim)
  if(!fac){
    e <- sd(ce)
  }else{
    e <- diff(range(ce))/4
  }
  if(cit == "norm"){
    outci <- e + qnorm(c(a, 1-a))*sd(re)
  }else{
    outci <- quantile(re, probs=c(a, 1-a))
  }
  res <- data.frame(imp = e, lwr = outci[1], upr = outci[2])
  res
}


