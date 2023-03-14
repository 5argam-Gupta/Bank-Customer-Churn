libname project '/home/u62282986/CRM_Project';

proc import datafile='/home/u62282986/CRM_Project/Churn_Modelling.csv'
out=project.data
dbms=csv;
run;

/* Encoding dummy variables */
data project.data; set project.data;
if Gender = 'Female' then Gender_dummy = 1; else Gender_dummy = 0;
run;

data project.data; set project.data;
if Geography = 'France' then France = 1; else France = 0;
run;

data project.data; set project.data;
if Geography = 'Spain' then Spain = 1; else Spain = 0;
run;

data project.data; set project.data;
if Geography = 'Germany' then Germany = 1; else Germany = 0;
run;

%let xvar=CreditScore Age Tenure Balance NumOfProducts HasCrCard IsActiveMember EstimatedSalary Gender_dummy France Spain Germany;

/* Descriptive statistics */
proc means data=project.data;
	var &xvar exited;
run;

/* Unsupervised Models */
/* PCA */
proc princomp data=project.data out=project.pca;
var &xvar;

/* PCA with eight components */
proc princomp data=project.data n=8 out=project.pca2;
var &xvar;
run;

/* K-means + PCA */
/* Standardize the dataset */
proc stdize data=project.data out=project.data_std method=std;
	var &xvar;
run;

/* K-means */
proc fastclus data=project.data_std maxclusters=5 drift distance out=project.kmeans;
	var &xvar;
run;

/* Calculate mean of variables in each cluster */
proc sql;
	create table project.data2 as
	select b.*, a.Cluster
	from project.kmeans a , project.data b
	where a.RowNumber = b.RowNumber;
run;
quit;

proc sql;
	select 	cluster, 
			mean(CreditScore) as CreditScore,
			mean(Age) as Age,
			mean(Tenure) as Tenure,
			mean(Balance) as Balance,
			mean(EstimatedSalary) as salary,
			mean(NumOfProducts) as numofprod,
			mean(HasCrCard) as creditcard,
			mean(IsActiveMember) as isactivemember,
			mean(Exited) as exited,
			mean(Gender_dummy) as female,
			mean(France) as france,
			mean(Germany) as germany,
			mean(Spain) as spain
	from project.data2
	group by cluster;
run;
quit;


/* PCA */
proc princomp data=project.kmeans plots(only)=(scree) out=project.kmeans_pca;
	var &xvar;
run;

/* Visualization */
title "K-Means Clustering";
proc sgplot data=project.kmeans_pca;
styleattrs datasymbols=(circlefilled)
 datacontrastcolors=(purple green red orange blue);
	scatter x=Prin1 y=Prin2 / group=CLUSTER;
	xaxis grid;
	yaxis grid;
run;

/* Add a log transformation of EstimatedSalary */
data project.data; set project.data;
ln_EstimatedSalary =log(EstimatedSalary);
run;

/* Supervised model */
/* Randomly split the data into 2 datasets with sampling rate be .80 */
PROC SURVEYSELECT DATA=project.data OUT=project.split METHOD=SRS
SAMPRATE=0.80
OUTALL SEED=12345 NOPRINT;
RUN;

/* Train data */
DATA project.train; SET project.split;
IF SELECTED=1;
RUN;

/* Test data */
DATA project.test; SET project.split;
IF SELECTED=0;
RUN;

/* Run logistic model 1 from train data with all variables and get ROC for both train and test data with model 1 */
PROC LOGISTIC DATA=project.train;
MODEL Exited = CreditScore Tenure Balance NumOfProducts HasCrCard IsActiveMember;
SCORE DATA=project.test OUT=valpred OUTROC=VROC;
ROC; ROCCONTRAST;
Run;

/* Run logistic model 2 from train data with all variables and get ROC for both train and test data with model 2 */
PROC LOGISTIC DATA=project.train;
MODEL Exited = CreditScore Age Tenure Balance NumOfProducts HasCrCard IsActiveMember EstimatedSalary
	female_dummy france_dummy spain_dummy/OUTROC=TROC;
SCORE DATA=project.test OUT=valpred OUTROC=VROC;
ROC; ROCCONTRAST;
Run;

/* Run logistic model 3 from train data with all variables and getROC for both train and test data with model 3 */
PROC LOGISTIC DATA=project.train;
MODEL Exited = CreditScore Age Tenure ln_Balance NumOfProducts HasCrCard IsActiveMember 
	ln_EstimatedSalary female_dummy france_dummy spain_dummy;
SCORE DATA=project.test OUT=valpred OUTROC=VROC;
ROC; ROCCONTRAST;
Run;

