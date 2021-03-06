#! /usr/bin/env Rscript
#
# BSF R script to post-processes Cufflinks output by enriching gene and
# transcript tables with Ensembl annotation downloaded from BioMart utilising
# the cummeRbund package. This script also sets sample-specific symbolic
# links to Tophat output files. Tophat alignment summary files are parsed for
# each sample and the resulting data frame
# (rnaseq_tophat_alignment_summary.tsv), as well as plots of alignment rates per
# sample in PDF (rnaseq_tophat_alignment_summary.pdf) and PNG format
# (rnaseq_tophat_alignment_summary.png) are written into the current working
# directory.
#
#
# Copyright 2013 -2015 Michael K. Schuster
#
# Biomedical Sequencing Facility (BSF), part of the genomics core facility of
# the Research Center for Molecular Medicine (CeMM) of the Austrian Academy of
# Sciences and the Medical University of Vienna (MUW).
#
#
# This file is part of BSF R.
#
# BSF R is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# BSF R is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with BSF R.  If not, see <http://www.gnu.org/licenses/>.

suppressPackageStartupMessages(expr = library(package = "biomaRt"))
suppressPackageStartupMessages(expr = library(package = "ggplot2"))
suppressPackageStartupMessages(expr = library(package = "optparse"))


#' Process Tophat and Cufflinks directories for each sample.
#' Enrich Cufflinks genes.fpkm_tracking and isoforms.fpkm_tracking tables with
#' Ensembl annotation downloaded via BioMart. Create sample-specific symbolic
#' links to Tophat files accepted_hits.bam, accepted_hits.bam.bai, unmapped.bam,
#' align_summary.txt, transcripts.gtf and skipped.gtf.
#'
#' @param summary_frame: Data frame with alignment summary statistics
#' @return: Data frame with alignment summary statistics

