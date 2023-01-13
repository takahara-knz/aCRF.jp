/******************************************************
 * LBドメインから症例毎の臨検値の推移グラフを作成する *
 * 出力したい順の番号が LBGLPIDに入力されている前提   *
 * LBGLPIDがブランクの場合、LBCAT+LBSPEC+LBTEST順     *
 * SDTMフォルダに、VisitList.csvを作成しておく        *
 * 			  S.Takahara Kanazawa University Hospital *
 ******************************************************/

%let	usubjid	=	TEST-0008 ;		* 出力したいUSUBJID ;

/***** 準備 *****
 ① SDTMデータが格納されているフォルダをsdtmに割り当てる
 ② 出力PDFファイルのフォルダをoutfに割り当てる
 ****************/

%let	sdtm	=	R:\02.General\61.SAS共通モジュール\CDISC汎用SASプログラム\テストデータ ;
%let	outf	=	\\DM-SERVER2\FRedirect$\takahara\Desktop ;

ods	pdf	file	=	"&outf\graph_&usubjid..pdf"  ;

options	orientation	=	landscape ;
options	mprint ;

/*
 * Visit関連のFormatを作成する
 */
proc import	out			=	visit_list0
				datafile	=	"&sdtm\visitlist.csv"
				dbms		=	csv
				replace
				;
	getnames		=	yes ;
	datarow			=	2 ;
	guessingrows	=	max ;
run ;
* 等間隔に振りなおすFormat ;
data	visiti(rename=(l=label)) ;
	set		visit_list0 ;
	retain	l	0 ;
	l	=	l + 1 ;
	start	=	visitnum ;
	end		=	visitnum ;
	fmtname	=	'visiti' ;
	type	=	'i' ;
	keep	start	end	l	fmtname	type ;
run ;
proc format	cntlin	=	visiti ;
run ;
* 振りなおした番号にラベルをつけるフォーマット ;
data	visitf ;
	set		visit_list0 ;
	retain	l	0 ;
	l	=	l + 1 ;
	start	=	l ;
	end		=	l ;
	fmtname	=	'visitf' ;
	type	=	'n' ;
	keep	start	end	label	fmtname	type ;
run ;
proc format	cntlin	=	visitf ;
run ;
/*
 * SDTMデータ読み込みMacro
 */
%macro	readds	( domain , select ) ;
	proc import	out			=	&domain.0
				datafile	=	"&sdtm\&domain..csv"
				dbms		=	csv
				replace
				;
			getnames		=	yes ;
			datarow			=	2 ;
			guessingrows	=	max ;
	run ;
	data	&domain.1 ;
		set		&domain.0 ;
			where	&select ;
	run ;
%mend ;

/*
 * SDTMデータ読み込み ;
 */
%readds		( lb , usubjid eq "&usubjid" ) ;

data	lb2 ;
	set		lb1 ;
		where	lbstresn ne . ;				* グラフにするので数値データのみ ;

	itemno		=	input	( lbgrpid ,	best. ) ;	
	visitno		=	input	( visitnum ,	visiti. ) ;		* Visitnumを等間隔に振り直し ;
	keep	usubjid	lbgrpid	lbcat	lbspec	lbtest	lbstresn	lbstresu	lbstnrlo	lbstnrhi	visitno ;
	format	visitno	visitf. ;
run ;

proc sort	data	=	lb2 ;
	by	lbgrpid	lbcat	lbspec	lbtest	lbstresu	visitno ;
run ;

goptions	hby	=	2 cells ;	

symbol1	color		=	black
		value		=	dot
		width		=	8
		interpol	=	join ;
symbol2	color		=	black
		value		=	plus
		line		=	4
		interpol	=	join ;
symbol3	color		=	black
		value		=	plus
		line		=	4
		interpol	=	join ;

axis1	major	=	( number	=	1 )
		minor	=	none ;

title	"*** Laboratory Test RESULT *** USUBJID = &usubjid" ;

proc gplot	data	=	lb2 ;
	by		lbgrpid	lbcat	lbspec	lbtest lbstresu ;
	plot	lbstresn * visitno
			lbstnrlo * visitno
			lbstnrhi * visitno
			/ 	overlay
				haxis	=	axis1 ;
	format	visitno	visitf. ;
	label	lbgrpid	=	'No.'
			lbcat	=	'Cat.'
			lbspec	=	'Spec.'
			lbtest	=	'Test'
			lbstresu	=	'Unit'
			lbstresn	=	'Result'
			visitno	=	'Visit'
			;
run ;

quit ;

ods	pdf	close ;
