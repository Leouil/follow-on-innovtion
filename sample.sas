* This code present sample selection process at pairwise, cited-firm, and citing-firm levels
filename macrodir "/sasmacro";
* SAS macros used are all available at https://github.com/Leouil/SASMacro;
%include macrodir(winsor,lagvar,leadvar,nvarlist,compfilter,filtermissing);
libname comp "/comp";
libname innov "/innovation";

** generate financial control variables using compustat data;
data controls;
    set comp.funda(where=(%compfilter));
%lagvar (varlist = at) ;
ME = csho * prcc_f;
logMKT=log(ME);
Leverage = (dltt + dlc ) /at;    label Leverage="dltt/at + dlc/at for leverage ";
cash=coalesce(che,0)/at;
ROA=ib/l1at;
RD2asset=coalesce(xrd,0)/at;
Capex2asset=coalesce(capx,0)/at;
EB = NI+xrd-coalesce(DVP,0);
BTM = (ceq+coalesce(txdb,0))/csho/prcc_f;
MTB = csho*prcc_f/(ceq+coalesce(txdb,0));
BE=ceq;
Drdpct=(xrd/at-l1xrd/l1at)/(l1xrd/l1at);
RDG=(Drdpct>0.05);
RDME=xrd/ME;
RDBE=xrd/BE;
ADME=xad/ME;
CapxME=capx/ME;
LogRDME=log(1+RDME);
LogADME=log(1+ADME);
LogCapxME=log(1+CapxME);
run;

proc sql;
** earnings volatility;
create table pre5 as 
  select distinct
  	a.gvkey, a.fyear, b.fyear as fyear2, b.roa
  from 
	controls a
  left join
  	controls b
  on
  	a.gvkey=b.gvkey and a.fyear-4<=b.fyear<=a.fyear
;
create table volatility as
  select distinct
  	gvkey, fyear, std(roa) as ROAVol
  from
  	pre5
  group by gvkey, fyear
;
** add earnings volatility;
  create table controls as
  select distinct
  	a.*, b.ROAVol
  from controls a
  left join volatility b
  on a.gvkey=b.gvkey and a.fyear=b.fyear
;
** add future ROA;
create table controls as
  select distinct
    a.*, b.ROA as F1ROA
  from controls a
  left join controls b
  on a.gvkey=b.gvkey and a.fyear=b.fyear-1
;
create table controls as
  select distinct
    a.*, b.ROA as F2ROA
  from controls a
  left join controls b
  on a.gvkey=b.gvkey and a.fyear=b.fyear-2
;
create table controls as
  select distinct
    a.*, b.ROA as F3ROA
  from controls a
  left join controls b
  on a.gvkey=b.gvkey and a.fyear=b.fyear-3
** merge with crsp data using link table;
** add beta and abearn (abnormal earnings);
create table controls as
  select distinct
	a.*, b.lpermno as permno
  from controls as a
  left join crsp.lnk as b
  on a.GVKEY=b.GVKEY and (b.LINKDT <= a.datadate or b.LINKDT = .B) 
  and (a.datadate <= b.LINKENDDT or b.LINKENDDT = .E)
  order by gvkey, permno, datadate
;
create table controls as
  select distinct
  	a.*, b.betav as beta
  from controls as a left join crsp.beta as b
  on a.permno=b.permno and a.fyear=b.year
;
create table controls as
  select distinct
  a.*,(EB*(1-taxrate)-b.b1ret*l1BE)/BE as ABEarn
  from controls a left join home.acti b
  on a.fyear=year(b.caldt)
  ;
quit;

data controls;
  set controls;
  %lagvar(varlist = roa);
  DROA=ROA-l1ROA;
  avgroa=(F1ROA+F2ROA+F3ROA);
run;

******Sample selection;
* I. Pairwise sample; 

*-1) 131,012 firm-year observations from 1999 to 2017 covered by Compustat and CRSP;
data controls;
  set controls;
  if missing(permno)=0;
  *# if cik=. then delete;
  if fyear>=1999 and fyear<=2017;
run;

*#-2) aggregate citation: 629,988 cited-citing firm-pairs (including examiner added) between 1999 and 2017;
*## needed data: allcitations, patcntclassyear, waveperiod
*##  after excluding self-citations, citations when the cited and citing patents share common inventors, citations added by patent examiners, and citations from patents whose age is greater than twenty years.;
/* */
data allcitations;
    set innov.allcitations;
    if self=0;
