module MiqServer::WorkerManagement::Base::Monitor::Reason
  extend ActiveSupport::Concern

  def worker_set_monitor_reason(pid, reason)
    @workers_lock&.synchronize(:EX) do
      @workers[pid][:monitor_reason] = reason if @workers.key?(pid)
    end
  end

  def worker_get_monitor_reason(pid)
    @workers_lock&.synchronize(:SH) { @workers.fetch_path(pid, :monitor_reason) }
  end
end
