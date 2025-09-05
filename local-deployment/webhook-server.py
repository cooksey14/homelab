#!/usr/bin/env python3
"""
Webhook server for local Pi cluster deployment
This server runs on your local machine and receives webhooks from GitHub
"""

import os
import json
import subprocess
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import threading
import time

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        """Handle POST requests from GitHub webhooks"""
        try:
            # Parse the URL
            parsed_path = urlparse(self.path)
            
            if parsed_path.path == '/webhook':
                # Read the payload
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                
                # Parse JSON payload
                payload = json.loads(post_data.decode('utf-8'))
                
                # Check if this is a push to main branch
                if (payload.get('ref') == 'refs/heads/main' and 
                    payload.get('repository', {}).get('name') == 'homelab'):
                    
                    logger.info("Received push to main branch, triggering deployment")
                    
                    # Trigger deployment
                    self.trigger_deployment()
                    
                    # Send success response
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps({'status': 'success'}).encode())
                else:
                    logger.info("Ignoring webhook (not main branch or wrong repo)")
                    self.send_response(200)
                    self.end_headers()
            else:
                self.send_response(404)
                self.end_headers()
                
        except Exception as e:
            logger.error(f"Error handling webhook: {e}")
            self.send_response(500)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'error': str(e)}).encode())

    def trigger_deployment(self):
        """Trigger deployment to Pi cluster"""
        try:
            logger.info("Starting deployment to Pi cluster...")
            
            # Run deployment script
            result = subprocess.run([
                'ssh', '-i', '/Users/colin/pi/pi', 
                'pimaster@192.168.86.27',
                'cd /tmp && curl -L https://github.com/cooksey14/homelab/archive/main.tar.gz | tar -xz && cd homelab-main/k3s && ./deploy.sh'
            ], capture_output=True, text=True, timeout=300)
            
            if result.returncode == 0:
                logger.info("Deployment successful!")
                logger.info(f"Output: {result.stdout}")
            else:
                logger.error(f"Deployment failed: {result.stderr}")
                
        except Exception as e:
            logger.error(f"Error during deployment: {e}")

    def log_message(self, format, *args):
        """Override to use our logger"""
        logger.info(f"{self.address_string()} - {format % args}")

def run_webhook_server(port=8080):
    """Run the webhook server"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, WebhookHandler)
    
    logger.info(f"Webhook server running on port {port}")
    logger.info("Configure GitHub webhook URL: http://your-local-ip:8080/webhook")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down webhook server...")
        httpd.shutdown()

if __name__ == '__main__':
    run_webhook_server()
