init

## 变更日志

项目使用根目录的 `CHANGELOG.md` 记录每次变更的任务详情描述，通过 `scripts/changelog.sh` 维护（最新记录在前）：

```bash
# 追加一条变更记录：任务详情、关联任务均可重复传多次，类型缺省为 feat
scripts/changelog.sh add --title "任务标题" --type feat \
  --details "任务详情描述" --ref "#Issue或PR编号"

# 查看最近 5 条记录（不带数字则查看全部）
scripts/changelog.sh show 5
```

发版时将「未发布」小节的内容归档为 `## [版本号]` 小节即可。
