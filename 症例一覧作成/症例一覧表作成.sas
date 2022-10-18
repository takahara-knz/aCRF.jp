/***************************************************
 * SDTMデータから症例一覧表を作成する              *
 * 左から                                          *
 * ・被験者ID/AGE SEX/ACTARM                       *
 * ・MH（合併症、既往歴）                          *
 * ・前治療（薬剤）                                *
 * ・投与開始日/投与終了日/中止決定日/中止理由     *
 * ・生存または死亡日/死亡理由                     *
 * 		   S.Takahara Kanazawa University Hospital *
 ***************************************************/

%let	study	=	テスト試験 (TEST study) ;
%let	sdtm	=	X:\SDTMデータ\ ;
%let	outf	=	X:\症例一覧表.xlsx ;
%let	id		=	SUBJID ;			* 表示する被験者ID・・・USUBJIDもしくはSUBJID ;
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
data	mh ;
	set		mh ;
	length	mhlltx	$ 200 ;
	if	mhstdtc eq ' '	then	mhstdtc	=	'UNK' ;
	if	mhendtc eq ' '	then	mhendtc	=	'UNK' ;
	if	mhenrf eq "&MHONGO"	then
		mhlltx	=	trim ( mhllt ) || ' ' || trim ( left ( mhstdtc ) ) || ' - *' ;
	else
		mhlltx	=	trim ( mhllt ) || ' ' || trim ( left ( mhstdtc ) ) || ' -' || trim ( left ( mhendtc ) ) ;
	keep	usubjid mhlltx ;
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
	length	cmtrtx	$ 200 ;
	if	cmstdtc eq ' '	then	cmstdtc	=	'UNK' ;
	if	cmendtc eq ' '	then	cmendtc	=	'UNK' ;
	cmtrtx	=	trim ( cmtrt ) || ' (' || trim ( cmstdtc ) || '-' || trim ( cmendtc ) || ')' ;
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
			mh
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
		c1	=	&id ;
		dos	=	put ( rfxstdtc , yymmdd10. ) ;
		mht	=	mhlltx ;
		cmt	=	cmtrtx ;
		if	dthfl eq 'Y'	then	dth	=	put	( dthdtc , yymmdd10. ) ;
		else						dth	=	'ALIVE' ;
	end ;
	else do ;
		if	mhlltx eq mht	then	mhlltx	=	' ' ;
		else						mht	=	mhlltx ;
		if	cmtrtx eq cmt	then	cmtrtx	=	' ' ;
		else						cmt	=	cmtrtx ;
		l	=	l + 1 ;
		select	( l ) ;
			when	( 2 )	do ;
				c1	=	put ( age , 2. ) || ' ' || sex ;
				dos	=	put ( rfxendtc , yymmdd10. ) ;
				dth	=	ddorres ;
				end ;
			when	( 3 )	do ;
				c1	=	actarmcd ;
				dos	=	put ( rfendtc , yymmdd10. ) ;
				end ;
			when	( 4 )	do ;
				dos	=	dsterm ;
				end ;
			otherwise		c1	=	' ' ;
		end ;
	end ;
	if	last.usubjid	then	l	=	99 ;
	keep	&id	c1	mhlltx	cmtrtx	dos	dth	l ;
	label	c1		=	'症例番号*年齢 性別*投与群'
			mhlltx	=	'合併症・既往歴'
			cmtrtx	=	'前治療薬'
			dos		=	'投与開始日*投与終了日*中止決定日*中止理由'
			dth		=	'生存または死亡日*死亡理由'
			;
run ;
proc sort	data	=	background2 ;
	by	&id	l ;
run ;
/*
 * Excel出力
 */
title		"&study 症例一覧表" ;
footnote	'&P/&N' ;
ods	excel	file	=	"&outf"
			options ( 
				sheet_name	= '症例一覧表'
				orientation	= 'landscape'
				pages_fitwidth	=	'1'	
				pages_fitheight	=	'999'
				row_repeat		=	'1'
			) ;
proc report	data	=	background2
				split='*'
				style(report)	=	[borderwidth=1.5 bordercolor=black]
				style(header)	=	[just=c borderbottomstyle=double borderbottomcolor=black]
				;

	columns	L c1	mhlltx	cmtrtx	dos	dth DEF	;

	define	c1		/ style	=	[width=60pt just=c] ;
	define	mhlltx	/ style	=	[width=200pt] ;
	define	cmtrtx	/ style	=	[width=300pt] ;
	define	dos		/ style	=	[width=150pt] ;
	define	dth		/ style	=	[width=100pt] ;
	define	L		/ noprint ;
	define	DEF		/ noprint	computed ;

	compute	DEF ;
		if	L.sum eq 99	then
			call	define	( _row_ ,	'style' ,	"style=[borderbottomcolor=black borderbottomwidth=0.1]" ) ;
		else
			call	define	( _row_ ,	'style' ,	"style=[borderbottomcolor=white borderbottomwidth=0.5]" ) ;
	endcomp ;
run ;
ods	excel	close ;
