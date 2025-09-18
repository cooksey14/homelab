from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import logging
import asyncio

from app.services.kubernetes import k8s_client

logger = logging.getLogger(__name__)

# Create router
router = APIRouter(tags=["monitoring"])


@router.get("/health")
async def health_check():
    """Basic health check endpoint."""
    return {"status": "healthy", "timestamp": datetime.utcnow()}


@router.get("/nodes")
async def get_nodes():
    """Get all cluster nodes."""
    try:
        nodes = await k8s_client.get_nodes()
        return {"nodes": nodes, "count": len(nodes)}
    except Exception as e:
        logger.error(f"Error getting nodes: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/nodes/{node_name}")
async def get_node(node_name: str):
    """Get specific node information."""
    try:
        nodes = await k8s_client.get_nodes()
        node = next((n for n in nodes if n["name"] == node_name), None)
        if not node:
            raise HTTPException(status_code=404, detail=f"Node {node_name} not found")
        return node
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting node {node_name}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/pods")
async def get_pods(namespace: Optional[str] = Query(None)):
    """Get pods from cluster."""
    try:
        pods = await k8s_client.get_pods(namespace)
        return {"pods": pods, "count": len(pods), "namespace": namespace}
    except Exception as e:
        logger.error(f"Error getting pods: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/pods/{pod_name}")
async def get_pod(pod_name: str, namespace: Optional[str] = Query(None)):
    """Get specific pod information."""
    try:
        pods = await k8s_client.get_pods(namespace)
        pod = next((p for p in pods if p["name"] == pod_name), None)
        if not pod:
            raise HTTPException(status_code=404, detail=f"Pod {pod_name} not found")
        return pod
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting pod {pod_name}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/services")
async def get_services(namespace: Optional[str] = Query(None)):
    """Get services from cluster."""
    try:
        services = await k8s_client.get_services(namespace)
        return {"services": services, "count": len(services), "namespace": namespace}
    except Exception as e:
        logger.error(f"Error getting services: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/services/{service_name}")
async def get_service(service_name: str, namespace: Optional[str] = Query(None)):
    """Get specific service information."""
    try:
        services = await k8s_client.get_services(namespace)
        service = next((s for s in services if s["name"] == service_name), None)
        if not service:
            raise HTTPException(status_code=404, detail=f"Service {service_name} not found")
        return service
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting service {service_name}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/metrics/nodes")
async def get_node_metrics():
    """Get node metrics (if metrics server is available)."""
    try:
        metrics = await k8s_client.get_node_metrics()
        return {"metrics": metrics, "count": len(metrics)}
    except Exception as e:
        logger.error(f"Error getting node metrics: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/metrics/pods")
async def get_pod_metrics(namespace: Optional[str] = Query(None)):
    """Get pod metrics (if metrics server is available)."""
    try:
        metrics = await k8s_client.get_pod_metrics(namespace)
        return {"metrics": metrics, "count": len(metrics), "namespace": namespace}
    except Exception as e:
        logger.error(f"Error getting pod metrics: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# Data Collection Endpoints

@router.post("/collect/nodes")
async def collect_nodes_data(background_tasks: BackgroundTasks):
    """
    Collect node data from Kubernetes cluster and store in database.
    This endpoint triggers data collection in the background.
    """
    try:
        # Collect data from Kubernetes API
        nodes_data = await k8s_client.get_nodes()
        
        # Store in database (background task)
        background_tasks.add_task(store_nodes_data, nodes_data)
        
        return {
            "message": "Node data collection started",
            "nodes_count": len(nodes_data),
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Failed to collect nodes data: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/collect/pods")
async def collect_pods_data(namespace: Optional[str] = Query(None), background_tasks: BackgroundTasks = None):
    """
    Collect pod data from Kubernetes cluster and store in database.
    """
    try:
        pods_data = await k8s_client.get_pods(namespace)
        
        if background_tasks:
            background_tasks.add_task(store_pods_data, pods_data)
        
        return {
            "message": "Pod data collection started",
            "pods_count": len(pods_data),
            "namespace": namespace,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Failed to collect pods data: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/collect/services")
async def collect_services_data(namespace: Optional[str] = Query(None), background_tasks: BackgroundTasks = None):
    """
    Collect service data from Kubernetes cluster and store in database.
    """
    try:
        services_data = await k8s_client.get_services(namespace)
        
        if background_tasks:
            background_tasks.add_task(store_services_data, services_data)
        
        return {
            "message": "Service data collection started",
            "services_count": len(services_data),
            "namespace": namespace,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Failed to collect services data: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/collect/all")
async def collect_all_data(background_tasks: BackgroundTasks):
    """
    Collect all cluster data (nodes, pods, services) and store in database.
    """
    try:
        # Collect all data concurrently
        nodes_task = k8s_client.get_nodes()
        pods_task = k8s_client.get_pods()
        services_task = k8s_client.get_services()
        
        nodes_data, pods_data, services_data = await asyncio.gather(
            nodes_task, pods_task, services_task
        )
        
        # Store all data in background
        background_tasks.add_task(store_all_data, nodes_data, pods_data, services_data)
        
        return {
            "message": "Complete cluster data collection started",
            "nodes_count": len(nodes_data),
            "pods_count": len(pods_data),
            "services_count": len(services_data),
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Failed to collect all data: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# Background task functions (placeholder for now)
async def store_nodes_data(nodes_data: List[Dict[str, Any]]):
    """Store nodes data in database."""
    logger.info(f"Storing {len(nodes_data)} nodes in database")
    # TODO: Implement database storage

async def store_pods_data(pods_data: List[Dict[str, Any]]):
    """Store pods data in database."""
    logger.info(f"Storing {len(pods_data)} pods in database")
    # TODO: Implement database storage

async def store_services_data(services_data: List[Dict[str, Any]]):
    """Store services data in database."""
    logger.info(f"Storing {len(services_data)} services in database")
    # TODO: Implement database storage

async def store_all_data(nodes_data: List[Dict[str, Any]], pods_data: List[Dict[str, Any]], services_data: List[Dict[str, Any]]):
    """Store all cluster data in database."""
    logger.info(f"Storing cluster data: {len(nodes_data)} nodes, {len(pods_data)} pods, {len(services_data)} services")
    # TODO: Implement database storage
