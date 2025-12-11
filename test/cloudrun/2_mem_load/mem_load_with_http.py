#!/usr/bin/env python3
"""
Memory Load Generator with HTTP server for Cloud Run compatibility
Supports: 75%, 85%, 95% memory targets via MEMORY_TARGET env variable
"""
import psutil
import time
import os
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading
import socket

# Import the existing memory load logic
from memory_load import MemoryLoadGenerator

class HealthCheckHandler(BaseHTTPRequestHandler):
    """Simple HTTP handler for Cloud Run health checks"""
    
    # Store generator instance as class variable
    generator = None
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/health' or self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            
            # Get current status
            target_percentage = int(os.getenv('MEMORY_TARGET', '50'))
            
            # Get memory info from generator (which reads from cgroup)
            if HealthCheckHandler.generator:
                mem_info = HealthCheckHandler.generator.get_memory_info()
                mem_total = f"{mem_info['total'] / (1024**3):.2f} GB"
                mem_used = f"{mem_info['used'] / (1024**3):.2f} GB"
                mem_available = f"{mem_info['available'] / (1024**3):.2f} GB"
                mem_percent = f"{mem_info['percent']:.1f}%"
                is_container = mem_info['is_container']
                
                # Get allocated memory from generator
                allocated_memory = "N/A"
                try:
                    allocated_mb = len(HealthCheckHandler.generator.data_blocks) * HealthCheckHandler.generator.block_size if hasattr(HealthCheckHandler.generator, 'data_blocks') else 0
                    allocated_memory = f"{allocated_mb / (1024**3):.2f} GB"
                except:
                    pass
            else:
                # Fallback to psutil
                mem = psutil.virtual_memory()
                mem_total = f"{mem.total / (1024**3):.2f} GB"
                mem_used = f"{mem.used / (1024**3):.2f} GB"
                mem_available = f"{mem.available / (1024**3):.2f} GB"
                mem_percent = f"{mem.percent:.1f}%"
                is_container = False
                allocated_memory = "N/A"
            
            # Get CPU info
            cpu_percent = "N/A"
            try:
                cpu_percent = f"{psutil.cpu_percent(interval=1):.1f}%"
            except:
                pass
            
            # Get environment variables
            startup_delay = os.getenv('STARTUP_DELAY', 'Not set')
            memory_limit = os.getenv('MEMORY_LIMIT', 'Not set')
            port = os.getenv('PORT', '8080')
            k_service = os.getenv('K_SERVICE', 'Not in Cloud Run')
            k_revision = os.getenv('K_REVISION', 'N/A')
            k_configuration = os.getenv('K_CONFIGURATION', 'N/A')
            
            # Try to get metadata from Cloud Run metadata server
            project_id = "N/A"
            region = "N/A"
            instance_id = "N/A"
            try:
                import urllib.request
                import json
                
                # Set metadata server headers
                headers = {'Metadata-Flavor': 'Google'}
                
                # Get project ID
                try:
                    req = urllib.request.Request(
                        'http://metadata.google.internal/computeMetadata/v1/project/project-id',
                        headers=headers
                    )
                    with urllib.request.urlopen(req, timeout=1) as response:
                        project_id = response.read().decode()
                except:
                    pass
                
                # Get instance ID
                try:
                    req = urllib.request.Request(
                        'http://metadata.google.internal/computeMetadata/v1/instance/id',
                        headers=headers
                    )
                    with urllib.request.urlopen(req, timeout=1) as response:
                        instance_id = response.read().decode()
                except:
                    pass
                
                # Get region from zone
                try:
                    req = urllib.request.Request(
                        'http://metadata.google.internal/computeMetadata/v1/instance/region',
                        headers=headers
                    )
                    with urllib.request.urlopen(req, timeout=1) as response:
                        region_path = response.read().decode()
                        region = region_path.split('/')[-1] if '/' in region_path else region_path
                except:
                    pass
                
            except Exception as e:
                pass
            
            # Build HTML response
            html = f"""<!DOCTYPE html>
<html>
<head>
    <title>Memory Load Generator</title>
    <meta http-equiv="refresh" content="10">
    <style>
        body {{ font-family: monospace; background: #1e1e1e; color: #00ff00; padding: 20px; }}
        h1 {{ color: #00ff00; border-bottom: 2px solid #00ff00; }}
        .section {{ margin: 20px 0; padding: 15px; border: 1px solid #00ff00; background: #2d2d2d; }}
        .label {{ color: #ffff00; font-weight: bold; }}
        .value {{ color: #00ffff; }}
        .highlight {{ color: #ff00ff; font-size: 1.2em; font-weight: bold; }}
    </style>
</head>
<body>
    <h1>💾 Memory Load Generator - Status Dashboard</h1>
    
    <div class="section">
        <h2>🎯 Target Configuration</h2>
        <p><span class="label">Memory Target:</span> <span class="highlight">{target_percentage}%</span></p>
        <p><span class="label">Actual Memory Usage:</span> <span class="highlight">{mem_percent}</span></p>
        <p><span class="label">Allocated by Generator:</span> <span class="value">{allocated_memory}</span></p>
    </div>
    
    <div class="section">
        <h2>💻 Memory Information</h2>
        <p><span class="label">Total Memory:</span> <span class="value">{mem_total}</span></p>
        <p><span class="label">Used Memory:</span> <span class="value">{mem_used}</span></p>
        <p><span class="label">Available Memory:</span> <span class="value">{mem_available}</span></p>
        <p><span class="label">Memory Source:</span> <span class="value">{"Container (cgroup)" if is_container else "Host (no limit)"}</span></p>
        <p><span class="label">Memory Limit (Config):</span> <span class="value">{memory_limit} MB</span></p>
        <p><span class="label">CPU Usage:</span> <span class="value">{cpu_percent}</span></p>
    </div>
    
    <div class="section">
        <h2>🔧 Runtime Configuration</h2>
        <p><span class="label">Startup Delay:</span> <span class="value">{startup_delay}s</span></p>
        <p><span class="label">HTTP Port:</span> <span class="value">{port}</span></p>
        <p><span class="label">Service Name:</span> <span class="value">{k_service}</span></p>
        <p><span class="label">Revision:</span> <span class="value">{k_revision}</span></p>
        <p><span class="label">Configuration:</span> <span class="value">{k_configuration}</span></p>
    </div>
    
    <div class="section">
        <h2>☁️ Cloud Run Metadata</h2>
        <p><span class="label">Project ID:</span> <span class="value">{project_id}</span></p>
        <p><span class="label">Region:</span> <span class="value">{region}</span></p>
        <p><span class="label">Instance ID:</span> <span class="value">{instance_id}</span></p>
    </div>
    
    <div class="section">
        <h2>📊 Process Information</h2>
        <p><span class="label">Active Processes:</span> <span class="value">{len([p for p in psutil.process_iter() if 'python' in p.name().lower()])} Python processes</span></p>
        <p><span class="label">Main PID:</span> <span class="value">{os.getpid()}</span></p>
    </div>
    
    <p style="color: #666; margin-top: 30px; text-align: center;">
        Auto-refresh every 10 seconds | Current time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
    </p>
</body>
</html>"""
            
            self.wfile.write(html.encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Suppress default logging"""
        pass

def start_http_server(port=8080):
    """Start HTTP server for Cloud Run"""
    try:
        server = HTTPServer(('0.0.0.0', port), HealthCheckHandler)
        print(f"[{datetime.now()}] ✅ HTTP server bound to port {port}")
        print(f"[{datetime.now()}] ✅ Ready to accept health checks")
        server.serve_forever()
    except Exception as e:
        print(f"[{datetime.now()}] ❌ Failed to start HTTP server: {e}")
        raise

def wait_for_port(port, timeout=10):
    """Wait for port to be available"""
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(1)
                result = s.connect_ex(('127.0.0.1', port))
                if result == 0:
                    return True
        except:
            pass
        time.sleep(0.1)
    return False

def main():
    """Main function"""
    # Get target memory percentage from environment variable (REQUIRED)
    target_percentage = int(os.getenv('MEMORY_TARGET', '0'))
    
    # Validate target percentage
    if target_percentage not in [75, 85, 95]:
        print(f"[{datetime.now()}] ERROR: MEMORY_TARGET must be set to 75, 85, or 95")
        print(f"[{datetime.now()}] Current value: {target_percentage}")
        raise ValueError("Invalid MEMORY_TARGET. Must be 75, 85, or 95")
    
    print(f"[{datetime.now()}] ===== Memory Load Generator Started (Cloud Run Mode) =====")
    print(f"[{datetime.now()}] Target: {target_percentage}% Memory utilization")
    
    # Get PORT from environment (Cloud Run sets this)
    port = int(os.environ.get('PORT', 8080))
    print(f"[{datetime.now()}] Port: {port}")
    
    # Start HTTP server in background thread (MUST be ready immediately)
    http_thread = threading.Thread(target=start_http_server, args=(port,), daemon=True)
    http_thread.start()
    
    print(f"[{datetime.now()}] HTTP server starting on port {port}...")
    
    # Wait for HTTP server to actually be listening
    print(f"[{datetime.now()}] Waiting for HTTP server to bind...")
    if wait_for_port(port, timeout=10):
        print(f"[{datetime.now()}] ✅ HTTP server is ready and listening on port {port}")
    else:
        print(f"[{datetime.now()}] ❌ HTTP server failed to start in time!")
        return
    
    # Additional delay before memory load (configurable)
    startup_delay = int(os.getenv('STARTUP_DELAY', '10'))
    if startup_delay > 0:
        print(f"[{datetime.now()}] Delaying {startup_delay}s before starting memory allocation...")
        print(f"[{datetime.now()}] (This ensures Cloud Run health check passes first)")
        time.sleep(startup_delay)
    
    # Get memory limit
    memory_limit = os.getenv('MEMORY_LIMIT', '512')
    print(f"[{datetime.now()}] Memory limit: {memory_limit} MB")
    
    # Get total memory
    mem = psutil.virtual_memory()
    total_memory_gb = mem.total / (1024**3)
    print(f"[{datetime.now()}] Total system memory: {total_memory_gb:.2f} GB")
    
    print(f"[{datetime.now()}] Target memory usage: {target_percentage}%")
    
    # Create memory load generator
    print(f"[{datetime.now()}] ===== Starting Memory Allocation =====")
    generator = MemoryLoadGenerator(target_percentage=target_percentage)
    
    # Store generator instance for health check handler
    HealthCheckHandler.generator = generator
    
    print(f"[{datetime.now()}] Starting memory allocation to reach {target_percentage}% usage...")
    print(f"[{datetime.now()}] ===== Memory allocation in progress =====")
    print(f"[{datetime.now()}] HTTP server listening on port {port}")
    print(f"[{datetime.now()}] Press Ctrl+C to stop")
    
    try:
        # Run the generator
        generator.run()
    except KeyboardInterrupt:
        print(f"\n[{datetime.now()}] Stopping memory load generator...")
        print(f"[{datetime.now()}] Generator stopped")

if __name__ == "__main__":
    main()
