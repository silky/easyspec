library(ggplot2)
args <- commandArgs(trailingOnly=TRUE)

if (length(args) != 11) {
  stop("Usage: evaluators_bars_per_group.r common.r input.csv output.pdf granularity groupName evaluator1 indication1 evaluator2 indication2 strategy1 strategy2")
}

common <- args[1]
inFile <- args[2]
outPdf <- args[3]
# granularity <- args[4]
groupName <- args[5]
e1 <- args[6]
i1 <- args[7]
e2 <- args[8]
i2 <- args[9]
s1 <- args[10]
s2 <- args[11]

source(common)

res = read.csv(inFile, header=TRUE)

res$origin <- paste(res$file, res$focus, res$strategy)

res <- res[(res$strategy == s1 | res$strategy == s2),]

# Select the right data
res1 <- res[res$evaluator == e1,]
res2 <- res[res$evaluator == e2,]

# Make the output numeric
res$output <- suppressWarnings(as.numeric(as.character(res$output)))

# Replace NaN with '0'
res$output <- replace(res$output, is.na(res$output), 0)

dat <- merge(res1, res2, by = "origin")
dat <- dat[!is.na(dat$output.x),]
dat <- dat[!is.na(dat$output.y),]

if (length(dat$origin) != 0) {
  startPdf(outPdf)
    

  ggplot(dat, aes(output.x, output.y, fill = strategy.x)) +
    geom_bar(stat="identity", position = "dodge") +
    scale_fill_brewer(palette = "Set1") +
    ggtitle(paste(e2, "in terms of", e1)) +
    labs(x = e1) + labs(y = e2)

} else {
  invalidDataPdf(outPdf)
}