data allcitations;
    set allcitations;
    if cominvs=0;
data allcitations;
    set allcitations;
    if examiner=0;
data allcitations;
    set allcitations;
    if within20;
run;

*## aggregation to firm-pair and citing application year | add patent variables, techsim, alliance;
*## needed data: citations (from above step), patentstock, techsim, controls, Alliance6817;
/* */
proc sql;
*### group by citingappyear;
create table paircite as
select distinct
  citingpermno, citedpermno, citingappyear,
  sum(within20) as citenum, 
  sum(within20/avgciteclass) as citenumadj
from 
  allcitations
group by 
  citingpermno, citedpermno, citingappyear
;
*### compute total citations in patents applied in a year;
create table paircite as
select distinct a.*, sum(a.citenum) as totcited, sum(a.citenumadj) as totcitedadj,
              sum(a.citenum)-citenum as totothercited, 
              sum(a.citenumadj)-citenumadj as totothercitedadj
from 
  paircite a
group by 
  citedpermno, citingappyear
;
quit;

*### add patent stock data to paircite;
proc sql;
create table paircite as 
select distinct
  a.*, b.patentstock, b.w3, b.bw37
from 
  paircite a 
left join 
 innov.patentstock b
on 
  a.citedpermno=b.permno and a.citingappyear=b.year
;
quit;

*# 794,452 cited-citing firm pairs;

*### add technology similarity - cosine similarity following Jaffe (1986);
proc sql;
create table paircite as
select distinct
  a.*, b.cosinesim as techsim
from
  paircite a
left join
  innov.techsim b
on 
  a.citedpermno=b.permno and a.citingpermno=b.permno2 and a.citingappyear=b.year
;
quit;

*### add gvkey and cusip from compustat and add alliance;
proc sql;
*#### add gvkey and cusip from compustat;
create table paircite as
    select distinct a.*, b.gvkey as citinggvkey, b.cusip as citingcusip
from paircite a
left join controls b
on a.citingpermno=b.permno and a.citingappyear=b.fyear
;
create table paircite as
    select distinct a.*, b.gvkey as citedgvkey, b.cusip as citedcusip
from paircite a
left join controls b
on a.citedpermno=b.permno and a.citingappyear=b.fyear
;
*#### add alliance - data collected from SDC;
create table alliance as 
select distinct
a.citingpermno, a.citedpermno, a.citingappyear, b.Alliance_Date_Announced as Date_Announced, b.Date_Alliance_Terminated as Date_Terminated
from 
  paircite(where=(missing(citedcusip)=0 and missing(citingcusip)=0)) a
left join
  innov.AllianceFromSDC b
on
  (substr(a.citingcusip,1,6)=b.cusip1 or substr(a.citingcusip,1,6)=b.cusip2 or substr(a.citingcusip,1,6)=b.cusip3 or substr(a.citingcusip,1,6)=b.cusip4) 
and
  (substr(a.citedcusip,1,6)=b.cusip1 or substr(a.citedcusip,1,6)=b.cusip2 or substr(a.citedcusip,1,6)=b.cusip3 or substr(a.citedcusip,1,6)=b.cusip4)
order by citinggvkey, citedgvkey, citingappyear, Alliance_Date_Announced
;
quit;

proc sort data=alliance nodupkey;by citingpermno citedpermno citingappyear;run;
proc sort data=paircite nodupkey;by citingpermno citedpermno citingappyear;run;

data alliance;
  set alliance;
  alliance=0;
  if (missing(Date_Announced)=0 and citingappyear>year(Date_Announced)) and (citinggyear<=year(Date_Terminated) or missing(Date_Terminated)) then alliance=1;
   ;
run;

proc sql;
create table paircite as 
select distinct a.*, b.alliance
from
  paircite a 
left join 
  alliance b
on
  a.citingpermno=b.citingpermno and a.citedpermno=b.citedpermno and a.citingappyear=b.citingappyear
;
quit;
*# got 794,452 cited-citing firm pairs;

*#-2) filter firm-pairs not covered by Compustat/CRSP;

