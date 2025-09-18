-- yoyo-migrations
-- Migration: create_database
-- Description: Create the homelab_command_center database and initial tables
-- File: 01_create_database.sql

-- Create initial tables for the HomeLab Command Center

-- Nodes table - stores Kubernetes node information
CREATE TABLE IF NOT EXISTS nodes (
    id VARCHAR(255) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name VARCHAR(255) UNIQUE NOT NULL,
    status VARCHAR(50) NOT NULL,
    role VARCHAR(50) NOT NULL,
    version VARCHAR(100),
    os_image VARCHAR(255),
    kernel_version VARCHAR(100),
    container_runtime VARCHAR(100),
    cpu_capacity VARCHAR(50),
    memory_capacity VARCHAR(50),
    cpu_allocatable VARCHAR(50),
    memory_allocatable VARCHAR(50),
    conditions JSONB,
    labels JSONB,
    annotations JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Pods table - stores Kubernetes pod information
CREATE TABLE IF NOT EXISTS pods (
    id VARCHAR(255) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name VARCHAR(255) NOT NULL,
    namespace VARCHAR(255) NOT NULL,
    node_name VARCHAR(255),
    status VARCHAR(50) NOT NULL,
    phase VARCHAR(50) NOT NULL,
    restart_count INTEGER DEFAULT 0,
    ready BOOLEAN DEFAULT FALSE,
    containers JSONB,
    labels JSONB,
    annotations JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Services table - stores Kubernetes service information
CREATE TABLE IF NOT EXISTS services (
    id VARCHAR(255) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name VARCHAR(255) NOT NULL,
    namespace VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    cluster_ip VARCHAR(50),
    external_ips JSONB,
    ports JSONB,
    selector JSONB,
    labels JSONB,
    annotations JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Cluster stats table - stores aggregated cluster statistics
CREATE TABLE IF NOT EXISTS cluster_stats (
    id VARCHAR(255) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_nodes INTEGER DEFAULT 0,
    ready_nodes INTEGER DEFAULT 0,
    total_pods INTEGER DEFAULT 0,
    running_pods INTEGER DEFAULT 0,
    pending_pods INTEGER DEFAULT 0,
    failed_pods INTEGER DEFAULT 0,
    total_services INTEGER DEFAULT 0,
    cpu_usage_percent FLOAT,
    memory_usage_percent FLOAT,
    storage_usage_percent FLOAT,
    custom_metrics JSONB
);

-- Health checks table - stores health check results
CREATE TABLE IF NOT EXISTS health_checks (
    id VARCHAR(255) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    resource_type VARCHAR(50) NOT NULL,
    resource_name VARCHAR(255) NOT NULL,
    namespace VARCHAR(255),
    status VARCHAR(50) NOT NULL,
    message TEXT,
    details JSONB,
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_nodes_name ON nodes(name);
CREATE INDEX IF NOT EXISTS idx_nodes_status ON nodes(status);
CREATE INDEX IF NOT EXISTS idx_pods_namespace ON pods(namespace);
CREATE INDEX IF NOT EXISTS idx_pods_phase ON pods(phase);
CREATE INDEX IF NOT EXISTS idx_pods_node_name ON pods(node_name);
CREATE INDEX IF NOT EXISTS idx_services_namespace ON services(namespace);
CREATE INDEX IF NOT EXISTS idx_services_type ON services(type);
CREATE INDEX IF NOT EXISTS idx_cluster_stats_timestamp ON cluster_stats(timestamp);
CREATE INDEX IF NOT EXISTS idx_health_checks_resource_type ON health_checks(resource_type);
CREATE INDEX IF NOT EXISTS idx_health_checks_status ON health_checks(status);
CREATE INDEX IF NOT EXISTS idx_health_checks_checked_at ON health_checks(checked_at);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at columns
CREATE TRIGGER update_nodes_updated_at BEFORE UPDATE ON nodes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pods_updated_at BEFORE UPDATE ON pods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_services_updated_at BEFORE UPDATE ON services
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();