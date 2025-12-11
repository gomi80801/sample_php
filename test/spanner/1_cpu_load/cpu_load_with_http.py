#!/usr/bin/env python3
"""
Spanner Load Generator with HTTP server for Cloud Run deployment
Monitors and reports Spanner CPU/Memory usage
"""
from cpu_load import SpannerLoadGenerator
from google.cloud import monitoring_v3
import os
import time
import threading
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
import socket

# Global generator instance
generator = None
load_thread = None

class HealthCheckHandler(BaseHTTPRequestHandler):
    """HTTP handler for health checks and status"""
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/health' or self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            
            # Get configuration
            project_id = os.getenv('GCP_PROJECT_ID', 'N/A')
            instance_id = os.getenv('SPANNER_INSTANCE_ID', 'N/A')
            database_id = os.getenv('SPANNER_DATABASE_ID', 'loadtest')
            target_cpu = os.getenv('CPU_TARGET', '75')
            
            # Get Spanner metrics
            cpu_utilization = get_spanner_cpu_utilization(project_id, instance_id)
            
            # Get environment info
            k_service = os.getenv('K_SERVICE', 'Not in Cloud Run')
            k_revision = os.getenv('K_REVISION', 'N/A')
            
            # Build HTML response
            html = f"""<!DOCTYPE html>
<html>
<head>
    <title>Spanner Load Generator</title>
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
    <h1>🗄️ Spanner Load Generator - Status Dashboard</h1>
    
    <div class="section">
        <h2>🎯 Target Configuration</h2>
        <p><span class="label">CPU Target:</span> <span class="highlight">{target_cpu}%</span></p>
        <p><span class="label">Actual CPU Utilization:</span> <span class="highlight">{cpu_utilization}%</span></p>
        <p><span class="label">Load Generator Status:</span> <span class="value">{"Running" if generator and generator.running else "Stopped"}</span></p>
    </div>
    
    <div class="section">
        <h2>🗄️ Spanner Configuration</h2>
        <p><span class="label">Project ID:</span> <span class="value">{project_id}</span></p>
        <p><span class="label">Instance ID:</span> <span class="value">{instance_id}</span></p>
        <p><span class="label">Database ID:</span> <span class="value">{database_id}</span></p>
        <p><span class="label">Threads:</span> <span class="value">{generator.num_threads if generator else "N/A"}</span></p>
        <p><span class="label">Target Ops/Sec:</span> <span class="value">{generator.ops_per_second if generator else "N/A"}</span></p>
    </div>
    
    <div class="section">
        <h2>☁️ Cloud Run Info</h2>
        <p><span class="label">Service:</span> <span class="value">{k_service}</span></p>
        <p><span class="label">Revision:</span> <span class="value">{k_revision}</span></p>
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

def get_spanner_cpu_utilization(project_id, instance_id):
    """Get current Spanner CPU utilization from Cloud Monitoring"""
    try:
        client = monitoring_v3.MetricServiceClient()
        project_name = f"projects/{project_id}"
        
        # Query for high_priority_cpu_utilization
        interval = monitoring_v3.TimeInterval()
        now = time.time()
        interval.end_time.seconds = int(now)
        interval.start_time.seconds = int(now - 300)  # Last 5 minutes
        
        results = client.list_time_series(
            request={
                "name": project_name,
                "filter": f'metric.type="spanner.googleapis.com/instance/cpu/utilization" AND resource.labels.instance_id="{instance_id}"',
                "interval": interval,
                "view": monitoring_v3.ListTimeSeriesRequest.TimeSeriesView.FULL,
            }
        )
        
        # Get latest value
        for result in results:
            if result.points:
                latest_point = result.points[0]
                cpu_value = latest_point.value.double_value * 100
                return f"{cpu_value:.1f}"
        
        return "N/A"
    except Exception as e:
        print(f"[{datetime.now()}] Error getting Spanner metrics: {e}")
        return "N/A"

def start_http_server(port=8080):
    """Start HTTP server"""
    try:
        server = HTTPServer(('0.0.0.0', port), HealthCheckHandler)
        print(f"[{datetime.now()}] ✅ HTTP server listening on port {port}")
        server.serve_forever()
    except Exception as e:
        print(f"[{datetime.now()}] ❌ Failed to start HTTP server: {e}")

def run_load_generator():
    """Run load generator in background"""
    global generator
    
    try:
        project_id = os.getenv('GCP_PROJECT_ID')
        instance_id = os.getenv('SPANNER_INSTANCE_ID')
        database_id = os.getenv('SPANNER_DATABASE_ID', 'loadtest')
        target_cpu = int(os.getenv('CPU_TARGET', '75'))
        
        print(f"[{datetime.now()}] Initializing Spanner Load Generator...")
        generator = SpannerLoadGenerator(
            project_id=project_id,
            instance_id=instance_id,
            database_id=database_id,
            target_cpu_percent=target_cpu
        )
        
        print(f"[{datetime.now()}] Setting up test table...")
        generator.setup_test_table()
        
        print(f"[{datetime.now()}] Pre-populating test data...")
        for i in range(100):
            generator.insert_operation()
        
        print(f"[{datetime.now()}] Starting load generation...")
        generator.run()
    except Exception as e:
        print(f"[{datetime.now()}] ERROR in load generator: {e}")
        import traceback
        traceback.print_exc()

def main():
    """Main function"""
    global load_thread
    
    print(f"[{datetime.now()}] ===== Spanner Load Generator (Cloud Run Mode) =====")
    
    # Get port - HTTP server MUST start immediately
    port = int(os.getenv('PORT', 8080))
    
    print(f"[{datetime.now()}] Starting HTTP server on port {port}...")
    
    # Start HTTP server FIRST (daemon=True so it doesn't block)
    http_thread = threading.Thread(target=start_http_server, args=(port,), daemon=True)
    http_thread.start()
    
    # Give HTTP server time to bind
    time.sleep(2)
    print(f"[{datetime.now()}] ✅ HTTP server started")
    
    # Validate environment (after HTTP is up)
    project_id = os.getenv('GCP_PROJECT_ID')
    instance_id = os.getenv('SPANNER_INSTANCE_ID')
    target_cpu = int(os.getenv('CPU_TARGET', '75'))
    
    if not project_id or not instance_id:
        print(f"[{datetime.now()}] WARNING: GCP_PROJECT_ID and SPANNER_INSTANCE_ID not set")
        print(f"[{datetime.now()}] HTTP server running but load generator disabled")
    elif target_cpu not in [75, 85, 95]:
        print(f"[{datetime.now()}] WARNING: CPU_TARGET must be 75, 85, or 95 (got {target_cpu})")
        print(f"[{datetime.now()}] HTTP server running but load generator disabled")
    else:
        # Start load generator in background (after HTTP is confirmed up)
        print(f"[{datetime.now()}] Starting load generator in background...")
        load_thread = threading.Thread(target=run_load_generator, daemon=True)
        load_thread.start()
        print(f"[{datetime.now()}] ✅ Load generator thread started")
    
    print(f"[{datetime.now()}] ✅ All systems running")
    print(f"[{datetime.now()}] Press Ctrl+C to stop")
    
    try:
        # Keep main thread alive
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print(f"\n[{datetime.now()}] Shutting down...")
        if generator:
            generator.running = False

if __name__ == "__main__":
    main()