data innov.paircite;
  set paircite;
  if missing(citedpermno)=0 and missing(citingpermno)=0;
  if citingappyear>=1999 and citingappyear<=2017;
  logpatentstock = log(1+patentstock);
  logpatentstocksq = log(1+patentstock)**2;
  logcitenumadj=log(citenumadj);
  logtotothercitedadj=log(totothercitedadj);
  logtotothercitedadjsq=log(totothercitedadj)**2;
data innov.paircite_techsim;
  set innov.paircite;
  if missing(citedpermno)=0 and missing(citingpermno)=0;
data innov.paircite;
  set innov.paircite_techsim;
  if missing(techsim) then delete;
run;

*#-3) add transparency and control variables;
proc sql;
*## add transparency to cited firms;
create table paircite as 
select distinct
  a.*,  (b.dqbs+b.dqis)/2 as dq, 
  coalesce(b.rd_disc,0) as rd_disc, coalesce(b.rd_discfls,0) as rd_discfls, coalesce(b.rd_discnum,0) as rd_discnum
from 
  innov.paircite(where=(patentstock>0)) a 
left join
  innov.trans b
on a.citedpermno=b.permno and a.citingappyear=b.fyear
;
*## add controls to both cited and citing firms;
create table paircite2 as 
select distinct
  a.*, b.cusip as citedcusip, b.roa as roa_i, b.logmkt as logmkt_i, b.leverage as leverage_i, 
  b.btm as btm_i, b.cash as cash_i, b.capex2asset as capex_i, 
  b.rd2asset as rd_i, b.ROAVol as incomevol_i, b.beta as beta_i, 
  b.sic as sic_i, b.sic2 as sic2_i, b.zip as zip_i
from 
  paircite a 
left join 
  controls b
on a.citedpermno=b.permno and a.citingappyear=b.fyear
;
create table paircite2 as
select distinct
  a.*, b.cusip as citingcusip, b.roa as roa_j, b.logmkt as logmkt_j, b.leverage as leverage_j, 
  b.btm as btm_j, b.cash as cash_j, b.capex2asset as capex_j, 
  b.rd2asset as rd_j, b.ROAVol as incomevol_j, b.beta as beta_j, 
  b.sic as sic_j, b.sic2 as sic2_j, b.zip as zip_j
from
  paircite2 a
left join
  controls b
on a.citingpermno=b.permno and a.citingappyear=b.fyear
;
quit;

*# filter control variables;
/* */
%let patvars =
  citenumadj logcitenumadj
  techsim patentstock logPatentstock logPatentstocksq w3 bw37
  totothercitedadj logtotothercitedadj logtotothercitedadjsq;
;
%let eqvars =
  logrdisc logrdiscfls logrdiscnum dq;
%let controls =
    ROA_i logMKT_i leverage_i btm_i cash_i Capex_i RD_i incomevol_i beta_i 
	d_ROA d_Size d_leverage d_btm d_cash d_Capex d_RD d_incomevol d_beta
	abd_ROA abd_Size abd_leverage abd_btm abd_cash abd_Capex abd_RD abd_incomevol abd_beta
;

data paircite_sample;
	set paircite2;
if citingappyear<=2017 and citingappyear>=1999;
logrdisc=log(sum(1,rd_disc));
logrdiscfls=log(sum(1,rd_discfls));
logrdiscnum=log(sum(1,rd_discnum));
d_ROA=ROA_j-ROA_i;
d_Size=logMKT_j-logMKT_i;
d_leverage=Leverage_j-Leverage_i;
d_btm=btm_j-btm_i;
d_cash=cash_j-cash_i;
d_Capex=Capex_j-Capex_i;
d_RD=RD_j-RD_i;
d_incomevol=incomevol_j-incomevol_i;
d_beta=beta_j-beta_i;
abd_ROA=abs(ROA_i-ROA_j);
abd_Size=abs(logMKT_i-logMKT_j);
abd_leverage=abs(Leverage_i-Leverage_j);
abd_btm=abs(btm_i-btm_j);
abd_cash=abs(cash_i-cash_j);
abd_Capex=abs(Capex_i-Capex_j);
abd_RD=abs(RD_i-RD_j);
abd_incomevol=abs(incomevol_i-incomevol_j);
abd_beta=abs(beta_i-beta_j);
logrpcov_all=log(1+rpcov_all);
logrpcov_pat=log(1+rpcov_pat);
*#distance between headquarters;
ZipDist=ZIPCITYDISTANCE(zip_i, zip_j);
GeoClose=(ZipDist<=100 and missing(ZipDist)=0);
if missing(techsim1) then techsim1=0;
samesic=(sic_i=sic_j);
samesic2=(sic2_i=sic2_j);
sic2year=sic2_j*citingappyear;
%filtermissing(&patvars &eqvars &controls);
data paircite_sample;
  set paircite_sample;
