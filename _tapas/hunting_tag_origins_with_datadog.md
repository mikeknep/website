---
layout: tapas
date: 2021-08-02
title: Hunting Tag Origins with Datadog
---

We created a parameterized dashboard in Datadog and noticed several tag discrepancies,
such as `env` vs. `environment` or `prod` vs. `production`.
AWS does not provide any sane way to query for tags across different services,
as [this Twitter thread laments](https://twitter.com/donkersgood/status/1368908784060497920),
so I looked for ways to perform a sort of "reverse lookup" from Datadog.
The following technique turned out pretty useful:

First, go to Datadog > Metrics > Summary and add a tag you're looking for (e.g. `environment:prod`).
The list of metrics is filtered down to incoming metrics from resources with that tag.
Make note of at least one metric each service; for demo purposes I'll use `aws.s3.bucket_size_bytes`.

Leave Metrics Summary and navigate to Metrics Explorer.
Fill in the following:
```
Graph:
  aws.s3.bucket_size_bytes  # the metric from Metrics Summary

Over:
  environment:prod          # the tag you're searching

One graph per:
  bucketname                # any human-friendly attribute
```

Tada!
Datadog renders graphs to the right with each bucket's name in the title.
