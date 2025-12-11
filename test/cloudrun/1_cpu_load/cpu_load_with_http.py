#!/usr/bin/env python3
"""
CPU Load Generator with HTTP server for Cloud Run compatibility
Supports: 75%, 85%, 95% CPU targets via CPU_TARGET env variable
"""
import multiprocessing
import time
import os
import math
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading
import socket
import psutil

# Import the existing CPU load logic
from cpu_load import get_container_cpu_quota, cpu_load_worker

# Global flag to track if CPU load should start
cpu_load_ready = threading.Event()

def get_container_cpu_usage():
    """Get actual CPU usage from cgroup"""
    try:
        # Try cgroup v2
        if os.path.exists('/sys/fs/cgroup/cpu.stat'):
            with open('/sys/fs/cgroup/cpu.stat', 'r') as f:
                for line in f:
                    if line.startswith('usage_usec'):
                        return int(line.split()[1]) / 1000000  # Convert to seconds
        
        # Try cgroup v1
        if os.path.exists('/sys/fs/cgroup/cpuacct/cpuacct.usage'):
            with open('/sys/fs/cgroup/cpuacct/cpuacct.usage', 'r') as f:
                return int(f.read().strip()) / 1000000000  # Convert nanoseconds to seconds
    except:
        pass
    return None

def calculate_cpu_percent(interval=1.0):
    """Calculate CPU percentage over an interval using cgroup data"""
    usage1 = get_container_cpu_usage()
    if usage1 is None:
        # Fallback to psutil if cgroup not available
        return psutil.cpu_percent(interval=interval)
    
    time.sleep(interval)
    
    usage2 = get_container_cpu_usage()
    if usage2 is None:
        return psutil.cpu_percent(interval=0)
    
    # Calculate CPU percentage
    cpu_quota = get_container_cpu_quota()
    if cpu_quota:
        cpu_cores = cpu_quota
    else:
        cpu_cores = multiprocessing.cpu_count()
    
    # Calculate percentage
    usage_diff = usage2 - usage1
    cpu_percent = (usage_diff / interval / cpu_cores) * 100
    
    return min(100, max(0, cpu_percent))