if (sic_i >= 6000 and sic_i<=6999) or (sic_j >= 6000 and sic_j<=6999) then delete;
run;

*# winsorize to generate sample;
%let winvars = &controls &patvars citenumadj logcitenumadj
              logtotothercitedadj2 logtotothercitedadj2sq
              logtotothercitedadj logtotothercitedadjsq
             ;

%winsor(vars = &winvars, by = none, dsetin = paircite_sample, dsetout = runpair, type = winsor, pctl = 1 99);

data innov.runpair;
    set runpair;
run;

*# II. cited-firm sample selection

*#-1) 131,012 firm-year observations from 1999 to 2017 covered by Compustat and CRSP| drop missing data in controls;
data controls;
  set controls;
  if missing(permno)=0;
  if fyear>=1999 and fyear<=2017;
run;

proc sql;
create table sample as
select distinct
  a.gvkey, a.permno, a.fyear, a.datadate, a.cik, b.cik as cik10k, b.form_type, b.filedate,
  a.roa as roa_i, a.logmkt as logmkt_i, a.leverage as leverage_i,
  a.btm as btm_i, a.cash as cash_i, a.capex2asset as capex_i,
  a.rd2asset as rd_i, a.ROAVol as incomevol_i, a.beta as beta_i,
  a.sic as sic_i, a.sic2 as sic2_i
from controls a left join innov.index10k b
on input(a.cik,10.)=b.cik and a.datadate<=b.filedate<intnx('month',a.datadate,12,'end')
;
quit;

proc sort data=sample nodupkey;
  by permno fyear;
run;

*#-2) filter missing controls and transparency;
proc sql;
*## add transparency;
create table sample as 
select distinct
  a.*, b.rd_disc, b.rd_discfls, b.rd_discnum,
 (b.dqbs+b.dqis)/2 as dq
from 
  sample a 
left join 
  innov.trans b
on a.permno=b.permno and a.fyear=b.fyear
;
*## add patentstock;
create table sample as
select distinct
  a.*, b.patentstock,  b.w3, b.bw37
from
  sample a left join
  innov.patentstock b
on
  a.permno=b.permno and a.fyear=b.year
;
quit;

%let controls=ROA_i logmkt_i logat_i leverage_i btm_i cash_i Capex_i RD_i incomevol_i beta_i;

data sample;
  set sample;
  %filtermissing(&controls);
run;

*#-2) merge with cited-firm level patent variables;
proc sql;
*## total citations;
create table citedfirms as
select distinct
  citedpermno, citingappyear,
  sum(citenum) as citenum,
  sum(citenumadj) as citenumadj
from
  innov.paircite_techsim
group by
  citedpermno, citingappyear
*## add transparency and controls;
create table citedfirms as 
select distinct
  a.*, b.*
from 
  sample a
left join
  citedfirms b
on a.permno=b.citedpermno and a.fyear=b.citingappyear
;
quit;

data citedfirms_clean;
    set citedfirms;
    if citenumadj>0;
run;
proc sort data=citedfirms_clean nodupkey;
  by permno citingappyear;
run;

*#-3) final sample selection;
%let patvars=logcitenum logcitenumadj w3 bw37 logpatentstock logpatentstocksq
            ;
%let eqvars=logrdisc logrdiscfls logrdiscnum dq;
%let controls=ROA_i logmkt_i logat_i leverage_i btm_i cash_i Capex_i RD_i incomevol_i beta_i;

data citedsample;
  set citedfirms_clean;
  if fyear>=1999 and fyear<=2017;
