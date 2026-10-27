# partition_qos.rb - shared partition / Slurm QOS rules for Tufts OOD apps.
#
# Deploy next to resource_discovery.erb:
#   /etc/ood/config/apps/dashboard/batch_connect/partials/partition_qos.rb
#
# Loaded by resource_discovery.erb (form side: which partitions are lab
# partitions, where "Request priority start" applies) and by each app's
# submit.yml.erb (which --qos to submit with):
#
#   load '/etc/ood/config/apps/dashboard/batch_connect/partials/partition_qos.rb'
#   qos = PartitionQos.qos_for(partition, (ta_qos if defined?(ta_qos)))
#
# Rules:
#   preempt                  -> --qos=preempt (always)
#   lab partitions           -> --qos=normal-contrib (always)
#   blackwell                -> no --qos (interactive not allowed)
#   batch, gpu               -> --qos=interactive when "Request priority start"
#                               is checked, otherwise no --qos
#
# Values are returned from methods (not constants) so the file can be re-loaded
# with `load` on every render without "already initialized constant" warnings,
# and edits take effect without restarting the dashboard.
module PartitionQos
  module_function

  # Public (shared) partitions; every other partition is a lab partition.
  def public_partitions
    %w[batch gpu preempt blackwell]
  end

  # Partitions whose jobs always run under a fixed QOS.
  def fixed_qos
    { 'preempt' => 'preempt' }
  end

  # QOS for jobs on lab partitions.
  def lab_qos
    'normal-contrib'
  end

  # Public partitions where --qos=interactive is not allowed.
  def no_interactive_partitions
    %w[preempt blackwell]
  end

  def lab_partition?(partition, public_list = public_partitions)
    !public_list.include?(partition.to_s)
  end

  # Whether "Request priority start" (--qos=interactive) applies to a partition.
  def interactive_allowed?(partition, public_list = public_partitions)
    p = partition.to_s
    !lab_partition?(p, public_list) && !no_interactive_partitions.include?(p)
  end

  # QOS to submit with, or nil to use the partition's default QOS.
  def qos_for(partition, ta_qos = nil, public_list = public_partitions)
    p = partition.to_s
    return fixed_qos[p] if fixed_qos.key?(p)
    return lab_qos if lab_partition?(p, public_list)
    return 'interactive' if ta_qos.to_s == 'interactive' && interactive_allowed?(p, public_list)
    nil
  end
end
