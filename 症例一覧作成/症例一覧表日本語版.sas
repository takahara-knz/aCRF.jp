/***************************************************
 * SDTMデータから症例一覧表(日本語版)を作成する    *
 * 但し、前治療薬の日本語化はしていない            *
 * 左から                                          *
 * ・被験者ID/AGE SEX/ACTARM                       *
 * ・MH（合併症、既往歴）                          *
 * ・前治療（薬剤）                                *
 * ・投与開始日/投与終了日/中止決定日/中止理由     *
 * ・生存または死亡日/死亡理由                     *
 * 		   S.Takahara Kanazawa University Hospital *
 ***************************************************/

%let	study	=	テスト試験 (TEST study) ;
%let	sdtm	=	R:\02.General\61.SAS共通モジュール\CDISC汎用SASプログラム\テストデータ2\ ;
%let	MedDRAf	=	R:\02.General\51.システム関連\21.辞書\MedDRA 22.0\ASCII\MDRA_J220 ;
%let	outf	=	\\DM-SERVER2\FRedirect$\takahara\Desktop\症例一覧表_j.xlsx ;
%let	mhongo	=	ONGOING ;			* MHで継続中（＝併存症）の場合のMHENRF ;
%let	mhpre	=	OTHER ;				* MHで合併症・既往歴の場合のMHCAT ;
%let	cmpre	=	PRIOR ;				* CMで前治療の場合のCMCAT ;

/*
 * マクロ
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
 * MH（既往歴、併存症）
 */
%readds		( mh , mhcat eq "&MHPRE" ) ;
/*
 * MedDRA-JのLLTを読み込み・・・英語版なら不要 ;
 */
PROC IMPORT OUT= WORK.LLT_J 
            DATAFILE= "&MedDRAf\llt_j.asc" 
            DBMS=DLM REPLACE;
     DELIMITER='24'x; 
     GETNAMES=NO;
     DATAROW=1; 
     GUESSINGROWS=max; 
RUN;
/*
 * MedDRA-Jとマージ
 */		
proc sort	data	=	mh ;
	by	mhlltcd ;
run ;

data	mh1 ;
	merge	mh(in=a)
			llt_j(rename=(var1=mhlltcd)) ;
		by	mhlltcd ;
	if	a ;
	length	mhlltx	$ 200
			mhstdtt	mhendtt	$ 4 ;											* 年のみ取得の場合。データに応じて修正 ;
	if	mhstdtc eq .	then	mhstdtt	=	'UNK' ;							* データがテキストになっている場合は適宜修正 ;
	else						mhstdtt	=	put ( mhstdtc , best4. ) ;		* 年月日で取得している場合は必要に応じてフォーマットを修正 ;
	if	mhendtc eq .	then	mhendtt	=	'UNK' ;
	else						mhendtt	=	put ( mhendtc , best4. ) ;		* 年月日で取得している場合は必要に応じてフォーマットを修正 ;
	if	mhenrf eq "&MHONGO"	then
		mhlltx	=	trim ( var2 ) || ' ' || trim ( left ( mhstdtt ) ) || ' - *' ;
	else
		mhlltx	=	trim ( var2 ) || ' ' || trim ( left ( mhstdtt ) ) || ' -' || trim ( left ( mhendtt ) ) ;
	keep	usubjid mhlltx ;
run ;
proc sort	data	=	mh1 ;
	by	usubjid ;
run ;

/*
 * CM（前治療）
 */
%readds		( cm , cmcat eq "&CMPRE" ) ;
proc sort	data	=	cm ;
	by	usubjid	cmrefid ;
run ;
data	cm ;
	set		cm ;
	length	cmtrtx	$ 200
			cmstdtt	cmendtt	$ 10 ;											* データに応じて修正 ;
	if	cmstdtc eq .	then	cmstdtt	=	'UNK' ;							* データがテキストになっている場合は適宜修正 ;
	else						cmstdtt	=	put ( cmstdtc , yymmdd10. ) ;
	if	cmendtc eq .	then	cmendtt	=	'UNK' ;
	else						cmendtt	=	put ( cmendtc , yymmdd10. ) ;
	cmtrtx	=	trim ( cmtrt ) || ' (' || trim ( cmstdtt ) || '-' || trim ( cmendtt ) || ')' ;
	keep	usubjid	cmtrtx ;
