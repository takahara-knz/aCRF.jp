/***************************************************
 * SDTMデータからRECIST推移一覧表を作成する        *
 * RECISTと腫瘍マーカーを表示する                  *
 * ※ 後半、ソースコードを修正する箇所があります   *
 * 		   S.Takahara Kanazawa University Hospital *
 ***************************************************/

/*★★★★★★★★★★アドバイス★★★★★★★★★★
  Excel出力した後、オートフィルターで
　標的病変評価、非標的病変評価、総合評価判定
　の各行をそれぞれ違う色にすると見やすいです       */

%let	study	=	テスト試験 (TEST study) ;
%let	sdtm	=	X:\SDTMデータ\ ;
%let	outf	=	X:\RECIST一覧表.xlsx ;
%let	id		=	SUBJID ;			* 表示する被験者ID・・・USUBJIDもしくはSUBJID ;
%let	recist	=	RECIST 1.1 ;		* RECISTデータのRSCAT ;
%let	marker	=	TMARKER ;			* 腫瘍マーカーデータのLBCAT ;
%let	drop	=	DROP ;				* 中止時のVISIT名 ;
%let	last	=	LAST ;				* 最終観察時のVISIT名 ;
/*
 * MACRO
 */
%macro	readds	( domain , select ) ;
	PROC IMPORT OUT	= &domain 
		DATAFILE	= "&sdtm\&domain..csv" 
		DBMS		= CSV	REPLACE ;
		GETNAMES	=  YES ;
		DATAROW		= 2 ;
		GUESSINGROWS= 10000 ; 
	RUN;
	data	&domain ;
		set		&domain ;
			where	&select ;
	run ;
%mend ;
/*
 * DM
 */
%readds		( dm , usubjid ne '' ) ;
/*
 * TU
 */
%readds		( tu , usubjid ne '' ) ;
proc sort	data	=	tu(keep=usubjid tulnkid tuloc -- tuportot) ;
	by	usubjid	tulnkid ;
run ;
/*
 * TR
 */
%readds		( tr , usubjid ne '' ) ;
proc sort	data	=	tr ;
	by	usubjid	trlnkid	visitnum ;
run ;
proc transpose		data	=	tr	out	= tr2 ;
	by		usubjid	trlnkid ;
	id		visit ;
	var		trorres ;
run ;	
/*
 * RS
 */
%readds		( rs2, rscat eq "&RECIST" ) ;
data	rs ;
	set		rs ;
	if	rsorres eq 'Non-CR/Non-PD'	then	rsorres='NCR/NPD' ;	* 幅をくうため ;
run ;
proc sort	data	=	rs	nodup ;
	by	usubjid	rstestcd	visit ;
run ;
proc transpose		data	=	rs	out	= rs2 ;
	by		usubjid	rstestcd ;
	id		visit ;
	var		rsorres ;
run ;	
/*
 * LB・・・Marker
 */
%readds		( lb ,  lbcat eq "&MARKER" ) ;
proc sort	data	=	lb ;
	by	usubjid	lbtestcd	visit ;
run ;
proc transpose		data	=	lb	out	= lb2 ;
	by		usubjid	lbtestcd ;
	id		visit ;
	var		lborres ;
run ;	
/*
 * Merge
 */
data	wk1 ;
	merge	tu(rename=(tulnkid=trlnkid))
			tr2 ;
		by	usubjid	trlnkid ;
	length	wk	$ 100 ;
	wk	=	trim ( tulat ) || ',' || tuportot ;
	if	substr ( wk , 1 , 2 ) eq ' ,'	then
		wk	=	substr ( wk , 3 ) ; 
	if	substr ( wk , length(trim(wk)) , 1 ) eq ','	then
		wk	=	substr ( wk , 1 , length(trim(wk))-1 ) ;
	if wk ne ' '	then	wk	=	' (' || trim ( wk ) || ')' ;
	wk	=	trim ( tuloc ) || wk ;
	drop	tuloc -- tuportot ;
run ;