class HealthCheckHandler(BaseHTTPRequestHandler):
    """Simple HTTP handler for Cloud Run health checks"""
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/health' or self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            
            # Get current status
            target_percentage = int(os.getenv('CPU_TARGET', '50'))
            
            # Get CPU info
            cpu_limit_env = os.getenv('CPU_LIMIT')
            container_cpu = None
            if cpu_limit_env:
                cpu_count = float(cpu_limit_env)
            else:
                container_cpu = get_container_cpu_quota()
                cpu_count = container_cpu if container_cpu else multiprocessing.cpu_count()
            
            # Calculate target load
            target_processes_float = cpu_count * target_percentage / 100
            
            # Get memory info
            mem_limit = "N/A"
            mem_usage = "N/A"
            try:
                mem_info = psutil.virtual_memory()
                mem_limit = f"{mem_info.total / (1024**3):.2f} GB"
                mem_usage = f"{mem_info.percent:.1f}%"
            except:
                pass
            
            # Get actual CPU usage (average over 1 second)
            cpu_usage_percent = "N/A"
            try:
                # Get CPU percentage over 1 second interval from cgroup
                cpu_percent_val = calculate_cpu_percent(interval=1.0)
                cpu_usage_percent = f"{cpu_percent_val:.1f}%"
            except:
                pass
            
            # Get environment variables
            startup_delay = os.getenv('STARTUP_DELAY', 'Not set')
            port = os.getenv('PORT', '8080')
            k_service = os.getenv('K_SERVICE', 'Not in Cloud Run')
            k_revision = os.getenv('K_REVISION', 'N/A')
            k_configuration = os.getenv('K_CONFIGURATION', 'N/A')
            
            # Try to get metadata from Cloud Run metadata server
            project_id = "N/A"
            region = "N/A"
            service_url = "N/A"
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
                    # Try to extract from K_SERVICE env
                    if k_service != 'Not in Cloud Run':
                        # Region might be in service URL
                        pass
                
            except Exception as e:
                pass
            
            # Build HTML response
            html = f"""<!DOCTYPE html>
<html>
<head>
    <title>CPU Load Generator</title>
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
    <h1>⚡ CPU Load Generator - Status Dashboard</h1>
    
    <div class="section">
        <h2>🎯 Target Configuration</h2>
        <p><span class="label">CPU Target:</span> <span class="highlight">{target_percentage}%</span></p>
        <p><span class="label">Target Load:</span> <span class="value">{target_processes_float:.2f} cores</span></p>
        <p><span class="label">Actual CPU Usage:</span> <span class="highlight">{cpu_usage_percent}</span></p>
    </div>
    
    <div class="section">
        <h2>💻 Resource Limits</h2>
        <p><span class="label">CPU Cores:</span> <span class="value">{cpu_count:.2f} cores</span></p>
        <p><span class="label">CPU Type:</span> <span class="value">{"Container (cgroup limited)" if container_cpu else "Host (no limit)"}</span></p>
        <p><span class="label">Memory Limit:</span> <span class="value">{mem_limit}</span></p>
        <p><span class="label">Memory Usage:</span> <span class="value">{mem_usage}</span></p>
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
    # Get target CPU percentage from environment variable (REQUIRED)
    target_percentage = int(os.getenv('CPU_TARGET', '0'))
    
    # Validate target percentage
    if target_percentage not in [75, 85, 95]:
        print(f"[{datetime.now()}] ERROR: CPU_TARGET must be set to 75, 85, or 95")
        print(f"[{datetime.now()}] Current value: {target_percentage}")
        raise ValueError("Invalid CPU_TARGET. Must be 75, 85, or 95")
    
    print(f"[{datetime.now()}] ===== CPU Load Generator Started (Cloud Run Mode) =====")
    print(f"[{datetime.now()}] Target: {target_percentage}% CPU utilization")
    
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
    
    # Additional delay before CPU load (configurable)
    startup_delay = int(os.getenv('STARTUP_DELAY', '10'))
    if startup_delay > 0:
        print(f"[{datetime.now()}] Delaying {startup_delay}s before starting CPU load...")
        print(f"[{datetime.now()}] (This ensures Cloud Run health check passes first)")
        time.sleep(startup_delay)
    
    # Get CPU count (prioritize env variable, then container limits)
    cpu_limit_env = os.getenv('CPU_LIMIT')
    if cpu_limit_env:
        cpu_count = float(cpu_limit_env)
        print(f"[{datetime.now()}] Running in: CLOUD RUN (CPU_LIMIT env)")
        print(f"[{datetime.now()}] CPU limit from env: {cpu_count:.2f} cores")
    else:
        container_cpu_quota = get_container_cpu_quota()
        if container_cpu_quota:
            cpu_count = container_cpu_quota
            print(f"[{datetime.now()}] Running in: CONTAINER (with CPU limit)")
            print(f"[{datetime.now()}] Container CPU quota: {cpu_count:.2f} cores")
        else:
            cpu_count = multiprocessing.cpu_count()
            print(f"[{datetime.now()}] Running in: HOST (no container limit)")
            print(f"[{datetime.now()}] Detected {cpu_count} CPU cores")
    
    # Calculate target load
    target_processes_float = cpu_count * target_percentage / 100
    
    # Calculate number of processes needed
    # Round up to ensure we can reach the target
    # Example: 1.7 cores = 2 processes (1 at 100%, 1 at 70%)
    target_processes = max(1, math.ceil(target_processes_float))
    
    # Calculate load per process
    # Distribute the target load across processes
    # Example: 1.7 cores / 2 processes = 0.85 load per process
    load_per_process = target_processes_float / target_processes
    
    print(f"[{datetime.now()}] Target CPU usage: {target_percentage}%")
    print(f"[{datetime.now()}] CPU count: {cpu_count:.2f}")
    print(f"[{datetime.now()}] Target load: {target_processes_float:.2f} cores")
    print(f"[{datetime.now()}] Spawning {target_processes} process(es)")
    print(f"[{datetime.now()}] Load per process: {load_per_process*100:.1f}%")
    
    print(f"[{datetime.now()}] ===== Starting CPU Load Workers =====")
    
    # Create and start worker processes
    processes = []
    for i in range(target_processes):
        p = multiprocessing.Process(target=cpu_load_worker, args=(load_per_process,))
        p.start()
        processes.append(p)
        print(f"[{datetime.now()}] Started process {i+1}/{target_processes} (PID: {p.pid})")
    
    print(f"[{datetime.now()}] ===== All processes started successfully =====")
    print(f"[{datetime.now()}] HTTP server listening on port {port}")
    print(f"[{datetime.now()}] Press Ctrl+C to stop")
    
    try:
        # Keep main process alive
        for p in processes:
            p.join()
    except KeyboardInterrupt:
        print(f"\n[{datetime.now()}] Stopping all processes...")
        for p in processes:
            p.terminate()
            p.join()
        print(f"[{datetime.now()}] All processes stopped")

if __name__ == "__main__":
    main()