process_sample <- function(summary_frame) {
  if (is.null(x = summary_frame)) {
    stop("Missing summary_frame argument")
  }
  
  for (i in 1:nrow(x = summary_frame)) {
    message(paste0("Processing sample ", summary_frame[i, "sample"]))
    
    # Construct sample-specific prefixes for Cufflinks and Tophat directories.
    prefix_cufflinks <-
      paste("rnaseq", "cufflinks", summary_frame[i, "sample"], sep = "_")
    prefix_tophat <-
      paste("rnaseq", "tophat", summary_frame[i, "sample"], sep = "_")
    
    # Read, summarise, merge, write and delete gene (genes.fpkm_tracking) tables.
    
    cufflinks_genes <-
      read.table(
        file = file.path(prefix_cufflinks, "genes.fpkm_tracking"),
        header = TRUE,
        colClasses = c(
          # Use data type "factor" for columns "class_code", "nearest_ref_id", "gene_short_name",
          # "tss_id", "length" and "coverage", which are not populated by Cufflinks for genes.
          "tracking_id" = "character",
          "class_code" = "factor",
          "nearest_ref_id" = "factor",
          "gene_id" = "character",
          "gene_short_name" = "factor",
          "tss_id" = "factor",
          "locus" = "character",
          "length" = "factor",
          "coverage" = "factor",
          "FPKM" = "numeric",
          "FPKM_conf_lo" = "numeric",
          "FPKM_conf_hi" = "numeric",
          "FPKM_status" = "factor"
        )
      )
    
    # Collect aggregate statistics for the FPKM_status field.
    aggregate_frame <-
      as.data.frame(x = table(cufflinks_genes$FPKM_status))
    
    # Assign the aggregate FPKM_status levels (rows) as summary frame columns.
    for (j in 1:nrow(x = aggregate_frame)) {
      summary_frame[i, paste("FPKM_status_gene", aggregate_frame[j, 1], sep = ".")] <-
        aggregate_frame[j, 2]
    }
    rm(aggregate_frame, j)
    
    file_path <-
      file.path(prefix_cufflinks,
                paste(prefix_cufflinks, "genes_fpkm_tracking.tsv", sep = "_"))
    if (!(file.exists(file_path) &&
          (file.info(file_path)$size > 0))) {
      cufflinks_ensembl <-
        merge(
          x = ensembl_genes,
          y = cufflinks_genes,
          by.x = "ensembl_gene_id",
          by.y = "tracking_id",
          all.y = TRUE,
          sort = TRUE
        )
      write.table(
        x = cufflinks_ensembl,
        file = file_path,
        col.names = TRUE,
        row.names = FALSE,
        sep = "\t"
      )
      rm(cufflinks_ensembl)
    }
    rm(cufflinks_genes, file_path)
    
    # Read, summarize, merge, write and delete transcript (isoforms.fpkm_tracking) tables.
    
    cufflinks_transcripts <-
      read.table(
        file = file.path(prefix_cufflinks, "isoforms.fpkm_tracking"),
        header = TRUE,
        colClasses = c(
          # Use data type "factor" for columns "class_code", "nearest_ref_id", "gene_short_name",
          # and "tss_id", which are not populated by Cufflinks for isoforms.
          "tracking_id" = "character",
          "class_code" = "factor",
          "nearest_ref_id" = "factor",
          "gene_id" = "character",
          "gene_short_name" = "factor",
          "tss_id" = "factor",
          "locus" = "character",
          "length" = "integer",
          "coverage" = "numeric",
          "FPKM" = "numeric",
          "FPKM_conf_lo" = "numeric",
          "FPKM_conf_hi" = "numeric",
          "FPKM_status" = "factor"
        )
      )
    
    # Collect aggregate statistics for the FPKM_status field.
    aggregate_frame <-
      as.data.frame(x = table(cufflinks_transcripts$FPKM_status))
    
    # Assign the aggregate FPKM_status levels (rows) as summary frame columns.
    for (j in 1:nrow(x = aggregate_frame)) {
      summary_frame[i, paste("FPKM_status_isoforms", aggregate_frame[j, 1], sep = ".")] <-
        aggregate_frame[j, 2]
    }
    rm(aggregate_frame, j)
    
    file_path <-
      file.path(
        prefix_cufflinks,
        paste(prefix_cufflinks, "isoforms_fpkm_tracking.tsv", sep = "_")
      )
    if (!(file.exists(file_path) &&
          (file.info(file_path)$size > 0))) {
      cufflinks_ensembl <-
        merge(
          x = ensembl_transcripts,
          y = cufflinks_transcripts,
          by.x = "ensembl_transcript_id",
          by.y = "tracking_id",
          all.y = TRUE,
          sort = TRUE
        )
      write.table(
        x = cufflinks_ensembl,
        file = file_path,
        col.names = TRUE,
        row.names = FALSE,
        sep = "\t"
      )
      rm(cufflinks_ensembl)
    }
    rm(cufflinks_transcripts, file_path)
    
    # Finally, create sample-specific symbolic links to Tophat files.
    
    file_path <- file.path("..", prefix_tophat, "accepted_hits.bam")
    link_path <-
      file.path(prefix_cufflinks,
                paste(prefix_tophat, "accepted_hits.bam", sep = "_"))
    if (!file.exists(link_path)) {
      if (!file.symlink(from = file_path, to = link_path)) {
        warning("Encountered an error linking the accepted_hits.bam file.")
      }
    }
    rm(file_path, link_path)
    
    file_path <-
      file.path("..", prefix_tophat, "accepted_hits.bam.bai")
    link_path <-
      file.path(prefix_cufflinks,
                paste(prefix_tophat, "accepted_hits.bam.bai", sep = "_"))
    if (!file.exists(link_path)) {
      if (!file.symlink(from = file_path, to = link_path)) {
        warning("Encountered an error linking the accepted_hits.bam.bai file.")
      }
    }
    rm(file_path, link_path)
    
    file_path <- file.path("..", prefix_tophat, "unmapped.bam")
    link_path <-
      file.path(prefix_cufflinks,
                paste(prefix_tophat, "unmapped.bam", sep = "_"))
    if (!file.exists(link_path)) {
      if (!file.symlink(from = file_path, to = link_path)) {
        warning("Encountered an error linking the unmapped.bam file.")
      }
    }
    rm(file_path, link_path)
    
    file_path <- file.path("..", prefix_tophat, "align_summary.txt")
    link_path <-
      file.path(prefix_cufflinks,
                paste(prefix_tophat, "align_summary.txt", sep = "_"))
    if (!file.exists(link_path)) {
      if (!file.symlink(from = file_path, to = link_path)) {
        warning("Encountered an error linking the align_summary.txt file.")
      }
    }
    rm(file_path, link_path)
    
    file_path <- "transcripts.gtf"
    link_path <-
      file.path(prefix_cufflinks,
                paste(prefix_cufflinks, "transcripts.gtf", sep = "_"))
    if (!file.exists(link_path)) {
      if (!file.symlink(from = file_path, to = link_path)) {
        warning("Encountered an error linking the transcripts.gtf file.")
      }
    }
    rm(file_path, link_path)
    
    file_path <- "skipped.gtf"
    link_path <-
      file.path(prefix_cufflinks,
                paste(prefix_cufflinks, "skipped.gtf", sep = "_"))
    if (!file.exists(link_path)) {
      if (!file.symlink(from = file_path, to = link_path)) {
        warning("Encountered an error linking the skipped.gtf file.")
      }
    }
    rm(file_path, link_path)
    
    rm(prefix_cufflinks, prefix_tophat)
  }
  
  return(summary_frame)
}