data	wk2	wk2a(keep=usubjid fup) ;
	length	wk	$ 100 ;
	set		wk1
			lb2(in=l)
			rs2(in=r) ;
	if	l	then	do ;
		wk		=	lbtestcd ;
		trlnkid	=	'Z' ;
	end ;
	if	r	then	do ;
		wk		=	rstestcd ;
		if		rstestcd eq 'NEWLIND'	then	trlnkid	=	'X' ;
		else if	rstestcd eq 'OVRLRESP'	then	trlnkid	=	'Y' ;
		else if	rstestcd eq 'BESTRESP'	then	trlnkid	=	'ZZZ' ;
		else									trlnkid	=	rstestcd ;
	end ;
	if	substr ( trlnkid , 1 , 1 ) eq 'T' then	trlnkid	=	'A' || trlnkid ;
	if	trlnkid ne 'ZZZ'	then	output	wk2 ;
	else							output	wk2a ;
run ;
proc sort	data	=	wk2 ;
	by	usubjid	trlnkid ;
run ; 

data	wk3 ;
	length	l	3.
			c1	$ 20.
			;
	merge	dm(keep=usubjid subjid)
			wk2a(rename=(fup=best))
			wk2
			;
		by	usubjid ;
	retain	l ;
	if	first.usubjid	then	do ;
		l	=	0 ;
		c1	=	&id ;
	end ;
	l	=	l + 1 ;
	if	l eq 2	then	do ;
		c1	=	best ;
	end ;
	if	last.usubjid	then	do ;
		l	=	99 ;
	end ;
	if		trlnkid eq 'ATRG'	then	wk	=	'標的病変評価' ;
	else if	trlnkid eq 'NTRG'	then	wk	=	'非標的病変評価' ;
	else if	trlnkid eq 'X'		then	wk	=	'新病変' ;
	else if	trlnkid eq 'Y'		then	wk	=	'総合評価判定' ;
	if		trlnkid eq 'ATRG'	then	flg	=	1 ;
	drop	best	_name_	lbtestcd	rstestcd ;
	label	c1		=	'症例登録番号*最良効果判定'
			wk		=	'部位／項目'
			&drop	=	'中止時'
			&last	=	'最終観察時'
			;
run ;
proc sort	data	=	wk3 ;
	by	&id	trlnkid ;
run ; 
/*
 * レポート作成・・・WK3をもとに、Visitを指定してください。
 */
title		"&study RECIST推移一覧表" ;
footnote	'&P/&N' ;
ods	excel	file	=	"&outf"
			options ( 
				sheet_name	= 'RECIST推移一覧表'
				orientation	= 'landscape'
				pages_fitwidth	=	'1'	
				pages_fitheight	=	'999'
				row_repeat		=	'1'
			) ;
proc report	data	=	wk3
				split='*'
				style(header)	=	[just=c]
				style(column)	=	[width=100pt]
				box
				;

	column	L DEF	/* trlnkid */	c1	wk	
			screen	cycle_2	cycle_4	cycle_6	cycle_8	cycle_10	cycle_12	cycle_14	&DROP	&LAST ;	* ここ、wk3見ながら表示順にVisit指定 ;

	define	c1		/ style	=	[width=80pt] ;
	define	wk		/ style	=	[width=250pt] ;
	define	L		/ noprint ;
	define	DEF		/ noprint	computed ;

	compute	DEF ;
/* ここ、色分けがうまくいきません。詳しい方教えてください
		if		trlnkid eq 'ATRG'	then
			call	define	( _row_ ,	"style" ,	"style=[backgroundcolor=blue]" ) ;
		else if	trlnkid eq 'NTRG'	then
			call	define	( _row_ ,	"style" ,	"style=[backgroundcolor=green]" ) ;
		else if	trlnkid eq 'Y'	then
			call	define	( _row_ ,	"style" ,	"style=[backgroundcolor=yellow]" ) ;
*/
		if	L.sum eq 99	then
			call	define	( _row_ ,	"style" ,	"style=[borderbottomcolor=black borderbottomwidth=0.1]" ) ;
		else
			call	define	( _row_ ,	"style" ,	"style=[borderbottomcolor=white borderbottomwidth=0.3]" ) ;
	endcomp ;
run ;
ods	excel	close ;
