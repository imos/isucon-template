# ISUCON用環境セットアップスクリプト

Docker を用いて本番の環境によらず 1 行のスクリプトで基本的な環境を構築します．

## mysql

```sql
GRANT ALL PRIVILEGES ON *.* TO ninetan@"%" IDENTIFIED BY 'ninetan' WITH GRANT OPTION;
FLUSH PRIVILEGES;
```
