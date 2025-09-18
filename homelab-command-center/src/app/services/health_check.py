from typing import List, Dict, Any, Optional
from datetime import datetime
import logging
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from app.database import Node, Pod, Service, HealthCheck
from app.services.kubernetes import k8s_client

logger = logging.getLogger(__name__)


class HealthCheckService:
    """Service for performing health checks on Kubernetes resources."""
    
    def __init__(self):
        self.k8s_client = k8s_client
    
    async def check_node_health(self, db: AsyncSession, node_data: Dict[str, Any]) -> Dict[str, Any]:
        """Check health of a Kubernetes node."""
        node_name = node_data["name"]
        status = "healthy"
        message = "Node is healthy"
        details = {}
        
        try:
            # Check node conditions
            conditions = node_data.get("conditions", {})
            
            # Check Ready condition
            ready_condition = conditions.get("Ready", {})
            if ready_condition.get("status") != "True":
                status = "unhealthy"
                message = f"Node {node_name} is not ready: {ready_condition.get('reason', 'Unknown')}"
                details["ready_condition"] = ready_condition
            
            # Check MemoryPressure condition
            memory_pressure = conditions.get("MemoryPressure", {})
            if memory_pressure.get("status") == "True":
                status = "warning" if status == "healthy" else status
                message = f"Node {node_name} has memory pressure"
                details["memory_pressure"] = memory_pressure
            
            # Check DiskPressure condition
            disk_pressure = conditions.get("DiskPressure", {})
            if disk_pressure.get("status") == "True":
                status = "warning" if status == "healthy" else status
                message = f"Node {node_name} has disk pressure"
                details["disk_pressure"] = disk_pressure
            
            # Check PIDPressure condition
            pid_pressure = conditions.get("PIDPressure", {})
            if pid_pressure.get("status") == "True":
                status = "warning" if status == "healthy" else status
                message = f"Node {node_name} has PID pressure"
                details["pid_pressure"] = pid_pressure
            
            # Store health check result
            await self._store_health_check(
                db, "node", node_name, None, status, message, details
            )
            
            return {
                "resource_type": "node",
                "resource_name": node_name,
                "status": status,
                "message": message,
                "details": details,
                "checked_at": datetime.utcnow()
            }
            
        except Exception as e:
            logger.error(f"Error checking node health for {node_name}: {e}")
            status = "unhealthy"
            message = f"Error checking node health: {str(e)}"
            
            await self._store_health_check(
                db, "node", node_name, None, status, message, {"error": str(e)}
            )
            
            return {
                "resource_type": "node",
                "resource_name": node_name,
                "status": status,
                "message": message,
                "details": {"error": str(e)},
                "checked_at": datetime.utcnow()
            }
    
    async def check_pod_health(self, db: AsyncSession, pod_data: Dict[str, Any]) -> Dict[str, Any]:
        """Check health of a Kubernetes pod."""
        pod_name = pod_data["name"]
        namespace = pod_data["namespace"]
        status = "healthy"
        message = "Pod is healthy"
        details = {}
        
        try:
            phase = pod_data.get("phase", "Unknown")
            restart_count = pod_data.get("restart_count", 0)
            ready = pod_data.get("ready", False)
            
            # Check pod phase
            if phase == "Failed":
                status = "unhealthy"
                message = f"Pod {pod_name} is in Failed state"
                details["phase"] = phase
            elif phase == "Pending":
                status = "warning"
                message = f"Pod {pod_name} is Pending"
                details["phase"] = phase
            elif phase == "Running" and not ready:
                status = "warning"
                message = f"Pod {pod_name} is Running but not ready"
                details["phase"] = phase
                details["ready"] = ready
            
            # Check restart count
            if restart_count > 5:
                status = "warning" if status == "healthy" else status
                message = f"Pod {pod_name} has high restart count: {restart_count}"
                details["restart_count"] = restart_count
            
            # Store health check result
            await self._store_health_check(
                db, "pod", pod_name, namespace, status, message, details
            )
            
            return {
                "resource_type": "pod",
                "resource_name": pod_name,
                "namespace": namespace,
                "status": status,
                "message": message,
                "details": details,
                "checked_at": datetime.utcnow()
            }
            
        except Exception as e:
            logger.error(f"Error checking pod health for {pod_name}: {e}")
            status = "unhealthy"
            message = f"Error checking pod health: {str(e)}"
            
            await self._store_health_check(
                db, "pod", pod_name, namespace, status, message, {"error": str(e)}
            )
            
            return {
                "resource_type": "pod",
                "resource_name": pod_name,
                "namespace": namespace,
                "status": status,
                "message": message,
                "details": {"error": str(e)},
                "checked_at": datetime.utcnow()
            }
    
    async def check_service_health(self, db: AsyncSession, service_data: Dict[str, Any]) -> Dict[str, Any]:
        """Check health of a Kubernetes service."""
        service_name = service_data["name"]
        namespace = service_data["namespace"]
        status = "healthy"
        message = "Service is healthy"
        details = {}
        
        try:
            service_type = service_data.get("type", "ClusterIP")
            cluster_ip = service_data.get("cluster_ip")
            ports = service_data.get("ports", [])
            
            # Check if service has ClusterIP
            if service_type in ["ClusterIP", "NodePort", "LoadBalancer"] and not cluster_ip:
                status = "unhealthy"
                message = f"Service {service_name} has no ClusterIP"
                details["cluster_ip"] = cluster_ip
            
            # Check if service has ports defined
            if not ports:
                status = "warning" if status == "healthy" else status
                message = f"Service {service_name} has no ports defined"
                details["ports"] = ports
            
            # Store health check result
            await self._store_health_check(
                db, "service", service_name, namespace, status, message, details
            )
            
            return {
                "resource_type": "service",
                "resource_name": service_name,
                "namespace": namespace,
                "status": status,
                "message": message,
                "details": details,
                "checked_at": datetime.utcnow()
            }
            
        except Exception as e:
            logger.error(f"Error checking service health for {service_name}: {e}")
            status = "unhealthy"
            message = f"Error checking service health: {str(e)}"
            
            await self._store_health_check(
                db, "service", service_name, namespace, status, message, {"error": str(e)}
            )
            
            return {
                "resource_type": "service",
                "resource_name": service_name,
                "namespace": namespace,
                "status": status,
                "message": message,
                "details": {"error": str(e)},
                "checked_at": datetime.utcnow()
            }
    
    async def perform_cluster_health_check(self, db: AsyncSession) -> Dict[str, Any]:
        """Perform comprehensive health check on the entire cluster."""
        logger.info("Starting cluster health check")
        
        try:
            # Get all resources from Kubernetes
            nodes = await self.k8s_client.get_nodes()
            pods = await self.k8s_client.get_pods()
            services = await self.k8s_client.get_services()
            
            # Perform health checks
            node_health = []
            pod_health = []
            service_health = []
            
            # Check nodes
            for node_data in nodes:
                health_result = await self.check_node_health(db, node_data)
                node_health.append(health_result)
            
            # Check pods
            for pod_data in pods:
                health_result = await self.check_pod_health(db, pod_data)
                pod_health.append(health_result)
            
            # Check services
            for service_data in services:
                health_result = await self.check_service_health(db, service_data)
                service_health.append(health_result)
            
            # Calculate overall cluster health
            all_checks = node_health + pod_health + service_health
            unhealthy_count = sum(1 for check in all_checks if check["status"] == "unhealthy")
            warning_count = sum(1 for check in all_checks if check["status"] == "warning")
            healthy_count = sum(1 for check in all_checks if check["status"] == "healthy")
            
            overall_status = "healthy"
            if unhealthy_count > 0:
                overall_status = "unhealthy"
            elif warning_count > 0:
                overall_status = "warning"
            
            cluster_health = {
                "overall_status": overall_status,
                "total_checks": len(all_checks),
                "healthy": healthy_count,
                "warning": warning_count,
                "unhealthy": unhealthy_count,
                "nodes": node_health,
                "pods": pod_health,
                "services": service_health,
                "checked_at": datetime.utcnow()
            }
            
            logger.info(f"Cluster health check completed: {overall_status}")
            return cluster_health
            
        except Exception as e:
            logger.error(f"Error performing cluster health check: {e}")
            return {
                "overall_status": "unhealthy",
                "error": str(e),
                "checked_at": datetime.utcnow()
            }
    
    async def _store_health_check(
        self, 
        db: AsyncSession, 
        resource_type: str, 
        resource_name: str, 
        namespace: Optional[str], 
        status: str, 
        message: str, 
        details: Dict[str, Any]
    ):
        """Store health check result in database."""
        try:
            health_check = HealthCheck(
                resource_type=resource_type,
                resource_name=resource_name,
                namespace=namespace,
                status=status,
                message=message,
                details=details
            )
            db.add(health_check)
            await db.commit()
        except Exception as e:
            logger.error(f"Error storing health check: {e}")
            await db.rollback()


# Global health check service instance
health_check_service = HealthCheckService()
