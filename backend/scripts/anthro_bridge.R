suppressPackageStartupMessages(library(anthro))
suppressPackageStartupMessages(library(jsonlite))
tryCatch({
  request <- fromJSON(file("stdin"), simplifyVector=FALSE)
  stopifnot(all(names(request) %in% c("schema_version","rows")))
  stopifnot(identical(request$schema_version, "1"), is.list(request$rows),
            length(request$rows)>0L, length(request$rows)<=128L)
  rows <- request$rows
  num <- function(row, key) {
    value <- row[[key]]
    if(is.null(value)) return(NA_real_)
    stopifnot(is.numeric(value), length(value)==1L, is.finite(value))
    if(key!="age_days") stopifnot(value>0)
    as.numeric(value)
  }
  ids <- vapply(rows, function(r) {
    stopifnot(is.character(r$row_id), length(r$row_id)==1L)
    r$row_id
  }, "")
  stopifnot(!anyDuplicated(ids))
  sexes <- vapply(rows, function(r) {
    stopifnot(is.character(r$sex), length(r$sex)==1L, r$sex %in% c("m","f"))
    r$sex
  }, "")
  ages <- vapply(rows, num, 0.0, key="age_days")
  stopifnot(all(is.finite(ages)), all(ages>=0), all(ages==floor(ages)))
  positions <- vapply(rows, function(r) {
    if(is.null(r$measure)) return(NA_character_)
    stopifnot(is.character(r$measure), length(r$measure)==1L, r$measure %in% c("l","h"))
    r$measure
  }, "")
  lengths <- vapply(rows, num, 0.0, key="lenhei_cm")
  stopifnot(all(is.na(lengths) | (!is.na(positions) & lengths>0)))
  allowed <- c("row_id","sex","age_days","weight_kg","lenhei_cm","measure","headc_cm")
  stopifnot(all(vapply(rows,function(r) all(names(r) %in% allowed),TRUE)))
  output <- anthro::anthro_zscores(sex=sexes, age=ages, is_age_in_month=FALSE,
    weight=vapply(rows,num,0.0,key="weight_kg"), lenhei=lengths, measure=positions,
    headc=vapply(rows,num,0.0,key="headc_cm"))
  stopifnot(nrow(output)==length(ids))
  numeric_columns <- vapply(output,is.numeric,TRUE)
  stopifnot(all(vapply(output[numeric_columns],function(x) all(is.na(x)|is.finite(x)),TRUE)))
  output$row_id <- ids
  cat(toJSON(list(schema_version="1", engine=list(R_version=as.character(getRversion()),
    anthro_version=as.character(packageVersion("anthro")),
    jsonlite_version=as.character(packageVersion("jsonlite")), bridge_version="1"),
    rows=output),auto_unbox=TRUE,dataframe="rows",na="null",digits=NA))
}, error=function(e) {
  message("ANTHRO_BRIDGE_FAILED")
  quit(status=1L)
})
