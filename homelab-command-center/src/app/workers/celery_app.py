from celery import Celery
from celery.schedules import crontab
from app.config import settings
import logging

logger = logging.getLogger(__name__)

# Create Celery app
celery_app = Celery(
    "homelab_command_center",
    broker=settings.redis_url,
    backend=settings.redis_url,
    include=["app.workers.tasks"]
)

# Celery configuration
celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=30 * 60,  # 30 minutes
    task_soft_time_limit=25 * 60,  # 25 minutes
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=1000,
)

# Periodic tasks schedule
celery_app.conf.beat_schedule = {
    "collect-cluster-stats": {
        "task": "app.workers.tasks.collect_cluster_stats",
        "schedule": settings.cluster_stats_interval,  # seconds
    },
    "perform-health-checks": {
        "task": "app.workers.tasks.perform_health_checks",
        "schedule": settings.health_check_interval,  # seconds
    },
    "cleanup-old-data": {
        "task": "app.workers.tasks.cleanup_old_data",
        "schedule": crontab(hour=2, minute=0),  # Daily at 2 AM
    },
}

celery_app.conf.timezone = "UTC"
