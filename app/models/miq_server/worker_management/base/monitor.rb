module MiqServer::WorkerManagement::Base::Monitor
  extend ActiveSupport::Concern

  include_concern 'Kill'
  include_concern 'Quiesce'
  include_concern 'Reason'
  include_concern 'Settings'
  include_concern 'Start'
  include_concern 'Status'
  include_concern 'Stop'
  include_concern 'SystemLimits'

  def monitor_workers
    # Clear the my_server cache so we can detect role and possibly other changes faster
    my_server.class.my_server_clear_cache

    sync_from_system
    sync_monitor

    # Sync the workers after sync'ing the child worker settings
    sync_workers

    MiqWorker.status_update_all

    cleanup_failed_workers
    monitor_active_workers

    do_system_limit_exceeded if self.kill_workers_due_to_resources_exhausted?
  end

  def sync_workers
    result = {}
    MiqWorkerType.worker_class_names.each do |class_name|
      begin
        c = class_name.constantize
        raise NameError, "Constant problem: expected: #{class_name}, constantized: #{c.name}" unless c.name == class_name

        result[c.name] = c.sync_workers
        result[c.name][:adds].each { |pid| worker_add(pid) unless pid.nil? }
      rescue => error
        _log.error("Failed to sync_workers for class: #{class_name}")
        _log.log_backtrace(error)
        next
      end
    end
    result
  end

  def sync_from_system
  end

  def monitor_active_workers
  end

  def cleanup_failed_workers
    check_pending_stop
    clean_worker_records
  end

  def clean_worker_records
    worker_deleted = false
    miq_workers.each do |w|
      next unless w.is_stopped?
      _log.info("SQL Record for #{w.format_full_log_msg}, Status: [#{w.status}] is being deleted")
      worker_delete(w.pid)
      w.destroy
      worker_deleted = true
    end

    miq_workers.reload if worker_deleted
  end

  def check_pending_stop
    miq_workers.each do |w|
      next unless w.is_stopped?
      next unless worker_get_monitor_status(w.pid) == :waiting_for_stop
      worker_set_monitor_status(w.pid, nil)
    end
  end

  def do_system_limit_exceeded
    MiqWorkerType.worker_class_names_in_kill_order.each do |class_name|
      workers = class_name.constantize.find_current.to_a
      next if workers.empty?

      w = workers.sort_by { |w| [w.memory_usage || -1, w.id] }.last

      msg = "#{w.format_full_log_msg} is being stopped because system resources exceeded threshold, it will be restarted once memory has freed up"
      _log.warn(msg)

      notification_options = {
        :name             => my_server.name,
        :memory_usage     => my_server.memory_usage.to_i,
        :memory_threshold => my_server.memory_threshold,
        :pid              => my_server.pid
      }

      MiqEvent.raise_evm_event_queue_in_region(w.miq_server, "evm_server_memory_exceeded", :event_details => msg, :type => w.class.name, :full_data => notification_options)
      stop_worker(w, MiqServer::WorkerManagement::MEMORY_EXCEEDED)
      break
    end
  end

  def sync_monitor
    @last_sync ||= Time.now.utc
    sync_interval         = @worker_monitor_settings[:sync_interval] || 30.minutes
    sync_interval_reached = sync_interval.seconds.ago.utc > @last_sync
    roles_changed         = my_server.active_roles_changed?
    resync_needed         = roles_changed || sync_interval_reached

    roles_added, roles_deleted, _roles_unchanged = my_server.role_changes

    if resync_needed
      log_role_changes           if roles_changed
      sync_active_roles          if roles_changed
      set_active_role_flags      if roles_changed

      EvmDatabase.restart_failover_monitor_service if (roles_added | roles_deleted).include?("database_operations")

      reset_queue_messages       if roles_changed

      @last_sync = Time.now.utc
      notify_workers_of_config_change(@last_sync)
    end
  end

  def key_store
    @key_store ||= MiqMemcached.client(:namespace => "server_monitor")
  end

  def notify_workers_of_config_change(last_sync)
    key_store.set("last_config_change", last_sync)
  end
end
