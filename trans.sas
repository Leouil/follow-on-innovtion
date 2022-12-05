* This code compute DQ measures and add R&D disclosure measures averaged over previous three years;
filename macrodir "/sasmacro";
* SAS macros used are all available at https://github.com/Leouil/SASMacro;
%include macrodir(winsor,lagvar,nvarlist,compfilter);
libname comp "/comp";
libname crsp "/crsp";
libname innov "/innovation";

/** DQ easure based on balance sheet**/
%let sub = ACODO ACOX XPP ACDO ACO CHE INVT RECT CB CH IVST INVFG
		INVO INVRM INVWIP RECCO RECD RECTR RECUB TXR ALDO AODO AOX
		DC AOCIDERGL AOCIOTHER AOCIPEN AOCISECGL RECTA CAPS CEQL
		CEQT CSTK RE TSTK CSTKCV ACOMINC REA REAJO REUNA REUNR
		SEQO TSTKC TSTKP DCLO DCS DCVSR DCVSUB DCVT DD DD2 DD3 DD4
		DD5 DFS DLTO DLTP DM DN DS DUDD GDWL INTANO MSA BASTR BAST
		DD1 NP DRC LCOX XACC AP DLC LCO TXP DRLT DPACO DPACT FATB
		FATC FATE FATL FATN FATO PPEGT DVPA PSTKC PSTKL PSTKN
		PSTKR PSTKRV ITCB TXDB
;
%let parent = ACO ACOX ACT CH CHE INVT RECT AO ACOMINC CEQ CSTK RE TSTK
	DLTT INTAN IVAO BAST DLC LCO LCT LO DPACT PPENT PSTK TXDITC
;
%let group = ACT AO CEQ DLTT INTAN IVAO LCT LO PPENT PSTK TXDITC
;
 data sub;
   set comp.funda(where=(%compfilter));
 	if gvkey ne .;
 	keep gvkey fyear &sub;
 run;
 proc transpose data=sub out=remote.sub name=variable prefix=value;
 	by gvkey fyear;
 run;

 data parent;
   set comp.funda(where=(%compfilter));
 	if gvkey ne .;
 	keep gvkey fyear &parent;
 run;
 proc transpose data=parent out=remote.parent name=variable prefix=value;
 	by gvkey fyear;
 run;

 data group;
   set comp.funda(where=(%compfilter));
 	if gvkey ne .;
 	keep gvkey fyear &group;
 run;
 proc transpose data=group out=remote.group name=variable prefix=value;
 	by gvkey fyear;
 run;

Proc sql;
create table dqbs as
select distinct a.gvkey, a.fyear, a.variable as sub,
				b.parent, b.group, a.value1 as subvalue
from remote.sub a, remote.bslink b
where upcase(a.variable)=b.subaccount
*bslink from Chen et al.(2015);
;
create table dqbs as
select distinct a.*, b.value1 as parentvalue
from dqbs a, remote.parent b
where a.gvkey=b.gvkey and a.fyear=b.fyear and a.parent=upcase(b.variable)
;
create table dqbs as
select distinct a.*, b.value1 as groupvalue
from dqbs a, remote.group b
where a.gvkey=b.gvkey and a.fyear=b.fyear and a.group=upcase(b.variable)
;
create table dqbs as
select distinct a.*, b.at, a.groupvalue/b.at as weight
from dqbs a, comp.funda(where=(%compfilter)) b
where a.gvkey=b.gvkey and a.fyear=b.fyear
;
quit;

*screening missing value;
proc sql;
create table dqbs as
select distinct *, sum(subvalue) as aggsubvalue
from dqbs
group by gvkey,fyear,group,parent
;
quit;

data dqbs;
	set dqbs;
	if at~=0;
	* screening;
	miss=0;
	if (missing(parentvalue)=0 or parentvalue~=0)
	and (aggsubvalue~=parentvalue)
	and missing(subvalue)
	then miss=1;
run;

proc sql;
create table dqbs_group as
select distinct gvkey, fyear, group, weight, sum(1-miss)/count(*) as nomiss
from dqbs
group by gvkey, fyear, group
;
create table dqbs as
select distinct gvkey, fyear, sum(ifn(abs(weight)>1,sign(weight),weight)*nomiss)/2 as dqbs 
from dqbs_group
group by gvkey, fyear
;
quit;


