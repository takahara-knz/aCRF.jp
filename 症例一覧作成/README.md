# 症例一覧表を作成するSASプログラム
**※ バリデーションは実施していません。各自の責任でご利用ください**
- DM、MH、CM、DS、DDをもとに、Excelファイルの左から以下の項目を表示します。
  - 被験者ID/AGE SEX/ACTARM 
  - MH（合併症、既往歴）
  - 前治療（薬剤） 
  - 投与開始日/投与終了日/中止決定日/中止理由
  - 生存または死亡日/死亡理由
- MHCATやCMCATなどにある程度の制限があります。試験に合うように修正して使ってください。
- ある程度の加工が必要と思われますので、SASがある程度分かる方向けです。
## 症例一覧表英語版
- 英語版です。ヘッダー等は見本なので、適宜修正して下さい。
## 症例一覧表日本語版
- MHをMedDRA-JのLLTに置き換えています。
- CMは当方は辞書を持っていないため、日本語化されていません
- 中止理由、死亡理由は日本語化されていません
-----
## サンプル
- テストデータにて上記SASプログラムの出力後、セル幅最適化のみ実施したもの
