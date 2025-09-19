from kubernetes import client, config
from kubernetes.client.rest import ApiException
from typing import List, Dict, Any, Optional
import logging
from app.config import settings

logger = logging.getLogger(__name__)


class KubernetesClient:
    """Kubernetes API client wrapper."""
    
    def __init__(self):
        self.v1 = None
        self.apps_v1 = None
        self.metrics_v1 = None
        self._initialize_clients()
    
    def _initialize_clients(self):
        """Initialize Kubernetes API clients."""
        try:
            # Try to load in-cluster config first (when running in Kubernetes)
            config.load_incluster_config()
            logger.info("Loaded in-cluster Kubernetes config")
        except Exception:
            try:
                # Fall back to kubeconfig file
                config.load_kube_config()
                logger.info("Loaded Kubernetes config from file")
            except Exception as e:
                logger.warning(f"Failed to load Kubernetes config: {e}")
                logger.warning("Running in mock mode - Kubernetes API calls will return empty data")
                self.v1 = None
                self.apps_v1 = None
                self.metrics_v1 = None
                return
        
        self.v1 = client.CoreV1Api()
        self.apps_v1 = client.AppsV1Api()
        
        # Try to initialize metrics client (may not be available)
        try:
            self.metrics_v1 = client.CustomObjectsApi()
        except Exception as e:
            logger.warning(f"Metrics API not available: {e}")
            self.metrics_v1 = None
    
    async def get_nodes(self) -> List[Dict[str, Any]]:
        """Get all cluster nodes."""
        if not self.v1:
            logger.warning("Kubernetes client not available, returning mock data")
            return self._get_mock_nodes()
        
        try:
            nodes = self.v1.list_node()
            return [self._serialize_node(node) for node in nodes.items]
        except ApiException as e:
            logger.error(f"Failed to get nodes: {e}")
            return []
    
    async def get_pods(self, namespace: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get pods from cluster."""
        if not self.v1:
            logger.warning("Kubernetes client not available, returning mock data")
            return self._get_mock_pods()
        
        try:
            if namespace:
                pods = self.v1.list_namespaced_pod(namespace=namespace)
            else:
                pods = self.v1.list_pod_for_all_namespaces()
            return [self._serialize_pod(pod) for pod in pods.items]
        except ApiException as e:
            logger.error(f"Failed to get pods: {e}")
            return []
    
    async def get_services(self, namespace: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get services from cluster."""
        if not self.v1:
            logger.warning("Kubernetes client not available, returning mock data")
            return self._get_mock_services()
        
        try:
            if namespace:
                services = self.v1.list_namespaced_service(namespace=namespace)
            else:
                services = self.v1.list_service_for_all_namespaces()
            return [self._serialize_service(service) for service in services.items]
        except ApiException as e:
            logger.error(f"Failed to get services: {e}")
            return []
    
    async def get_node_metrics(self) -> List[Dict[str, Any]]:
        """Get node metrics (if metrics server is available)."""
        if not self.metrics_v1:
            return []
        
        try:
            metrics = self.metrics_v1.list_cluster_custom_object(
                group="metrics.k8s.io",
                version="v1beta1",
                plural="nodes"
            )
            return metrics.get("items", [])
        except Exception as e:
            logger.warning(f"Failed to get node metrics: {e}")
            return []
    
    async def get_pod_metrics(self, namespace: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get pod metrics (if metrics server is available)."""
        if not self.metrics_v1:
            return []
        
        try:
            if namespace:
                metrics = self.metrics_v1.list_namespaced_custom_object(
                    group="metrics.k8s.io",
                    version="v1beta1",
                    namespace=namespace,
                    plural="pods"
                )
            else:
                metrics = self.metrics_v1.list_cluster_custom_object(
                    group="metrics.k8s.io",
                    version="v1beta1",
                    plural="pods"
                )
            return metrics.get("items", [])
        except Exception as e:
            logger.warning(f"Failed to get pod metrics: {e}")
            return []
    
    def _serialize_node(self, node) -> Dict[str, Any]:
        """Serialize node object to dictionary."""
        status = node.status
        spec = node.spec
        
        # Extract node conditions
        conditions = {}
        for condition in status.conditions or []:
            conditions[condition.type] = {
                "status": condition.status,
                "reason": condition.reason,
                "message": condition.message,
                "last_transition_time": condition.last_transition_time.isoformat() if condition.last_transition_time else None
            }
        
        # Extract capacity and allocatable resources
        capacity = {}
        allocatable = {}
        
        if status.capacity:
            capacity = dict(status.capacity)
        if status.allocatable:
            allocatable = dict(status.allocatable)
        
        return {
            "name": node.metadata.name,
            "status": "Ready" if any(c.type == "Ready" and c.status == "True" for c in status.conditions or []) else "NotReady",
            "role": "master" if "node-role.kubernetes.io/master" in (node.metadata.labels or {}) else "worker",
            "version": status.node_info.kubelet_version if status.node_info else None,
            "os_image": status.node_info.os_image if status.node_info else None,
            "kernel_version": status.node_info.kernel_version if status.node_info else None,
            "container_runtime": status.node_info.container_runtime_version if status.node_info else None,
            "cpu_capacity": capacity.get("cpu"),
            "memory_capacity": capacity.get("memory"),
            "cpu_allocatable": allocatable.get("cpu"),
            "memory_allocatable": allocatable.get("memory"),
            "conditions": conditions,
            "labels": dict(node.metadata.labels or {}),
            "annotations": dict(node.metadata.annotations or {}),
        }
    
    def _serialize_pod(self, pod) -> Dict[str, Any]:
        """Serialize pod object to dictionary."""
        status = pod.status
        spec = pod.spec
        
        # Calculate restart count
        restart_count = 0
        for container_status in status.container_statuses or []:
            restart_count += container_status.restart_count
        
        # Determine if pod is ready
        ready = False
        if status.conditions:
            for condition in status.conditions:
                if condition.type == "Ready" and condition.status == "True":
                    ready = True
                    break
        
        # Serialize container information
        containers = []
        for container in spec.containers:
            container_info = {
                "name": container.name,
                "image": container.image,
                "ports": [{"port": p.container_port, "protocol": p.protocol} for p in container.ports or []],
                "resources": {
                    "requests": dict(container.resources.requests) if container.resources and container.resources.requests else {},
                    "limits": dict(container.resources.limits) if container.resources and container.resources.limits else {}
                }
            }
            containers.append(container_info)
        
        return {
            "name": pod.metadata.name,
            "namespace": pod.metadata.namespace,
            "node_name": spec.node_name,
            "status": status.phase,
            "phase": status.phase,
            "restart_count": restart_count,
            "ready": ready,
            "containers": containers,
            "labels": dict(pod.metadata.labels or {}),
            "annotations": dict(pod.metadata.annotations or {}),
        }
    
    def _serialize_service(self, service) -> Dict[str, Any]:
        """Serialize service object to dictionary."""
        spec = service.spec
        
        # Serialize ports
        ports = []
        for port in spec.ports or []:
            port_info = {
                "name": port.name,
                "port": port.port,
                "target_port": port.target_port,
                "protocol": port.protocol
            }
            if port.node_port:
                port_info["node_port"] = port.node_port
            ports.append(port_info)
        
        return {
            "name": service.metadata.name,
            "namespace": service.metadata.namespace,
            "type": spec.type,
            "cluster_ip": spec.cluster_ip,
            "external_ips": spec.external_i_ps or [],
            "ports": ports,
            "selector": dict(spec.selector or {}),
            "labels": dict(service.metadata.labels or {}),
            "annotations": dict(service.metadata.annotations or {}),
        }


    def _get_mock_nodes(self) -> List[Dict[str, Any]]:
        """Return mock node data for local development."""
        return [
            {
                "name": "master-node",
                "status": "Ready",
                "role": "master",
                "version": "v1.28.0",
                "os_image": "Ubuntu 22.04 LTS",
                "kernel_version": "5.15.0-91-generic",
                "container_runtime": "containerd://1.7.0",
                "cpu_capacity": "4",
                "memory_capacity": "8Gi",
                "cpu_allocatable": "3900m",
                "memory_allocatable": "7.5Gi",
                "conditions": {
                    "Ready": {"status": "True", "reason": "KubeletReady", "message": "kubelet is posting ready status"}
                },
                "labels": {"node-role.kubernetes.io/master": ""},
                "annotations": {}
            },
            {
                "name": "worker-node-1",
                "status": "Ready",
                "role": "worker",
                "version": "v1.28.0",
                "os_image": "Ubuntu 22.04 LTS",
                "kernel_version": "5.15.0-91-generic",
                "container_runtime": "containerd://1.7.0",
                "cpu_capacity": "2",
                "memory_capacity": "4Gi",
                "cpu_allocatable": "1900m",
                "memory_allocatable": "3.5Gi",
                "conditions": {
                    "Ready": {"status": "True", "reason": "KubeletReady", "message": "kubelet is posting ready status"}
                },
                "labels": {"node-role.kubernetes.io/worker": ""},
                "annotations": {}
            }
        ]
    
    def _get_mock_pods(self) -> List[Dict[str, Any]]:
        """Return mock pod data for local development."""
        return [
            {
                "name": "homelab-command-center-7d8f9c4b5-abc12",
                "namespace": "homelab-command-center",
                "node_name": "master-node",
                "status": "Running",
                "phase": "Running",
                "restart_count": 0,
                "ready": True,
                "containers": [
                    {
                        "name": "app",
                        "image": "homelab-command-center:latest",
                        "ports": [{"port": 8000, "protocol": "TCP"}],
                        "resources": {"requests": {"cpu": "100m", "memory": "128Mi"}}
                    }
                ],
                "labels": {"app": "homelab-command-center"},
                "annotations": {}
            },
            {
                "name": "postgres-6c8d9e4f2-def34",
                "namespace": "homelab-command-center",
                "node_name": "worker-node-1",
                "status": "Running",
                "phase": "Running",
                "restart_count": 0,
                "ready": True,
                "containers": [
                    {
                        "name": "postgres",
                        "image": "postgres:15",
                        "ports": [{"port": 5432, "protocol": "TCP"}],
                        "resources": {"requests": {"cpu": "200m", "memory": "256Mi"}}
                    }
                ],
                "labels": {"app": "postgres"},
                "annotations": {}
            }
        ]
    
    def _get_mock_services(self) -> List[Dict[str, Any]]:
        """Return mock service data for local development."""
        return [
            {
                "name": "homelab-command-center-service",
                "namespace": "homelab-command-center",
                "type": "ClusterIP",
                "cluster_ip": "10.96.1.100",
                "external_ips": [],
                "ports": [
                    {"name": "http", "port": 80, "target_port": 8000, "protocol": "TCP"}
                ],
                "selector": {"app": "homelab-command-center"},
                "labels": {"app": "homelab-command-center"},
                "annotations": {}
            },
            {
                "name": "postgres-service",
                "namespace": "homelab-command-center",
                "type": "ClusterIP",
                "cluster_ip": "10.96.1.101",
                "external_ips": [],
                "ports": [
                    {"name": "postgres", "port": 5432, "target_port": 5432, "protocol": "TCP"}
                ],
                "selector": {"app": "postgres"},
                "labels": {"app": "postgres"},
                "annotations": {}
            }
        ]


# Global Kubernetes client instance
k8s_client = KubernetesClient()
