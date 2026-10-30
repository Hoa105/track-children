suppressPackageStartupMessages(library(anthro))
suppressPackageStartupMessages(library(jsonlite))
ns <- asNamespace("anthro")
names <- c(wfa="growthstandards_weianthro",lhfa="growthstandards_lenanthro",hcfa="growthstandards_hcanthro",bmifa="growthstandards_bmianthro",wfl="growthstandards_wflanthro",wfh="growthstandards_wfhanthro")
args <- commandArgs(trailingOnly=TRUE)
if(length(args) && args[[1]]=="--inspect") {
  for(name in names) {cat(name,"\n"); print(head(get(name,ns),2))}
  quit(status=0)
}
target <- if(length(args)) args[[1]] else "backend/data/who/attained.json"
tables <- lapply(names, function(name) get(name,ns))
dir.create(dirname(target),recursive=TRUE,showWarnings=FALSE)
writeLines(toJSON(list(anthro_version=as.character(packageVersion("anthro")),tables=tables),dataframe="rows",auto_unbox=TRUE,digits=NA),target,useBytes=TRUE)
