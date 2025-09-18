import redis.asyncio as redis
from app.config import settings
import logging

logger = logging.getLogger(__name__)

# Redis connection pool
redis_pool = None

async def get_redis() -> redis.Redis:
    """Get Redis connection."""
    global redis_pool
    if redis_pool is None:
        redis_pool = redis.ConnectionPool.from_url(settings.redis_url)
    
    return redis.Redis(connection_pool=redis_pool)

async def init_redis():
    """Initialize Redis connection."""
    global redis_pool
    try:
        redis_pool = redis.ConnectionPool.from_url(settings.redis_url)
        redis_client = redis.Redis(connection_pool=redis_pool)
        
        # Test connection
        await redis_client.ping()
        logger.info("Redis connection initialized successfully")
        
        return redis_client
    except Exception as e:
        logger.error(f"Failed to initialize Redis: {e}")
        raise

async def close_redis():
    """Close Redis connection."""
    global redis_pool
    if redis_pool:
        await redis_pool.disconnect()
        redis_pool = None
        logger.info("Redis connection closed")
