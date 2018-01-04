@dir = File.expand_path(File.dirname(__FILE__))
#listen File.join(@dir, "../unicorn.sock"), :backlog => 1024

worker_processes ENV.fetch('WORKER_PROCESSES', 3).to_i
timeout 1000

preload_app true

GC.respond_to?(:copy_on_write_friendly=) and  GC.copy_on_write_friendly = true

before_fork do |server, worker|
  defined?(ActiveRecord::Base) and ActiveRecord::Base.connection.disconnect!

  # kills old children after zero downtime deploy
  old_pid = "#{server.config[:pid]}.oldbin"
  if old_pid != server.pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end

  sleep 1
end

after_fork do |_server, _worker|
  defined?(ActiveRecord::Base) and ActiveRecord::Base.establish_connection

  defined?(Rails) and Rails.cache.respond_to?(:reconnect) and Rails.cache.reconnect
end
