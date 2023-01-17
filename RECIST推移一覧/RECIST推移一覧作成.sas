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
%let	sdtm	=	R:\02.General\61.SAS共通モジュール\CDISC汎用SASプログラム\テストデータ2\ ;
%let	outf	=	\\DM-SERVER2\FRedirect$\takahara\Desktop\RECIST一覧表.xlsx ;
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
%readds		( rs , rscat eq "&RECIST" ) ;
data	rs ;
	set		rs ;
	if	rsorres eq 'Non-CR/Non-PD'	then	rsorres='NCR/NPD' ;
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
data	lb ;
	set		lb ;
	length	t	$ 8 ;
	t	=	left ( put	( lborres , best. ) ) ;
	rename	t	=	lborres ;
	drop	lborres ;
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
	merge	dm(keep=usubjid age sex)
			wk2a(rename=(fup=best))
			wk2
			;
		by	usubjid ;
	retain	l ;
	if	first.usubjid	then	do ;
		l	=	0 ;
		c1	=	usubjid ;
	end ;
	l	=	l + 1 ;
	if	l eq 2	then	do ;
		c1	=	put ( age , best. ) || ' / ' || sex ;
	end ;
	if	l eq 3	then	do ;
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
	drop	best	_name_	lbtestcd	rstestcd	age	sex ;
	label	c1		=	'症例登録番号*年齢・性別*最良効果判定'
			wk		=	'部位／項目'
			&drop	=	'中止時'
			&last	=	'最終観察時'
			;
run ;
proc sort	data	=	wk3 ;
	by	usubjid	trlnkid ;
run ; 
/*
 * レポート作成・・・WK3をもとに、Visitを順に指定してください。
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
**************************************** ここ、wk3を見ながらVisitを表示順に指定 ************************************ ;
	column	l trlnkid 	c1	wk	
			pre	cycle_2	cycle_4	cycle_6	cycle_8	cycle_10	cycle_12	cycle_14	cycle_16	cycle_18	&DROP ;	* ここ、wk3を見ながらVisitを表示順に指定 ;
**************************************************** 指定おわり **************************************************** ;

	define	c1		/ style	=	[width=80pt just=c] ;
	define	wk		/ style	=	[width=250pt] ;
	define	l		/ display	noprint ;
	define	trlnkid	/ noprint ;

	compute	wk ;
		if		trlnkid eq 'ATRG'	then
			call	define	( _row_ ,	"style" ,	"style=[backgroundcolor=lemonchiffon]" ) ;
		else if	trlnkid eq 'NTRG'	then
			call	define	( _row_ ,	"style" ,	"style=[backgroundcolor=lightcyan]" ) ;
		else if	trlnkid eq 'Y'	then
			call	define	( _row_ ,	"style" ,	"style=[backgroundcolor=pink]" ) ;
		else if	trlnkid eq 'Z'	then
			call	define	( _row_ ,	"style" ,	"style=[backgroundcolor=lightgray]" ) ;

		call	define	( 'c1' ,	"style/replace" ,	"style=[backgroundcolor=white]" ) ;

		if	l eq 99	then
			call	define	( _row_ ,	"style/merge" ,	"style=[borderbottomcolor=black borderbottomstyle=double bordertopcolor=white bordertopwidth=5]" ) ;
		else
			call	define	( 'c1' ,	"style/merge" ,	"style=[borderbottomcolor=white borderbottomwidth=5 bordertopcolor=white bordertopwidth=5]" ) ;

	endcomp ;
run ;
ods	excel	close ;