#' Parse Tophat alignment summary (align_summary.txt) files and return a data
#' frame.
#'
#' @param summary_frame: Data frame with alignment summary statistics
#' @return: Data frame with alignment summary statistics

process_align_summary <- function(summary_frame) {
  if (is.null(x = summary_frame)) {
    stop("Missing summary_frame argument")
  }
  
  # Initialise further columns in the data frame.
  frame_length <- nrow(x = summary_frame)
  # R integer vector of the number of input reads.
  summary_frame$input = integer(length = frame_length)
  # R integer vector of the number of mapped reads.
  summary_frame$mapped = integer(length = frame_length)
  # R integer vector of the number of multiply mapped reads.
  summary_frame$multiple = integer(length = frame_length)
  # R integer vector of the number of multiply mapped reads above the threshold.
  summary_frame$above = integer(length = frame_length)
  # R integer vector of the mapping threshold.
  summary_frame$threshold = integer(length = frame_length)
  rm(frame_length)
  
  for (i in 1:nrow(x = summary_frame)) {
    prefix_tophat <-
      paste("rnaseq", "tophat", summary_frame[i, "sample"], sep = "_")
    file_path <- file.path(prefix_tophat, "align_summary.txt")
    
    if (!file.exists(file_path)) {
      warning(paste0("Missing Tophat alignment summary file ", file_path))
      rm(prefix_tophat, file_path)
      next
    }
    
    align_summary <- readLines(con = file_path)
    
    # This is the layout of a Tophat align_summary.txt file.
    #
    #   [1] "Reads:"
    #   [2] "          Input     :  21791622"
    #   [3] "           Mapped   :  21518402 (98.7% of input)"
    #   [4] "            of these:   2010462 ( 9.3%) have multiple alignments (8356 have >20)"
    #   [5] "98.7% overall read mapping rate."
    
    # Parse the second line of "input" reads.
    summary_frame[i, "input"] <- as.integer(
      x = sub(
        pattern = "[[:space:]]+Input[[:space:]]+:[[:space:]]+([[:digit:]]+)",
        replacement = "\\1",
        x = align_summary[2]
      )
    )
    
    # Parse the third line of "mapped" reads.
    summary_frame[i, "mapped"] <- as.integer(
      x = sub(
        pattern = "[[:space:]]+Mapped[[:space:]]+:[[:space:]]+([[:digit:]]+) .*",
        replacement = "\\1",
        x = align_summary[3]
      )
    )
    
    # Get the number of "multiply" aligned reads from the fourth line.
    summary_frame[i, "multiple"] <- as.integer(
      x = sub(
        pattern = ".+:[[:space:]]+([[:digit:]]+) .*",
        replacement = "\\1",
        x = align_summary[4]
      )
    )
    
    # Get the number of multiply aligned reads "above" the multiple alignment threshold.
    summary_frame[i, "above"] <- as.integer(
      x = sub(
        pattern = ".+alignments \\(([[:digit:]]+) have.+",
        replacement = "\\1",
        x = align_summary[4]
      )
    )
    
    # Get the multiple alignment "threshold".
    summary_frame[i, "threshold"] <- as.integer(x = sub(
      pattern = ".+ >([[:digit:]]+)\\)",
      replacement = "\\1",
      x = align_summary[4]
    ))
    
    rm(align_summary, prefix_tophat)
  }
  rm(i)
  
  return(summary_frame)
}