run ;
/*
 * 中止・脱落
 */
%readds		( ds , dsterm ne 'COMPLETED' ) ;
/*
 * 死亡
 */
%readds		( dd , ddorres ne '' ) ;
/*
 * データ統合
 */
data	background ;
	merge	dm
			mh1
			cm
			ds(keep=usubjid dsterm)
			dd(keep=usubjid ddorres) ;
		by	usubjid ;
	retain	l ;
	if	first.usubjid	then	l	=	1 ;
	else						l	=	l + 1 ;
	output ;
	if	last.usubjid	then	do ;
		do ix	=	l+1 to 4 ;
			output ;
		end ;
	end ;
	drop	l	ix ;
run ;
data	background2 ;
	length	c1		$ 20
			mhlltx	cmtrtx	mht	cmt	dos	$ 200
			dth		$ 20 ;
	set		background ;
		by	usubjid ;
	retain	l	mht	cmt ;
	if	first.usubjid	then	do ;
		l	=	1 ;
		c1	=	usubjid ;
		dos	=	put ( rfxstdtc , yymmdd10. ) ;
		mht	=	mhlltx ;
		cmt	=	cmtrtx ;
		if	dthfl eq 'Y'	then	dth	=	'死亡 ' || put	( dthdtc , yymmdd10. ) ;
		else						dth	=	'生存' ;
	end ;
	else do ;
		if	mhlltx eq mht	then	mhlltx	=	' ' ;
		else						mht	=	mhlltx ;
		if	cmtrtx eq cmt	then	cmtrtx	=	' ' ;
		else						cmt	=	cmtrtx ;
		l	=	l + 1 ;
		select	( l ) ;
			when	( 2 )	do ;
				c1	=	put ( age , 2. ) || ' / ' || sex ;
				dos	=	put ( rfxendtc , yymmdd10. ) ;
				dth	=	ddorres ;
				end ;
			when	( 3 )	do ;
				c1	=	actarm ;
				dos	=	put ( rfendtc , yymmdd10. ) ;
				end ;
			when	( 4 )	do ;
				dos	=	dsterm ;
				end ;
			otherwise		c1	=	' ' ;
		end ;
	end ;
	if	last.usubjid	then	l	=	99 ;
	keep	usubjid	c1	mhlltx	cmtrtx	dos	dth	l ddorres ;
	label	c1		=	'症例番号#年齢 性別#投与群'
			mhlltx	=	'合併症・既往歴##*：併存'
			cmtrtx	=	'前治療薬'
			dos		=	'投与開始日#投与終了日#中止決定日#中止理由'
			dth		=	'生存または死亡日#死亡理由'
			;
run ;
proc sort	data	=	background2 ;
	by	usubjid	l ;
run ;
/*
 * Excel出力
 */
title		"&study 症例一覧表" ;
footnote	'&P/&N' ;
ods	excel	file	=	"&outf"
			options ( 
				sheet_name	= '症例一覧表日本語版'
				orientation	= 'landscape'
				pages_fitwidth	=	'1'	
				pages_fitheight	=	'999'
				row_repeat		=	'1'
			) ;
proc report	data	=	background2
				split='#'
				style(report)	=	[borderwidth=1.5 bordercolor=black]
				style(header)	=	[just=c borderbottomstyle=double borderbottomcolor=black]
				;

	columns	L c1	mhlltx	cmtrtx	dos	dth	;

	define	c1		/ style	=	[width=60pt just=c] ;
	define	mhlltx	/ style	=	[width=200pt] ;
	define	cmtrtx	/ style	=	[width=300pt] ;
	define	dos		/ style	=	[width=150pt] ;
	define	dth		/ style	=	[width=100pt] ;
	define	l		/ display	noprint ;

	compute	c1 ;
		if	l eq 99	then
			call	define	( _row_ ,	"style/merge" ,	"style=[borderbottomcolor=black borderbottomstyle=double bordertopcolor=white bordertopwidth=5]" ) ;
		else
			call	define	( _row_ ,	"style/merge" ,	"style=[borderbottomcolor=white borderbottomwidth=5 bordertopcolor=white bordertopwidth=5]" ) ;
	endcomp ;
run ;
ods	excel	close ;
