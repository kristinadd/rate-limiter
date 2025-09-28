# Simple in-memory rate limiter using token bucket algorithm
class RateLimiter
  # Class variable to store buckets for all clients
  # In production, this would be in Redis, but we're starting simple
  @@buckets = {}
  @@mutex = Mutex.new

  # Configuration
  BUCKET_SIZE = 50      # Maximum tokens in bucket
  REFILL_RATE = 50      # Tokens added per second

  def initialize(client_id)
    @client_id = client_id
  end

  # Check if request is allowed and consume a token if so
  def allow_request?
    @@mutex.synchronize do
      bucket = get_or_create_bucket

      # Refill tokens based on time passed
      refill_bucket(bucket)

      # Check if we have tokens available
      if bucket[:tokens] >= 1
        bucket[:tokens] -= 1  # Consume one token
        true
      else
        false  # Rate limited
      end
    end
  end

  # Get current token count (for debugging/monitoring)
  def current_tokens
    @@mutex.synchronize do
      bucket = get_or_create_bucket
      refill_bucket(bucket)
      bucket[:tokens]
    end
  end

  private

  def get_or_create_bucket
    @@buckets[@client_id] ||= {
      tokens: BUCKET_SIZE,           # Start with full bucket
      last_refill: Time.current      # Track when we last added tokens
    }
  end

  def refill_bucket(bucket)
    now = Time.current
    time_passed = now - bucket[:last_refill]

    # Calculate how many tokens to add based on time passed
    tokens_to_add = (time_passed * REFILL_RATE).to_i

    if tokens_to_add > 0
      # Add tokens but don't exceed bucket size
      bucket[:tokens] = [ bucket[:tokens] + tokens_to_add, BUCKET_SIZE ].min
      bucket[:last_refill] = now
    end
  end
end
