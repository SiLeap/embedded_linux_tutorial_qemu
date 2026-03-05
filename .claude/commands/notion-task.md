执行 Notion 任务：$ARGUMENTS
如果 $ARGUMENTS 为空：
  1. 查询任务看板 filter: Status=Todo, Priority=P0，按 Due Date 升序
  2. 取第一条作为目标任务
如果 $ARGUMENTS 非空：
  1. 查询任务看板 filter: Task Name contains "$ARGUMENTS"
  2. 取匹配结果作为目标任务
然后：
3. 读取目标任务的 Claude Prompt 字段
4. 在 embedded_linux_tutorial_qemu 仓库中执行开发
5. make modules → QEMU insmod + sysfs 验证
6. MCP 回写 Output + commit hash，Status → Done
7. 如有踩坑 → 写入踩坑日志
