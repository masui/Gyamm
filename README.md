## Gyamm: メールをWebページとして保存

  - xxx@gyamm.com にメールを送ると http://Gyamm.com/xxx でアクセスできる
  - [http://Gyamm.com]() で運用中

### ソースの状況

- [qwikのソース](https://github.com/eto/qwik)を流用している
  - そのまま使えればいいのだが "require 'quik/mail'" と書いてあるのでそのままでは使えない。
  - QuickMLとかQwikとかいうモジュール名も変更
  - これらを全部消したフラットな感じで使う
- というわけで流用ソースが沢山含まれている。ライセンスはシラネ

### Gyammメールサーバの再起動

 - sudo kill -9 (gyamm-server)
 - sudo ruby bin/gyamm-server

### Gyamm Webの再起動
 - sudo apachectl restart

