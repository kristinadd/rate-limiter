class ApiController < ApplicationController
  # Skip CSRF protection for API endpoints
  skip_before_action :verify_authenticity_token

  # Apply rate limiting to all actions in this controller
  before_action :check_rate_limit

  # Simple API endpoint that returns some data
  def data
    render json: {
      message: "Success! You made it through the rate limiter.",
      timestamp: Time.current,
      user_id: current_user_id,
      remaining_tokens: current_limiter.current_tokens
    }
  end

  # Another endpoint to test with
  def status
    render json: {
      status: "OK",
      server_time: Time.current,
      user_id: current_user_id,
      rate_limit_info: {
        remaining_tokens: current_limiter.current_tokens,
        max_tokens: RedisRateLimiter::BUCKET_SIZE,
        refill_rate: "#{RedisRateLimiter::REFILL_RATE * 60} tokens per minute"
      }
    }
  end

  private

  def check_rate_limit
    unless current_limiter.allow_request?
      render json: {
        error: "Rate limit exceeded",
        message: "You have exceeded the rate limit of #{RedisRateLimiter::BUCKET_SIZE} requests per 5 minutes.",
        retry_after: "Try again in a few seconds",
        current_tokens: current_limiter.current_tokens
      }, status: 429  # HTTP 429 Too Many Requests
      false
    end
  end

  def current_limiter
    @current_limiter ||= RedisRateLimiter.new(current_user_id)
  end

  def current_user_id
    # In a real app, this would come from authentication
    # For demo purposes, we'll use IP address or a header
    request.headers["X-User-ID"] || request.remote_ip || "anonymous"
  end
end
