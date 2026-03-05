修复 Bug：$ARGUMENTS
如果 $ARGUMENTS 为空：
  1. 查询 Bug 追踪 filter: Status=Open, Severity 按 Critical>Major>Minor 排序
  2. 取第一条作为目标 Bug
如果 $ARGUMENTS 非空：
  1. 查询 Bug 追踪 filter: Bug Title contains "$ARGUMENTS"
  2. 取匹配结果作为目标 Bug
然后：
3. 读取 Symptom 字段
4. 分析日志，生成 3 个假设按概率排序
5. 定位代码 → 修复 → 编译 → QEMU 验证
6. 回写 Root Cause + Fix + Commit，Status → Fixed
7. 提练预防措施 → 写入踩坑日志
