#!/usr/bin/env python3
"""
Polling deployer for local Pi cluster
This script runs on your Pi and polls GitHub for changes
"""

import os
import json
import subprocess
import logging
import time
import requests
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/polling-deployer.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class PollingDeployer:
    def __init__(self, repo_owner, repo_name, branch='main', poll_interval=300):
        self.repo_owner = repo_owner
        self.repo_name = repo_name
        self.branch = branch
        self.poll_interval = poll_interval
        self.last_commit = None
        self.github_token = os.getenv('GITHUB_TOKEN')  # Optional for rate limiting
        
    def get_latest_commit(self):
        """Get the latest commit SHA from GitHub API"""
        try:
            url = f"https://api.github.com/repos/{self.repo_owner}/{self.repo_name}/commits/{self.branch}"
            headers = {}
            if self.github_token:
                headers['Authorization'] = f'token {self.github_token}'
            
            response = requests.get(url, headers=headers, timeout=10)
            response.raise_for_status()
            
            commit_data = response.json()
            return commit_data['sha']
            
        except Exception as e:
            logger.error(f"Error fetching latest commit: {e}")
            return None
    
    def download_and_deploy(self):
        """Download the latest code and deploy"""
        try:
            logger.info("Downloading latest code from GitHub...")
            
            # Create temporary directory
            temp_dir = "/tmp/gitops-deploy"
            os.makedirs(temp_dir, exist_ok=True)
            
            # Download and extract the repository
            download_cmd = [
                'curl', '-L', 
                f'https://github.com/{self.repo_owner}/{self.repo_name}/archive/{self.branch}.tar.gz',
                '|', 'tar', '-xz', '-C', temp_dir
            ]
            
            result = subprocess.run(' '.join(download_cmd), shell=True, 
                                 capture_output=True, text=True, timeout=60)
            
            if result.returncode != 0:
                logger.error(f"Failed to download repository: {result.stderr}")
                return False
            
            # Find the extracted directory
            extracted_dir = None
            for item in os.listdir(temp_dir):
                if item.startswith(f'{self.repo_name}-'):
                    extracted_dir = os.path.join(temp_dir, item)
                    break
            
            if not extracted_dir:
                logger.error("Could not find extracted repository directory")
                return False
            
            # Run deployment
            k3s_dir = os.path.join(extracted_dir, 'k3s')
            if os.path.exists(k3s_dir):
                logger.info("Running deployment script...")
                
                deploy_cmd = ['bash', '-c', f'cd {k3s_dir} && ./deploy.sh']
                result = subprocess.run(deploy_cmd, capture_output=True, text=True, timeout=300)
                
                if result.returncode == 0:
                    logger.info("Deployment successful!")
                    logger.info(f"Output: {result.stdout}")
                    return True
                else:
                    logger.error(f"Deployment failed: {result.stderr}")
                    return False
            else:
                logger.error(f"K3s directory not found: {k3s_dir}")
                return False
                
        except Exception as e:
            logger.error(f"Error during deployment: {e}")
            return False
        finally:
            # Clean up temporary directory
            try:
                subprocess.run(['rm', '-rf', temp_dir], timeout=10)
            except:
                pass
    
    def run(self):
        """Main polling loop"""
        logger.info(f"Starting polling deployer for {self.repo_owner}/{self.repo_name}")
        logger.info(f"Polling every {self.poll_interval} seconds")
        
        while True:
            try:
                latest_commit = self.get_latest_commit()
                
                if latest_commit and latest_commit != self.last_commit:
                    logger.info(f"New commit detected: {latest_commit}")
                    
                    if self.download_and_deploy():
                        self.last_commit = latest_commit
                        logger.info("Deployment completed successfully")
                    else:
                        logger.error("Deployment failed")
                elif latest_commit:
                    logger.debug(f"No new commits (current: {latest_commit})")
                else:
                    logger.warning("Could not fetch latest commit")
                
                time.sleep(self.poll_interval)
                
            except KeyboardInterrupt:
                logger.info("Polling deployer stopped by user")
                break
            except Exception as e:
                logger.error(f"Error in polling loop: {e}")
                time.sleep(60)  # Wait before retrying

def main():
    # Configuration
    REPO_OWNER = "cooksey14"
    REPO_NAME = "homelab"
    POLL_INTERVAL = 300  # 5 minutes
    
    deployer = PollingDeployer(REPO_OWNER, REPO_NAME, poll_interval=POLL_INTERVAL)
    deployer.run()

if __name__ == '__main__':
    main()