# Get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults.

argument_list <- parse_args(object = OptionParser(
  option_list = list(
    make_option(
      opt_str = c("--verbose", "-v"),
      action = "store_true",
      default = TRUE,
      help = "Print extra output [default]",
      type = "logical"
    ),
    make_option(
      opt_str = c("--quiet", "-q"),
      action = "store_false",
      default = FALSE,
      dest = "verbose",
      help = "Print little output",
      type = "logical"
    ),
    make_option(
      opt_str = c("--biomart-instance"),
      default = "ENSEMBL_MART_ENSEMBL",
      dest = "biomart_instance",
      help = "BioMart instance",
      type = "character"
    ),
    make_option(
      opt_str = c("--biomart-data-set"),
      dest = "biomart_data_set",
      help = "BioMart data set",
      type = "character"
    ),
    make_option(
      opt_str = c("--biomart-host"),
      dest = "biomart_host",
      default = "www.ensembl.org",
      help = "BioMart host",
      type = "character"
    ),
    make_option(
      opt_str = c("--biomart-port"),
      default = 80,
      dest = "biomart_port",
      help = "BioMart port",
      type = "integer"
    ),
    make_option(
      opt_str = c("--biomart-path"),
      dest = "biomart_path",
      help = "BioMart path",
      type = "character"
    ),
    make_option(
      opt_str = c("--plot-width"),
      default = 7,
      dest = "plot_width",
      help = "Plot width in inches",
      type = "numeric"
    ),
    make_option(
      opt_str = c("--plot-height"),
      default = 7,
      dest = "plot_height",
      help = "Plot height in inches",
      type = "numeric"
    )
  )
))

if (is.null(x = argument_list$biomart_data_set)) {
  stop("Missing --biomart-data-set option")
}

# Connect to the Ensembl BioMart.

ensembl_mart <- useMart(
  biomart = argument_list$biomart_instance,
  dataset = argument_list$biomart_data_set,
  host = argument_list$biomart_host,
  port = argument_list$biomart_port
)

message("Loading attribute data from BioMart")

ensembl_attributes <- listAttributes(
  mart = ensembl_mart,
  page = "feature_page",
  what = c("name", "description", "page")
)

# Get Ensembl Gene information. From Ensembl version e75, the attributes
# "external_gene_id" and "external_gene_db" are called "external_gene_name" and
# "external_gene_source", respectively.

if (any(ensembl_attributes$name == "external_gene_id")) {
  # Pre e75.
  ensembl_gene_attributes <- c("ensembl_gene_id",
                               "external_gene_id",
                               "external_gene_db",
                               "gene_biotype")
} else if (any(ensembl_attributes$name == "external_gene_name")) {
  # Post e75.
  ensembl_gene_attributes <- c("ensembl_gene_id",
                               "external_gene_name",
                               "external_gene_db",
                               "gene_biotype")
} else {
  stop(
    "Neither external_gene_id nor external_gene_name are available as BioMart attributes."
  )
}

message("Loading gene data from BioMart")

ensembl_genes <-
  getBM(attributes = ensembl_gene_attributes, mart = ensembl_mart)
