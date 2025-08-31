#this script provides code for training and testing the 4 models (in various variations)

library(caret)
library(tidyverse)
library(randomForest)
library(kernlab)
library(gbm)
library(LogicReg)
set.seed(8008)

all_autoq = readRDS("all_autoq.rds") 

#split to training and test balanced by outcome (80/20%)
trainIndex <- createDataPartition(all_autoq$rating, p = .8, list = FALSE, times = 1)
trainingdata <- all_autoq[ trainIndex,]
testdata  <- all_autoq[-trainIndex,]

#create 10 cross-validation folds
folds_balance <- createFolds(trainingdata$rating, k=10) #balanced by outcome var
#train control
train_contr <- trainControl(method="cv",index=folds_balance)
train_contr_smote <- train_contr
train_contr_smote$sampling <- "smote"


message('--------Training logreg-------')

#train logistic regression model
weights <- ifelse(trainingdata$rating == 0,
                  (1/table(trainingdata$rating)[1]) * 0.5,
                  (1/table(trainingdata$rating)[2]) * 0.5)
grid_log <- expand.grid(lambda = c(0.1, 1, 10), cp='bic') 

train_log <- train(
  rating ~ ., #formulae
  data = trainingdata[,4:22], #data without id and volume and study fields
  preProcess = c("center", "scale"),
  method = "plr", # penaliz logistic regression #params lambda, cp #alternat (LogitBoost for boosted logistic regression)
  weights=weights,
  tuneGrid=grid_log,
  trControl = train_contr) # train control from previous step.

train_log_smote <- train(
  rating ~ ., 
  data = trainingdata[,4:22], 
  preProcess = c("center", "scale"),
  method = "plr", 
 # weights=weights,
  tuneGrid=grid_log,
  trControl = train_contr_smote) # with upsampling of minority class


message('--------Training GBM--------')

#train gradient boosting model
gb_weights <- ifelse(trainingdata$rating == 0,
                        (1/table(trainingdata$rating)[1]) * 0.5,
                        (1/table(trainingdata$rating)[2]) * 0.5)
grid_gb <- expand.grid(n.trees = c(150, 200, 250), interaction.depth=c(3,4,5),shrinkage=0.1,n.minobsinnode = 10) 
train_gb <- train(
  rating ~ ., 
  data = trainingdata[,4:22], 
  preProcess = c("center", "scale"),
  method = "gbm", # gradient boosting #params n.trees, interaction.depth, shrinkage, n.minobsinnode
  weights=gb_weights,
  tuneGrid=grid_gb,
  trControl = train_contr) 

train_gb_smote <- train(
  rating ~ ., 
  data = trainingdata[,4:22], 
  preProcess = c("center", "scale"),
  method = "gbm", # gradient boosting #params n.trees, interaction.depth, shrinkage, n.minobsinnode
  #weights=gb_weights,
  tuneGrid=grid_gb,
  trControl = train_contr_smote) #with upsampling


message('--------Training SVM--------')

#train support vector machines model
# using RBF kernel (allow more complexity than linear) and class weights (because outcome=0 is more common than outcome=1)
train_contr_svm <- trainControl(method="cv",index=folds_balance, search = "random")
train_svm <- train(
  rating ~ ., 
  data = trainingdata[,4:22],
  preProcess = c("center", "scale"),
  method = "svmRadialWeights", # radial basis function kernel and weights # params sigma, C, Weight
  trControl = train_contr_svm,
  tuneLength = 16) 

grid_with_weight <- expand.grid(sigma=0.12 , C = c(1, 5, 10), Weight = 0.02) 
train_svm_weights <- train(
  rating ~ ., 
  data = trainingdata[,4:22],
  preProcess = c("center", "scale"),
  method = "svmRadialWeights", # radial basis function kernel and weights # params sigma, C, Weight
  trControl = train_contr,
  tuneGrid = grid_with_weight) 


message('--------Training RF--------')

