# Run from repository root with backend/.r-library on R_LIBS_USER.
# Read-only verification of shipped tables against the installed WHO anthro engine.
suppressPackageStartupMessages(library(anthro))
suppressPackageStartupMessages(library(jsonlite))
args <- commandArgs(trailingOnly=TRUE)
target <- if(length(args)) args[[1]] else "tmp/attained-anthro-verification.json"
data <- fromJSON("backend/data/who/attained.json")
names <- c(wfa="growthstandards_weianthro",lhfa="growthstandards_lenanthro",
           hcfa="growthstandards_hcanthro",bmifa="growthstandards_bmianthro",
           wfl="growthstandards_wflanthro",wfh="growthstandards_wfhanthro")
tables <- lapply(names(names), function(ind) {
  actual <- data$tables[[ind]]
  expected <- get(names[[ind]], asNamespace("anthro"))
  same <- identical(names(actual), names(expected)) &&
    isTRUE(all.equal(actual, expected, tolerance=0, check.attributes=FALSE))
  list(indicator=ind, rows=nrow(actual), cells=nrow(actual)*ncol(actual), exact_match=same)
})
q <- function(r,z) ifelse(r$l == 0, r$m*exp(r$s*z), r$m*(1+r$l*r$s*z)^(1/r$l))
checks <- lapply(c("wfa","wfl","wfh"), function(ind) {
  r <- data$tables[[ind]]
  scores <- c(-4,-3,-2,0,2,3,4)
  r <- r[rep(seq_len(nrow(r)), each=length(scores)),]
  z <- rep(scores, length.out=nrow(r))
  value <- q(r,pmax(-3,pmin(3,z)))
  value[z > 3] <- (q(r,3)+(z-3)*(q(r,3)-q(r,2)))[z > 3]
  value[z < -3] <- (q(r,-3)+(z+3)*(q(r,-2)-q(r,-3)))[z < -3]
  age <- if(ind == "wfa") r$age else rep(if(ind == "wfl") 365 else 900,nrow(r))
  result <- anthro_zscores(sex=r$sex,age=age,is_age_in_month=FALSE,weight=value,
    lenhei=if(ind == "wfa") rep(NA_real_,nrow(r)) else r[[if(ind == "wfl") "length" else "height"]],
    measure=rep(if(ind == "wfh") "h" else "l",nrow(r)))
  observed <- result[[if(ind == "wfa") "zwei" else "zwfl"]]
  errors <- abs(observed-z)
  bad <- which(is.na(errors) | errors > 0.011)
  list(indicator=ind,cases=length(z),missing=sum(is.na(observed)),
       max_absolute_error=max(errors,na.rm=TRUE), failures=length(bad),
       examples=lapply(head(bad,10),function(i) list(sex=r$sex[i],age_days=age[i],
         x=if(ind == "wfa") age[i] else r[[if(ind == "wfl") "length" else "height"]][i],
         weight_kg=value[i],expected=z[i],observed=observed[i])))
})
report <- list(engine=list(R=as.character(getRversion()),anthro=as.character(packageVersion("anthro"))),
  scope="All attained table cells; all WFA/WFL/WFH rows at SD -4,-3,-2,0,2,3,4",
  caveat="Comparison against installed WHO anthro package, not independent WHO desktop software or downloaded golden fixtures",
  tolerance=0.011,tables=tables,public_engine=checks,
  passed=all(vapply(tables,function(x)x$exact_match,TRUE)) && all(vapply(checks,function(x)x$failures==0,TRUE)))
dir.create(dirname(target),recursive=TRUE,showWarnings=FALSE)
writeLines(toJSON(report,auto_unbox=TRUE,pretty=TRUE,digits=NA,na="null"),target)
cat(toJSON(report,auto_unbox=TRUE,pretty=TRUE,digits=NA,na="null"))
if(!report$passed) quit(status=1)
