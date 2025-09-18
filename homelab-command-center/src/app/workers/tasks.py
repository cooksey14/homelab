from celery import current_task
from sqlalchemy.ext.asyncio import AsyncSession
import logging
from datetime import datetime, timedelta

from app.workers.celery_app import celery_app
from app.database import async_session, ClusterStats, HealthCheck
from app.services.cluster_monitoring import cluster_monitoring_service
from app.services.health_check import health_check_service

logger = logging.getLogger(__name__)


@celery_app.task(bind=True)
def collect_cluster_stats(self):
    """Background task to collect cluster statistics."""
    logger.info("Starting cluster stats collection task")
    
    try:
        # Create async session for the task
        async def _collect_stats():
            async with async_session() as db:
                stats = await cluster_monitoring_service.collect_cluster_stats(db)
                logger.info(f"Cluster stats collected: {stats}")
                return stats
        
        # Run the async function
        import asyncio
        result = asyncio.run(_collect_stats())
        
        logger.info("Cluster stats collection task completed successfully")
        return {"status": "success", "data": result}
        
    except Exception as e:
        logger.error(f"Error in cluster stats collection task: {e}")
        # Retry the task with exponential backoff
        raise self.retry(exc=e, countdown=60, max_retries=3)


@celery_app.task(bind=True)
def perform_health_checks(self):
    """Background task to perform health checks."""
    logger.info("Starting health checks task")
    
    try:
        # Create async session for the task
        async def _perform_checks():
            async with async_session() as db:
                health_result = await health_check_service.perform_cluster_health_check(db)
                logger.info(f"Health checks completed: {health_result['overall_status']}")
                return health_result
        
        # Run the async function
        import asyncio
        result = asyncio.run(_perform_checks())
        
        logger.info("Health checks task completed successfully")
        return {"status": "success", "data": result}
        
    except Exception as e:
        logger.error(f"Error in health checks task: {e}")
        # Retry the task with exponential backoff
        raise self.retry(exc=e, countdown=60, max_retries=3)


@celery_app.task(bind=True)
def cleanup_old_data(self):
    """Background task to cleanup old data."""
    logger.info("Starting data cleanup task")
    
    try:
        # Create async session for the task
        async def _cleanup_data():
            async with async_session() as db:
                # Clean up old cluster stats (keep last 7 days)
                cutoff_date = datetime.utcnow() - timedelta(days=7)
                
                from sqlalchemy import delete
                
                # Delete old cluster stats
                result = await db.execute(
                    delete(ClusterStats).where(ClusterStats.timestamp < cutoff_date)
                )
                stats_deleted = result.rowcount
                
                # Delete old health checks (keep last 3 days)
                health_cutoff = datetime.utcnow() - timedelta(days=3)
                result = await db.execute(
                    delete(HealthCheck).where(HealthCheck.checked_at < health_cutoff)
                )
                health_deleted = result.rowcount
                
                await db.commit()
                
                logger.info(f"Cleanup completed: {stats_deleted} stats, {health_deleted} health checks deleted")
                return {
                    "stats_deleted": stats_deleted,
                    "health_checks_deleted": health_deleted
                }
        
        # Run the async function
        import asyncio
        result = asyncio.run(_cleanup_data())
        
        logger.info("Data cleanup task completed successfully")
        return {"status": "success", "data": result}
        
    except Exception as e:
        logger.error(f"Error in data cleanup task: {e}")
        # Retry the task with exponential backoff
        raise self.retry(exc=e, countdown=300, max_retries=2)  # 5 minute retry for cleanup


@celery_app.task(bind=True)
def sync_kubernetes_resources(self):
    """Background task to sync Kubernetes resources to database."""
    logger.info("Starting Kubernetes resources sync task")
    
    try:
        # Create async session for the task
        async def _sync_resources():
            async with async_session() as db:
                from app.services.kubernetes import k8s_client
                from app.database import Node, Pod, Service
                from sqlalchemy import select, update, insert
                
                # Sync nodes
                nodes = await k8s_client.get_nodes()
                for node_data in nodes:
                    # Check if node exists
                    result = await db.execute(
                        select(Node).where(Node.name == node_data["name"])
                    )
                    existing_node = result.scalar_one_or_none()
                    
                    if existing_node:
                        # Update existing node
                        await db.execute(
                            update(Node)
                            .where(Node.name == node_data["name"])
                            .values(
                                status=node_data["status"],
                                role=node_data["role"],
                                version=node_data["version"],
                                os_image=node_data["os_image"],
                                kernel_version=node_data["kernel_version"],
                                container_runtime=node_data["container_runtime"],
                                cpu_capacity=node_data["cpu_capacity"],
                                memory_capacity=node_data["memory_capacity"],
                                cpu_allocatable=node_data["cpu_allocatable"],
                                memory_allocatable=node_data["memory_allocatable"],
                                conditions=node_data["conditions"],
                                labels=node_data["labels"],
                                annotations=node_data["annotations"],
                                updated_at=datetime.utcnow()
                            )
                        )
                    else:
                        # Insert new node
                        new_node = Node(**node_data)
                        db.add(new_node)
                
                await db.commit()
                logger.info(f"Synced {len(nodes)} nodes")
                
                return {"nodes_synced": len(nodes)}
        
        # Run the async function
        import asyncio
        result = asyncio.run(_sync_resources())
        
        logger.info("Kubernetes resources sync task completed successfully")
        return {"status": "success", "data": result}
        
    except Exception as e:
        logger.error(f"Error in Kubernetes resources sync task: {e}")
        # Retry the task with exponential backoff
        raise self.retry(exc=e, countdown=60, max_retries=3)