data citedsample;
  set citedsample;
  if 60<=sic2_i<70 then delete;
  logcitenum = log(citenum);
  logcitenumadj = log(citenumadj);
  logpatentstock=log(patentstock);
  logpatentstocksq=logpatentstock**2;
  rd_disc=coalesce(rd_disc,0);
  rd_discfls=coalesce(rd_discfls,0);
  rd_discnum=coalesce(rd_discnum,0);
  logrdisc=log(sum(1,rd_disc));
  logrdiscfls=log(sum(1,rd_discfls));
  logrdiscnum=log(sum(1,rd_discnum));
  sic2year=sic2_i*citingappyear;
  data citedsample;
   set citedsample;
   %filtermissing(logrdisc dq);
  data citedsample;
   set citedsample;
  run;
%let winvars = &patvars &controls &&eqvars;
%winsor(vars = &winvars, by = none, dsetin = citedsample, dsetout = innov.runcited, type = winsor, pctl = 1 99);

*#-III. citing-firm sample selection;

proc sql;
*# starting from paircite, add transparency;
create table paircite as 
select distinct
  a.*, b.earntrans, coalesce(b.rd_disc,0) as rd_disc, coalesce(b.rd_discfls,0) as rd_discfls, coalesce(b.rd_discnum,0) as rd_discnum,
  log(sum(1,rd_disc)) as logrdisc, log(sum(1,rd_discfls)) as logrdiscfls, log(sum(1,rd_discnum)) as logrdiscnum,
  b.dq
from 
  innov.paircite_techsim a,
  innov.trans b
where a.citedpermno=b.permno and a.citingappyear=b.fyear
;*# innov.paircite_all12142021;
create table citingfirms as
select distinct
    citingpermno, citingappyear,
    sum(citenumadj) as totalcitationadj, 
    sum(citenumadj*logrdisc)/sum(citenumadj) as logrdisc_wt,
    sum(citenumadj*logrdiscfls)/sum(citenumadj) as logrdiscfls_wt,
    sum(citenumadj*logrdiscnum)/sum(citenumadj) as logrdiscnum_wt,
    sum(citenumadj*dq)/sum(citenumadj) as dq_wt
from paircite
group by citingpermno, citingappyear
;
*# add control variables;
create table citingfirms as
select distinct
    a.*, (b.l1at+b.at)/2 as avgat, b.ROA, b.ME, b.logMKT,
    b.leverage, b.btm, b.mtb, b.cash, b.RD2asset as RD,
    b.Capex2asset as capex, b.abearn, b.roavol as earnvol,
    b.LOGRDME, b.RDG, b.LOGADME, b.LOGCAPXME,
    b.avgroa, b.sic as sic_j, b.sic2 as sic2_j
from citingfirms a, controls b
where a.citingpermno=b.permno and a.citingappyear=b.fyear
;
quit;

*# add patent control variable;
proc sql;
*# add DAPC and LogPATME following Hirshleifer et al. 2012;
create table citingfirms as
select distinct
    a.*, b.dapc, log(sum(1,b.patcnt/a.ME)) as LogPATME
from citingfirms a left join innov.DAPC b
on a.citingpermno=b.permno and a.citingappyear=b.fyear
;
proc sort data=citingfirms nodupkey;
	by citingpermno citingappyear;
run;

%let vars = logtotciteadj logrdisc
			avgroa logrdme rdg logpatme logadme logcapxme
			logmkt btm abearn earnvol
			ROA Leverage cash RD Capex beta
            logrdisc_wt logrdiscfls_wt logrdiscnum_wt dq_wt;

data citingfirms;
	set citingfirms;
	logtotciteadj=log(totalcitationadj);
	%filtermissing(&vars);
data citingfirms;
	set citingfirms;
	if 60<=sic2_j<70 then delete;
run;

%winsor(vars = &vars, by = none, dsetin = citingfirms, dsetout = runciting, type = winsor, pctl = 1 99);

proc rank data=runciting out=runciting groups=4;
    var apc;
    ranks dapc;
run;

data innov.runciting;
	set runciting;
	totalcite_rdisc_wt=logtotciteadj*logrdisc_wt;
	totalcite_rdiscfls_wt=logtotciteadj*logrdiscfls_wt;
	totalcite_rdiscnum_wt=logtotciteadj*logrdiscnum_wt;
	totalcite_dq_wt=logtotciteadj*dq_wt;
	sic2year=sic2_j*citingappyear;
run;
