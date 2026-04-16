# Open OnDemand Resource Discovery Widgets

This repository contains shared helper files for Tufts Open OnDemand Batch
Connect apps:

- `resource_discovery.erb`
- `form.js`

Together, they generate dynamic Slurm resource widgets for interactive apps and
keep dependent form fields synchronized as users change partitions or GPU
architectures.

## Files

### `resource_discovery.erb`

`resource_discovery.erb` is an ERB partial loaded from an app's `form.yml.erb`.
It queries Slurm at form-render time and defines helper methods that generate
Batch Connect form attributes.

It discovers:

- user-accessible Slurm partitions
- partition wall-time limits
- partition CPU and memory caps
- node CPU counts
- node memory
- GPU GRES names
- GPU feature variants such as `a100-80G`, `l40s-48G`, or `h200-141G`
- maximum GPUs per node for each partition and GPU type
- unavailable GPU types where all matching nodes are down or drained

It provides these helper methods:

```erb
<%= generate_partition_field.indent(2) %>
<%= generate_num_cores_field.indent(2) %>
<%= generate_num_memory_field.indent(2) %>
<%= generate_num_hours_field.indent(2) %>
<%= generate_gpu_type_field.indent(2) %>
<%= generate_num_gpus_field.indent(2) %>
```

The generated resource fields are marked `cacheable: false` so users are asked
to choose resources intentionally for each new job. GPU and memory fields are
also marked `display: true` so their submitted values can appear in the Batch
Connect session card details.

### `form.js`

`form.js` adds browser-side dynamic behavior for generated resource widgets.

It can:

- repopulate GPU architecture options when the selected partition changes
- hide GPU-related widgets for CPU-only partitions
- update maximum GPU count by selected partition and GPU type
- update maximum CPU cores by selected partition and GPU type
- update maximum memory by selected partition and GPU type
- update maximum wall time by selected partition
- warn when a selected GPU type is fully unavailable

The JavaScript is generic enough to work with both CPU-only and GPU-capable apps.
If an app does not render a `gpu_type` field, it treats the internal GPU type as
`none` and still updates CPU, memory, and wall-time limits.

## Partition Filters

Set `@partition_filter` in each app's `form.yml.erb` before loading
`resource_discovery.erb`.

Available filters:

- `:cpu`: show only CPU-only partitions.
- `:gpu`: show only partitions that contain GPU nodes.
- `:all`: show all user-accessible partitions.

Examples:

```erb
@partition_filter = :cpu
```

```erb
@partition_filter = :gpu
```

```erb
@partition_filter = :all
```

## App Usage

In an app's `form.yml.erb`, load the shared partial before `cluster:`.

```erb
---
<%
@partition_filter = :all

_partial_path = '/etc/ood/config/apps/dashboard/batch_connect/partials/resource_discovery.erb'
_resource_result = ERB.new(File.read(_partial_path)).result(binding)
%>

cluster: "pax"

bc_dynamic_js: true
```

Then render whichever generated widgets the app needs.

### CPU-Only App

Use this for apps such as RStudio that should only show CPU partitions:

```erb
<%
@partition_filter = :cpu

_partial_path = '/etc/ood/config/apps/dashboard/batch_connect/partials/resource_discovery.erb'
_resource_result = ERB.new(File.read(_partial_path)).result(binding)
%>
```

```erb
attributes:
<%= generate_partition_field.indent(2) %>
<%= generate_num_cores_field.indent(2) %>
<%= generate_num_memory_field.indent(2) %>
<%= generate_num_hours_field.indent(2) %>
```

### GPU-Only App

Use this for apps such as Stable Diffusion that require GPUs:

```erb
<%
@partition_filter = :gpu

_partial_path = File.expand_path('partials/resource_discovery.erb', __dir__)
_resource_result = ERB.new(File.read(_partial_path)).result(binding)
%>
```

```erb
attributes:
<%= generate_partition_field.indent(2) %>
<%= generate_gpu_type_field.indent(2) %>
<%= generate_num_gpus_field.indent(2) %>
<%= generate_num_cores_field.indent(2) %>
<%= generate_num_memory_field.indent(2) %>
<%= generate_num_hours_field.indent(2) %>
```

The GPU-only example above uses a local app copy of `resource_discovery.erb`.
Most apps should use the shared site-level partial instead:

```erb
_partial_path = '/etc/ood/config/apps/dashboard/batch_connect/partials/resource_discovery.erb'
```

### Mixed CPU/GPU App

Use this for apps such as Jupyter that should allow either CPU or GPU
partitions:

```erb
@partition_filter = :all
```

Render both CPU and GPU widgets:

```erb
<%= generate_partition_field.indent(2) %>
<%= generate_num_cores_field.indent(2) %>
<%= generate_num_memory_field.indent(2) %>
<%= generate_gpu_type_field.indent(2) %>
<%= generate_num_gpus_field.indent(2) %>
<%= generate_num_hours_field.indent(2) %>
```

When a CPU-only partition is selected, `form.js` hides the GPU widgets and clears
their submitted values.

## Submit Template Pattern

GPU apps should derive Slurm GRES and constraints from the selected GPU type.
For example:

```text
l40s-48G + 2 GPUs -> --gres=gpu:l40s:2 --constraint=l40s-48G
h200-141G + 4 GPUs -> --gres=gpu:h200:4 --constraint=h200-141G
```

The app's `submit.yml.erb` should treat blank or `none` GPU type as a CPU job,
and a concrete GPU type as a GPU job.

## Requirements

- Open OnDemand Batch Connect
- Slurm
- `sinfo`
- `scontrol`
- Ruby with ERB support
- Browser support for standard JavaScript
