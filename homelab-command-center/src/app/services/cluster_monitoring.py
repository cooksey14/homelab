from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import logging
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
from app.database import Node, Pod, Service, ClusterStats
from app.services.kubernetes import k8s_client

logger = logging.getLogger(__name__)


class ClusterMonitoringService:
    """Service for monitoring cluster statistics and metrics."""
    
    def __init__(self):
        self.k8s_client = k8s_client
    
    async def collect_cluster_stats(self, db: AsyncSession) -> Dict[str, Any]:
        """Collect comprehensive cluster statistics."""
        logger.info("Collecting cluster statistics")
        
        try:
            # Get all resources from Kubernetes
            nodes = await self.k8s_client.get_nodes()
            pods = await self.k8s_client.get_pods()
            services = await self.k8s_client.get_services()
            
            # Calculate node statistics
            total_nodes = len(nodes)
            ready_nodes = sum(1 for node in nodes if node.get("status") == "Ready")
            
            # Calculate pod statistics
            total_pods = len(pods)
            running_pods = sum(1 for pod in pods if pod.get("phase") == "Running")
            pending_pods = sum(1 for pod in pods if pod.get("phase") == "Pending")
            failed_pods = sum(1 for pod in pods if pod.get("phase") == "Failed")
            
            # Calculate service statistics
            total_services = len(services)
            
            # Try to get resource usage metrics
            cpu_usage_percent = None
            memory_usage_percent = None
            storage_usage_percent = None
            
            try:
                node_metrics = await self.k8s_client.get_node_metrics()
                if node_metrics:
                    cpu_usage_percent, memory_usage_percent = self._calculate_resource_usage(node_metrics)
            except Exception as e:
                logger.warning(f"Could not get resource metrics: {e}")
            
            # Create cluster stats record
            cluster_stats = ClusterStats(
                total_nodes=total_nodes,
                ready_nodes=ready_nodes,
                total_pods=total_pods,
                running_pods=running_pods,
                pending_pods=pending_pods,
                failed_pods=failed_pods,
                total_services=total_services,
                cpu_usage_percent=cpu_usage_percent,
                memory_usage_percent=memory_usage_percent,
                storage_usage_percent=storage_usage_percent,
                custom_metrics={
                    "node_roles": self._get_node_roles(nodes),
                    "pod_namespaces": self._get_pod_namespaces(pods),
                    "service_types": self._get_service_types(services)
                }
            )
            
            db.add(cluster_stats)
            await db.commit()
            
            # Return the stats data
            stats_data = {
                "timestamp": cluster_stats.timestamp,
                "total_nodes": total_nodes,
                "ready_nodes": ready_nodes,
                "total_pods": total_pods,
                "running_pods": running_pods,
                "pending_pods": pending_pods,
                "failed_pods": failed_pods,
                "total_services": total_services,
                "cpu_usage_percent": cpu_usage_percent,
                "memory_usage_percent": memory_usage_percent,
                "storage_usage_percent": storage_usage_percent,
                "custom_metrics": cluster_stats.custom_metrics
            }
            
            logger.info(f"Cluster stats collected: {total_nodes} nodes, {total_pods} pods, {total_services} services")
            return stats_data
            
        except Exception as e:
            logger.error(f"Error collecting cluster stats: {e}")
            await db.rollback()
            raise
    
    async def get_cluster_stats_history(
        self, 
        db: AsyncSession, 
        hours: int = 24, 
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """Get historical cluster statistics."""
        try:
            since = datetime.utcnow() - timedelta(hours=hours)
            
            result = await db.execute(
                select(ClusterStats)
                .where(ClusterStats.timestamp >= since)
                .order_by(desc(ClusterStats.timestamp))
                .limit(limit)
            )
            
            stats_records = result.scalars().all()
            
            return [
                {
                    "timestamp": record.timestamp,
                    "total_nodes": record.total_nodes,
                    "ready_nodes": record.ready_nodes,
                    "total_pods": record.total_pods,
                    "running_pods": record.running_pods,
                    "pending_pods": record.pending_pods,
                    "failed_pods": record.failed_pods,
                    "total_services": record.total_services,
                    "cpu_usage_percent": record.cpu_usage_percent,
                    "memory_usage_percent": record.memory_usage_percent,
                    "storage_usage_percent": record.storage_usage_percent,
                    "custom_metrics": record.custom_metrics
                }
                for record in stats_records
            ]
            
        except Exception as e:
            logger.error(f"Error getting cluster stats history: {e}")
            return []
    
    async def get_current_cluster_state(self, db: AsyncSession) -> Dict[str, Any]:
        """Get current cluster state with detailed information."""
        try:
            # Get latest stats
            result = await db.execute(
                select(ClusterStats)
                .order_by(desc(ClusterStats.timestamp))
                .limit(1)
            )
            latest_stats = result.scalar_one_or_none()
            
            # Get current resources
            nodes = await self.k8s_client.get_nodes()
            pods = await self.k8s_client.get_pods()
            services = await self.k8s_client.get_services()
            
            # Get detailed node information
            node_details = []
            for node in nodes:
                node_info = {
                    "name": node["name"],
                    "status": node["status"],
                    "role": node["role"],
                    "version": node["version"],
                    "os_image": node["os_image"],
                    "cpu_capacity": node["cpu_capacity"],
                    "memory_capacity": node["memory_capacity"],
                    "cpu_allocatable": node["cpu_allocatable"],
                    "memory_allocatable": node["memory_allocatable"],
                    "conditions": node["conditions"]
                }
                node_details.append(node_info)
            
            # Get detailed pod information
            pod_details = []
            for pod in pods:
                pod_info = {
                    "name": pod["name"],
                    "namespace": pod["namespace"],
                    "node_name": pod["node_name"],
                    "phase": pod["phase"],
                    "restart_count": pod["restart_count"],
                    "ready": pod["ready"],
                    "containers": pod["containers"]
                }
                pod_details.append(pod_info)
            
            # Get detailed service information
            service_details = []
            for service in services:
                service_info = {
                    "name": service["name"],
                    "namespace": service["namespace"],
                    "type": service["type"],
                    "cluster_ip": service["cluster_ip"],
                    "ports": service["ports"],
                    "selector": service["selector"]
                }
                service_details.append(service_info)
            
            return {
                "timestamp": datetime.utcnow(),
                "latest_stats": {
                    "timestamp": latest_stats.timestamp if latest_stats else None,
                    "total_nodes": latest_stats.total_nodes if latest_stats else 0,
                    "ready_nodes": latest_stats.ready_nodes if latest_stats else 0,
                    "total_pods": latest_stats.total_pods if latest_stats else 0,
                    "running_pods": latest_stats.running_pods if latest_stats else 0,
                    "pending_pods": latest_stats.pending_pods if latest_stats else 0,
                    "failed_pods": latest_stats.failed_pods if latest_stats else 0,
                    "total_services": latest_stats.total_services if latest_stats else 0,
                    "cpu_usage_percent": latest_stats.cpu_usage_percent if latest_stats else None,
                    "memory_usage_percent": latest_stats.memory_usage_percent if latest_stats else None,
                },
                "nodes": node_details,
                "pods": pod_details,
                "services": service_details
            }
            
        except Exception as e:
            logger.error(f"Error getting current cluster state: {e}")
            return {"error": str(e)}
    
    def _calculate_resource_usage(self, node_metrics: List[Dict[str, Any]]) -> tuple[Optional[float], Optional[float]]:
        """Calculate CPU and memory usage percentages from metrics."""
        try:
            total_cpu_usage = 0
            total_memory_usage = 0
            total_cpu_capacity = 0
            total_memory_capacity = 0
            
            for metric in node_metrics:
                usage = metric.get("usage", {})
                cpu_usage = self._parse_resource_quantity(usage.get("cpu", "0"))
                memory_usage = self._parse_resource_quantity(usage.get("memory", "0"))
                
                # Get node capacity (this would need to be fetched separately)
                # For now, we'll use a simplified calculation
                total_cpu_usage += cpu_usage
                total_memory_usage += memory_usage
            
            # This is a simplified calculation - in reality, you'd need to get
            # the actual node capacities and calculate percentages properly
            cpu_percent = (total_cpu_usage / max(total_cpu_capacity, 1)) * 100 if total_cpu_capacity > 0 else None
            memory_percent = (total_memory_usage / max(total_memory_capacity, 1)) * 100 if total_memory_capacity > 0 else None
            
            return cpu_percent, memory_percent
            
        except Exception as e:
            logger.warning(f"Error calculating resource usage: {e}")
            return None, None
    
    def _parse_resource_quantity(self, quantity: str) -> float:
        """Parse Kubernetes resource quantity string to float."""
        try:
            # Remove common suffixes and convert to float
            quantity = quantity.replace("m", "").replace("Mi", "").replace("Gi", "").replace("Ki", "")
            return float(quantity)
        except (ValueError, AttributeError):
            return 0.0
    
    def _get_node_roles(self, nodes: List[Dict[str, Any]]) -> Dict[str, int]:
        """Get count of nodes by role."""
        roles = {}
        for node in nodes:
            role = node.get("role", "unknown")
            roles[role] = roles.get(role, 0) + 1
        return roles
    
    def _get_pod_namespaces(self, pods: List[Dict[str, Any]]) -> Dict[str, int]:
        """Get count of pods by namespace."""
        namespaces = {}
        for pod in pods:
            namespace = pod.get("namespace", "unknown")
            namespaces[namespace] = namespaces.get(namespace, 0) + 1
        return namespaces
    
    def _get_service_types(self, services: List[Dict[str, Any]]) -> Dict[str, int]:
        """Get count of services by type."""
        types = {}
        for service in services:
            service_type = service.get("type", "unknown")
            types[service_type] = types.get(service_type, 0) + 1
        return types


# Global cluster monitoring service instance
cluster_monitoring_service = ClusterMonitoringService()
