# This script loads the allqc.txt file generated in the previous step, applies a machine learning classifier to 
# predict artifacts, and returns the results of which volumes are classified as 'bad' (indicated by a 1). 

# Inputs:
# * allqc.txt

# Outputs:
# * study_summary.csv = CSV file with summary of number of bad vols by ID
# * study_allvolsclassified.csv = CSV file with one row per volume in the DWI scan

#------------------------------------------------------
# set paths and filenames
#------------------------------------------------------
inputDir='/path/to/your/allqc/input' #this is where the allqc.txt file is stored
classifierDir='/path/to/the/classifier' #this is where autoq_classifier.rds is stored (probably where you saved the scripts)
outputDir='/path/to/folder/where/you/want/output' #this is where the outputs of this script are saved


#------------------------------------------------------
# load/install packages
#------------------------------------------------------
osuRepo = 'http://ftp.osuosl.org/pub/cran/'

if (!require(tidyverse)) {
  install.packages('tidyverse', repos = osuRepo)
}


if (!require(caret)) {
  install.packages('caret', repos = osuRepo)
}

if (!require(randomForest)) {
  install.packages('randomForest', repos = osuRepo)
}


#------------------------------------------------------
# load input file
#------------------------------------------------------
message('--------Loading confound file--------')

allqc_data <- read.csv(paste0(inputDir, "/allqc.txt"),header=F,sep="") %>%
  rename(ID=V1, volume=V2)

#------------------------------------------------------
# apply classifier
#------------------------------------------------------
message('--------Applying classifier--------')

# load classifier
mlModel <- readRDS(paste0(classifierDir,'/autoq_classifier.rds'))

# apply model
allqc_data$badvol <- predict(mlModel, newdata=allqc_data)


#------------------------------------------------------
# summarize data and write csv files
#------------------------------------------------------
message(sprintf('--------Writing summaries to %s--------', outputDir))

# summarize 
summary <- allqc_data %>% 
  group_by(ID) %>%
  mutate(badvol=as.numeric(badvol)-1) %>%
  summarise(nvols = sum(badvol, na.rm = T),
            percent = round((sum(badvol, na.rm = T) / n()) * 100, 1))

# print all volumes
all_vols <- allqc_data %>%
  select(ID, volume, badvol)

# create the summary directory if it does not exist
if (!file.exists(outputDir)) {
  message(paste0(outputDir, ' does not exist. Creating it now.'))
  dir.create(outputDir, recursive = TRUE)
}

# write files
write.csv(summary, file.path(outputDir, 'study_summary_autoq.csv'), row.names = FALSE)
write.csv(all_vols, file.path(outputDir, 'study_allvolsclassified_autoq.csv'), row.names = FALSE)
