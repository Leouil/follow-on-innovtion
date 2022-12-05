# This R code provides the main regression models at both pairwise and cited-firm levels for testing H1 and H2
library(lfe)
library(rio)
library(plm)
library(dplyr)
library(ggplot2)

work = "/home/work/"
wd=paste(work,sep='')
outd=paste(work,"table/",sep='')
source(paste(work,'formula.R',sep=''))

#-----------------baseline pairwise level analysis---------------------
# load pairwise sample
runpair=import(paste(work,'runpair.sas7bdat',sep=''))

# regression variable and parameter definition
str_controlsadj = "logtotothercitedadj logtotothercitedadjsq logpatentstock logpatentstocksq w3 bw37 techsim geoclose abd_roa abd_size abd_leverage abd_btm abd_cash abd_capex abd_rd abd_incomevol abd_beta roa_i logmkt_i leverage_i btm_i cash_i capex_i rd_i incomevol_i beta_i"
controlsadj = unlist(strsplit(str_controlsadj,split=" "))
runpair$citingpermnoyear=with(runpair, citingpermno*citingappyear)
fes_pair = c('citingpermnoyear') # citing firm - year fixed effects
clu_pair = c('sic2_j','citingappyear') # standard error cluster by two-digit SIC and year
dvpair=c('logcitenumadj')
eq1=c('logrdisc')
eq2=c('logrdiscfls')
eq3=c('logrdiscnum')
eq4=c('dq')

# test the effect of transparency on follow-on innovation
ivs_eq1 = c(eq1, controlsadj)
ivs_eq2 = c(eq2, controlsadj)
ivs_eq3 = c(eq3, controlsadj)
ivs_eq4 = c(eq4, controlsadj)
m_eq1 = felm(fefm(dvpair,ivs_eq1,fes_pair,clu_pair),runpair)
m_eq2 = felm(fefm(dvpair,ivs_eq2,fes_pair,clu_pair),runpair)
m_eq3 = felm(fefm(dvpair,ivs_eq3,fes_pair,clu_pair),runpair)
m_eq4 = felm(fefm(dvpair,ivs_eq4,fes_pair,clu_pair),runpair)
# show baseline regression 
summ(m_eq1)
summ(m_eq2)
summ(m_eq3)
summ(m_eq4)


#-----------------baseline cited firm level analysis
# load cited firm level sample
runcited=import(paste(work,'runcited.sas7bdat',sep=''))

# variables and parameter definition
str_controls_fm = "logpatentstock logpatentstocksq w3 bw37 roa_i logmkt_i leverage_i btm_i cash_i capex_i rd_i incomevol_i beta_i"
controls_fm = unlist(strsplit(str_controls_fm,split=" "))
fes_fm = c('sic2year') # cited firm's industry - year fixed effects
clu_fm = c('sic2_i')  # standard error cluster by cited firm's two-digit SIC and year
dv = c('logcitenumadj')
eq1=c('logrdisc')
eq2=c('logrdiscfls')
eq3=c('logrdiscnum')
eq4=c('dq')

# test the effect of transparency on follow-on innovation
ivs_eq1_fm = c(eq1, controls_fm)
ivs_eq2_fm = c(eq2, controls_fm)
ivs_eq3_fm = c(eq3, controls_fm)
ivs_eq4_fm = c(eq4, controls_fm)
m_eq1_fm = felm(fefm(dv,ivs_eq1_fm,fes_fm,clu_fm),runcited)
m_eq2_fm = felm(fefm(dv,ivs_eq2_fm,fes_fm,clu_fm),runcited)
m_eq3_fm = felm(fefm(dv,ivs_eq3_fm,fes_fm,clu_fm),runcited)
m_eq4_fm = felm(fefm(dv,ivs_eq4_fm,fes_fm,clu_fm),runcited)

# output cited firm baseline
summ(m_eq1_fm)
summ(m_eq2_fm)
summ(m_eq3_fm)
summ(m_eq4_fm)