/** DQ measure based on income statement **/
%let sub = CIBEGNI CICURR CIDERGL CIOTHER CIPEN CISECGL ESUB FCA
		IDIT INTC IRENT NOPIO AQP DTEP GDWLIP GLP NRTXT RCP
		RDIP RRP SETP SPIOP WDP ITCI TXC TXDFED TXDFO TXDI
		TXDS TXFED TXFO TXO TXS TXW ACCHG DO DONR XI XINTD AM
		COGS DFXA DP STKCPA XAD XLR XPR XRD XRENT XSGA XSTFO
;
%let group = CITOTAL NOPI SPI TXT XIDO XINT XOPR
;
data sub;
  set comp.funda(where=(%compfilter));
	if gvkey ne .;
	keep gvkey fyear &sub;
run;
proc transpose data=sub out=sub2 name=variable prefix=value;
	by gvkey fyear;
run;

data group;
  set comp.funda(where=(%compfilter));
	if gvkey ne .;
	keep gvkey fyear &group;
run;
proc transpose data=group out=group2 name=variable prefix=value;
	by gvkey fyear;
run;

Proc sql;
create table dqis as
select distinct a.gvkey, a.fyear, a.variable as sub,
				b.group, a.value1 as subvalue
from sub2 a, remote.islink b
where upcase(a.variable)=b.subaccount
;
create table dqis as
select distinct a.*, b.value1 as groupvalue
from dqis a, group2 b
where a.gvkey=b.gvkey and a.fyear=b.fyear and a.group=upcase(b.variable)
;
quit;

*screening missing value;
proc sql;
create table dqis as
select distinct *, sum(subvalue) as aggsubvalue
from dqis
group by gvkey,fyear,group
;
quit;

data dqis;
	set dqis;
	* screening;
	miss=0;
	if (missing(groupvalue)=0 or groupvalue~=0)
	and missing(subvalue)
	then miss=1;
	if group="TXT" and aggsubvalue=groupvalue then miss=0;
run;

proc sql;
create table dqis_group as
select distinct gvkey, fyear, group, sum(1-miss)/count(*) as nomiss
from dqis
group by gvkey, fyear, group
;
create table dqis as
select distinct gvkey, fyear, mean(nomiss) as dqis
from dqis_group
group by gvkey, fyear
;
quit;


*# combine with R&D disclosure variables;
*-----------------create previous three-year transparency----------------;
proc sql;
create table allfirmyears as
  select distinct
    a.gvkey, a.fyear, a.datadate, a.cik, b.lpermno as permno
  from comp.funda(where=(%compfilter)) as a
  left join crsp.lnk as b
  on a.GVKEY=b.GVKEY and (b.LINKDT <= a.datadate or b.LINKDT = .B) 
  and (a.datadate <= b.LINKENDDT or b.LINKENDDT = .E)
  order by gvkey, permno, datadate
;
*add dq measures in previous three years;
create table pre3trans as
select distinct
  a.gvkey, a.fyear, b.fyear as fyear2, b.dqbs
from 
  allfirmyears a
left join 
  dqbs b
on
  a.gvkey=b.gvkey and a.fyear-2<=b.fyear<=a.fyear
;
create table pre3trans as
select distinct
  a.*, b.dq_is
from 
  trans a
left join 
  dqis b
on
  a.gvkey=b.gvkey and a.fyear2=b.fyear
;
* add RD disclosure from 10-K;
create table pre3trans as
select distinct
  a.*, b.rd_disc, b.rd_discfls, b.rd_discnum
from 
  trans a
left join 
  innov.RD_disc b
on
  a.cik=b.cik and a.fyear2=b.fyear
;
create table trans as
select distinct
  gvkey, permno, fyear, mean(rd_disc) as rd_disc, mean(rd_discfls) as rd_discfls, mean(rd_discnum) as rd_discnum, 
  mean(dq_bs) as dq_bs, mean(dq_is) as dq_is
from
  pre3trans
group by gvkey, permno, fyear
;
quit;

data innov.trans;
    set trans;
    if missing(permno)=0;
run;
