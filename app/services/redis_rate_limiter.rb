# Redis-based rate limiter using token bucket algorithm
class RedisRateLimiter
  # Configuration
  BUCKET_SIZE = 10      # Maximum tokens in bucket
  REFILL_RATE = 10.0/300  # Tokens added per second (50 tokens per 300 seconds = 5 minutes)

  def initialize(client_id)
    @client_id = client_id
    @redis = REDIS_CLIENT
    @bucket_key = "rate_limit:#{client_id}"
    @last_refill_key = "rate_limit:#{client_id}:last_refill"
  end

  # Check if request is allowed and consume a token if so
  def allow_request?
    # Use Redis transaction to ensure atomicity
    result = @redis.multi do |transaction|
      # Get current values
      current_tokens = transaction.get(@bucket_key)
      last_refill = transaction.get(@last_refill_key)

      # We'll process the result after the transaction
    end

    # Process the transaction results
    current_tokens = result[0]&.to_i || BUCKET_SIZE  # Start with full bucket if new
    last_refill = result[1] ? Time.parse(result[1]) : Time.current

    # Calculate refill
    now = Time.current
    time_passed = now - last_refill
    tokens_to_add = (time_passed * REFILL_RATE).to_i

    # Calculate new token count
    new_tokens = [ current_tokens + tokens_to_add, BUCKET_SIZE ].min

    # Check if we can allow the request
    if new_tokens >= 1
      # Allow request: consume token and update Redis
      final_tokens = new_tokens - 1

      @redis.multi do |transaction|
        transaction.set(@bucket_key, final_tokens)
        transaction.set(@last_refill_key, now.iso8601)
        # Set expiration to clean up old data (1 hour after last use)
        transaction.expire(@bucket_key, 3600)
        transaction.expire(@last_refill_key, 3600)
      end

      true
    else
      # Deny request: just update the refill time
      @redis.multi do |transaction|
        transaction.set(@bucket_key, new_tokens)
        transaction.set(@last_refill_key, now.iso8601)
        transaction.expire(@bucket_key, 3600)
        transaction.expire(@last_refill_key, 3600)
      end

      false
    end
  end

  # Get current token count (for debugging/monitoring)
  def current_tokens
    current_tokens = @redis.get(@bucket_key)&.to_i || BUCKET_SIZE
    last_refill = @redis.get(@last_refill_key)
    last_refill = last_refill ? Time.parse(last_refill) : Time.current

    # Calculate what tokens would be after refill
    now = Time.current
    time_passed = now - last_refill
    tokens_to_add = (time_passed * REFILL_RATE).to_i

    [ current_tokens + tokens_to_add, BUCKET_SIZE ].min
  end

  # Clear rate limit for a client (useful for testing)
  def reset!
    @redis.del(@bucket_key, @last_refill_key)
  end
end
