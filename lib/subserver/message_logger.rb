module Subserver
  class MessageLogger

    def call(message)
      start = Time.now
      logger.info("start")
      yield
      logger.info("done: #{elapsed(start)} sec")
    rescue Exception
      logger.info("fail: #{elapsed(start)} sec")
      raise
    end

    private

    def elapsed(start)
      (Time.now - start).round(3)
    end

    def logger
      Subserver.logger
    end
  end
end