#train random forest model 
train_contr_rf <- trainControl(method="cv",index=folds_balance, classProbs = F)
train_rf <- train(
  rating ~ ., #formulae
  data = trainingdata[,4:22], 
  preProcess = c("center", "scale"),
  method = "rf", # random forest model #params mtry
  trControl = train_contr_rf) 

#train random forest model SMOTE
train_contr_rfsmote <- trainControl(method="cv",index=folds_balance, classProbs = F, sampling="smote")
train_rf_smote <- train(
  rating ~ ., #formulae
  data = trainingdata[,4:22], 
  preProcess = c("center", "scale"),
  method = "rf", # random forest model #params mtry
  trControl = train_contr_rfsmote) 


##### TESTING ##########

# test the logreg model 
test_results_log <- testdata %>% select(rating)
test_results_log$predicted_rating <- predict(train_log, newdata=testdata)
probability_rating_log <- predict(train_log, newdata=testdata, type="prob")
test_results_log <- cbind(test_results_log,probability_rating_log)
names(test_results_log) <- c("rating","predicted_rating","prob0","prob1")
test_results_log$predicted_rating70 <- as.factor(ifelse(test_results_log$prob1>0.699999,1,0))
#plot_log<-ggplot(test_results_log, aes(x = prob1)) + 
#  geom_histogram(binwidth = .05) +   facet_wrap(~rating) +   xlab("Probability of 'bad' rating")
stats_log<-confusionMatrix(data = test_results_log$predicted_rating, reference = test_results_log$rating)

# test the GB model 
test_results_gb <- testdata %>% select(rating)
test_results_gb$predicted_rating <- predict(train_gb, newdata=testdata)
probability_rating_gb <- predict(train_gb, newdata=testdata, type="prob") 
test_results_gb <- cbind(test_results_gb,probability_rating_gb)
names(test_results_gb) <- c("rating","predicted_rating","prob0","prob1")
plot_gbm<-ggplot(data=test_results_gb, aes(x = prob1)) + 
  geom_histogram(binwidth = .05) + 
  facet_wrap(~rating) + 
  xlab("Probability of 'bad' rating")
stats_gbm<-confusionMatrix(data = test_results_gb$predicted_rating, reference = test_results_gb$rating)

# test the  SVM model 
test_results_svm <- testdata %>% select(rating)
test_results_svm$predicted_rating <- predict(train_svm, newdata=testdata)
probability_rating_svm <- predict(train_svm, newdata=testdata, type="prob")
test_results_svm <- cbind(test_results_svm,probability_rating_svm)
names(test_results_svm) <- c("rating","predicted_rating","prob0","prob1")
stats_svm<-confusionMatrix(data = test_results_svm$predicted_rating, reference = test_results_svm$rating)

# test the RF model
test_results_rf <- testdata %>% select(rating)
test_results_rf$predicted_rating <- predict(train_rf, newdata=testdata)
probability_rating_rf <- predict(train_rf, newdata=testdata, type="prob")
test_results_rf <- cbind(test_results_rf,probability_rating_rf)
names(test_results_rf) <- c("rating","predicted_rating","prob0","prob1")
stats_rf<-confusionMatrix(data = test_results_rf$predicted_rating, reference = test_results_rf$rating)
# test the RF model SMOTE
test_results_rf <- testdata %>% select(rating)
test_results_rf$predicted_rating <- predict(train_rf_smote, newdata=testdata)
probability_rating_rf <- predict(train_rf_smote, newdata=testdata, type="prob")
test_results_rf <- cbind(test_results_rf,probability_rating_rf)
names(test_results_rf) <- c("rating","predicted_rating","prob0","prob1")
test_results_rf$predicted_rating_motion <- as.factor(ifelse(testdata$V4>1,1,0)) 
test_results_rf$predicted_rating_outliers <- as.factor(ifelse(testdata$V19>8,1,0))
stats_rf<-confusionMatrix(data = test_results_rf$predicted_rating, reference = test_results_rf$rating)
confusionMatrix(data = test_results_rf$predicted_rating_motion, reference = test_results_rf$rating)
confusionMatrix(data = test_results_rf$predicted_rating_outliers, reference = test_results_rf$rating)
