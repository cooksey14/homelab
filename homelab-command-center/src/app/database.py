from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, String, Integer, Boolean, Float, DateTime, Text, JSON
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

# Create base class
Base = declarative_base()

# Database engine and session
from app.config import settings

engine = create_async_engine(settings.database_url, echo=False)
async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


# Database Models
class Node(Base):
    __tablename__ = "nodes"
    
    id = Column(String(255), primary_key=True)
    name = Column(String(255), unique=True, nullable=False)
    status = Column(String(50), nullable=False)
    role = Column(String(50), nullable=False)
    version = Column(String(100))
    os_image = Column(String(255))
    kernel_version = Column(String(100))
    container_runtime = Column(String(100))
    cpu_capacity = Column(String(50))
    memory_capacity = Column(String(50))
    cpu_allocatable = Column(String(50))
    memory_allocatable = Column(String(50))
    conditions = Column(JSON)
    labels = Column(JSON)
    annotations = Column(JSON)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Pod(Base):
    __tablename__ = "pods"
    
    id = Column(String(255), primary_key=True)
    name = Column(String(255), nullable=False)
    namespace = Column(String(255), nullable=False)
    node_name = Column(String(255))
    status = Column(String(50), nullable=False)
    phase = Column(String(50), nullable=False)
    restart_count = Column(Integer, default=0)
    ready = Column(Boolean, default=False)
    containers = Column(JSON)
    labels = Column(JSON)
    annotations = Column(JSON)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Service(Base):
    __tablename__ = "services"
    
    id = Column(String(255), primary_key=True)
    name = Column(String(255), nullable=False)
    namespace = Column(String(255), nullable=False)
    type = Column(String(50), nullable=False)
    cluster_ip = Column(String(50))
    external_ips = Column(JSON)
    ports = Column(JSON)
    selector = Column(JSON)
    labels = Column(JSON)
    annotations = Column(JSON)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class ClusterStats(Base):
    __tablename__ = "cluster_stats"
    
    id = Column(String(255), primary_key=True)
    timestamp = Column(DateTime, default=datetime.utcnow)
    total_nodes = Column(Integer, default=0)
    ready_nodes = Column(Integer, default=0)
    total_pods = Column(Integer, default=0)
    running_pods = Column(Integer, default=0)
    pending_pods = Column(Integer, default=0)
    failed_pods = Column(Integer, default=0)
    total_services = Column(Integer, default=0)
    cpu_usage_percent = Column(Float)
    memory_usage_percent = Column(Float)
    storage_usage_percent = Column(Float)
    custom_metrics = Column(JSON)


class HealthCheck(Base):
    __tablename__ = "health_checks"
    
    id = Column(String(255), primary_key=True)
    resource_type = Column(String(50), nullable=False)
    resource_name = Column(String(255), nullable=False)
    namespace = Column(String(255))
    status = Column(String(50), nullable=False)
    message = Column(Text)
    details = Column(JSON)
    checked_at = Column(DateTime, default=datetime.utcnow)


async def get_db() -> AsyncSession:
    """Get database session."""
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()


async def init_db():
    """Initialize database tables."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)