rm(ensembl_gene_attributes)

# Get Ensembl Transcript information.

if (any(ensembl_attributes$name == "external_gene_id")) {
  # Pre e75.
  ensembl_transcript_attributes <- c(
    "ensembl_transcript_id",
    "external_transcript_id",
    "transcript_db_name",
    "transcript_biotype",
    "ensembl_gene_id",
    "external_gene_id",
    "external_gene_db",
    "gene_biotype"
  )
} else if (any(ensembl_attributes$name == "external_gene_name")) {
  # Post e75.
  ensembl_transcript_attributes <- c(
    "ensembl_transcript_id",
    "external_transcript_name",
    "transcript_db_name",
    "transcript_biotype",
    "ensembl_gene_id",
    "external_gene_name",
    "external_gene_db",
    "gene_biotype"
  )
} else {
  stop(
    "Neither external_gene_id nor external_gene_name are available as BioMart attributes."
  )
}

message("Loading transcript data from BioMart")
ensembl_transcripts <-
  getBM(attributes = ensembl_transcript_attributes, mart = ensembl_mart)
rm(ensembl_transcript_attributes)

# Destroy and thus discconnect the Ensembl BioMart connection already here.

rm(ensembl_mart)

# Process all "rnaseq_cufflinks_*" directories in the current working directory.
# Initialise a data frame with row names of all "rnaseq_cufflinks_*" directories
# via their common prefix and parse the sample name simply by removing the prefix.

summary_frame <- data.frame(
  row.names = sub(
    pattern = "^rnaseq_cufflinks_",
    replacement = "",
    x = grep(
      pattern = '^rnaseq_cufflinks_',
      x = list.dirs(full.names = FALSE, recursive = FALSE),
      value = TRUE
    )
  ),
  stringsAsFactors = FALSE
)

# Set the sample also explictly as a data.frame column, required for plotting.

summary_frame$sample <- row.names(x = summary_frame)
summary_frame <-
  process_align_summary(summary_frame = summary_frame)
summary_frame <- process_sample(summary_frame = summary_frame)

# Write the alignment summary frame to disk and create plots.

file_path <- "rnaseq_tophat_alignment_summary.tsv"
write.table(
  x = summary_frame,
  file = file_path,
  col.names = TRUE,
  row.names = FALSE,
  sep = "\t"
)
rm(file_path)

# Alignment summary plot.
ggplot_object <- ggplot(data = summary_frame)
ggplot_object <- ggplot_object + ggtitle(label = "TopHat Alignment Summary")
ggplot_object <-
  ggplot_object + geom_point(mapping = aes(
    x = mapped,
    y = mapped / input,
    colour = sample
  ))
# Reduce the label font size and the legend key size and allow a maximum of 24
# guide legend rows.
ggplot_object <-
  ggplot_object + guides(colour = guide_legend(
    keywidth = rel(x = 0.8),
    keyheight = rel(x = 0.8),
    nrow = 24
  ))
ggplot_object <-
  ggplot_object + theme(legend.text = element_text(size = rel(x = 0.7)))
# Scale the plot width with the number of samples, by adding a quarter of
# the original width for each 24 samples.
plot_width <-
  argument_list$plot_width + (ceiling(x = nrow(x = summary_frame) / 24) - 1) * argument_list$plot_width * 0.25
ggsave(
  filename = "rnaseq_tophat_alignment_summary.png",
  plot = ggplot_object,
  width = plot_width,
  height = argument_list$plot_height
)
ggsave(
  filename = "rnaseq_tophat_alignment_summary.pdf",
  plot = ggplot_object,
  width = plot_width,
  height = argument_list$plot_height
)
rm(ggplot_object, plot_width, summary_frame)

rm(
  ensembl_attributes,
  ensembl_transcripts,
  ensembl_genes,
  argument_list,
  process_sample,
  process_align_summary
)

message("All done")

# Finally, print all objects that have not been removed from the environment.
if (length(x = ls())) {
  print(x = ls())
}
