require 'logger'
require 'json'
require 'benchmark'

Dir['./lib/*.rb'].sort.each { |file| require file }

$stdout.sync = true

logger = Logger.new(STDOUT)
logger.info('Application has been started.')

servers = ENV['LXD_HOSTS'].split(',')

# TODO: Refactor this mess

loop do
  total_time = Benchmark.realtime do
    servers.each do |s|
      lxd = Lxd.new(s, ENV['CLIENT_CERT'], ENV['CLIENT_KEY'], ENV['LOG_LEVEL'])
      redis = Database.new(ENV['REDIS_HOST'], ENV['REDIS_PORT'], ENV['LOG_LEVEL'])
      
      import_time = Benchmark.realtime do
        lxd.get_containers.each do |container|
          redis.save_container(
            "lxd:#{URI.parse(lxd.api_endpoint).hostname}:#{container}",
            ENV['INTERVAL'].to_i + 60,
            info: lxd.get_container_info(container).to_json,
            state: lxd.get_container_state(container).to_json
          )
        end
      end
      logger.info('Containers data have been saved')
      logger.info("Import time: #{import_time.round(2)}s")
    end
  end
  logger.info("Total import time: #{total_time.round(2)}s")

  sleep ENV['INTERVAL'].to_i
end

logger.info('Application has been finished.')