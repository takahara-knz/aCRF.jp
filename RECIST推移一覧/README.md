# RECIST一覧を作成するSASプログラム
**※ バリデーションは実施していません。各自の責任でご利用ください**
- 以下のものをExcelに出力します。
  - 症例登録番号と最良効果判定
  - RECISTの標的病変臓器部位、非標的病変の臓器部位、腫瘍マーカーの項目名
  - 各Visitの、標的病変の長径、標的病変の評価、非標的病変の有無、非標的病変の評価、新病変の有無、総合評価判定、腫瘍マーカー（項目問わず）
- LBCATの制約や、VISITNUMのほかVISITが入力されていることなど、いくつか制約があります。
- 試験データに合わせてある程度の修正が必要と思われますので、SASを書ける人向けです。
------
## サンプル
- 無加工・・・上記SASプログラムの出力後、セル幅最適化のみ実施したもの（データ自体はダミーデータに書き換えしています）
- 加工後・・・更に以下の加工を加えたもの
  - オートフィルターで「標的病変評価」を選択し、セル色を緑に
  - オートフィルターで「非標的病変評価」を選択し、セル色を青に
  - オートフィルターで「総合評価判定」を選択し、セル色を桃に
  - オートフィルターで腫瘍マーカーを全て選択し、セル色を灰に
  - A列をセンタリング
  - ヘッダーを縦センタリング
