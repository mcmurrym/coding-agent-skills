Suggested fix:
- Replace a full scan with the indexed query path for better correctness/perf.

```suggestion
const rows = await ctx.db
  .query("tasks")
  .withIndex("by_org_status", (q) =>
    q.eq("orgId", args.orgId).eq("status", "active")
  )
  .collect();
```
