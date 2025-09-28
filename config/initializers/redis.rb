# Redis configuration for rate limiting
# In production, you'd use environment variables for connection details

# This code runs AUTOMATICALLY when Rails starts
# You don't call it manually - Rails does it for you

REDIS_CLIENT = Redis.new(
  host: "localhost",
  port: 6379,
  db: 0  # Use database 0 for rate limiting
)

# Test the connection
begin
  REDIS_CLIENT.ping
  Rails.logger.info "Redis connected successfully"
rescue Redis::CannotConnectError => e
  Rails.logger.error "Redis connection failed: #{e.message}"
  Rails.logger.error "Make sure Redis is running: brew install redis && brew services start redis"
end
