args <- commandArgs(trailingOnly=TRUE)
target <- if(length(args)) args[[1]] else "backend/.r-library"
dir.create(target, recursive=TRUE, showWarnings=FALSE)
.libPaths(c(normalizePath(target), .libPaths()))
versions <- c(anthro="1.1.0",jsonlite="2.0.0")
for (pkg in names(versions)) {
  if (!requireNamespace(pkg, quietly=TRUE) || as.character(packageVersion(pkg))!=versions[[pkg]]) {
    if (.Platform$OS.type=="windows") {
      minor <- strsplit(as.character(getRversion()),".",fixed=TRUE)[[1]]
      url <- paste0("https://cloud.r-project.org/bin/windows/contrib/",paste(minor[1:2],collapse="."),"/",pkg,"_",versions[[pkg]],".zip")
      install.packages(url,lib=target,repos=NULL,type="win.binary")
    } else {
      if(!requireNamespace("remotes",quietly=TRUE)) install.packages("remotes",lib=target,repos="https://cloud.r-project.org")
      remotes::install_version(pkg,version=versions[[pkg]],lib=target,repos="https://cloud.r-project.org",upgrade="never")
    }
  }
  stopifnot(requireNamespace(pkg, quietly=TRUE))
  stopifnot(as.character(packageVersion(pkg))==versions[[pkg]])
  cat(pkg, as.character(packageVersion(pkg)), "\n")
}
