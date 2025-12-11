#!/usr/bin/env python3
"""
Push Custom CPU Metrics to Google Cloud Monitoring for Spanner
Simulates CPU usage at 75% and pushes to Cloud Monitoring every 5 seconds
"""
import time
from google.cloud import monitoring_v3
from google.api import metric_pb2 as ga_metric
from google.api import label_pb2 as ga_label
import os
from datetime import datetime

class SpannerCPUMetricPusher:
    def __init__(self, project_id, instance_id, cpu_percentage=75):
        """
        Initialize metric pusher
        
        Args:
            project_id: GCP project ID
            instance_id: Spanner instance ID
            cpu_percentage: CPU usage percentage to report (default: 75)
        """
        self.project_id = project_id
        self.instance_id = instance_id
        self.cpu_percentage = cpu_percentage
        self.client = monitoring_v3.MetricServiceClient()
        self.project_name = f"projects/{project_id}"
        
    def create_custom_metric_descriptor(self):
        """Create custom metric descriptor if not exists"""
        descriptor = ga_metric.MetricDescriptor()
        descriptor.type = "custom.googleapis.com/spanner/cpu_utilization_simulated"
        descriptor.metric_kind = ga_metric.MetricDescriptor.MetricKind.GAUGE
        descriptor.value_type = ga_metric.MetricDescriptor.ValueType.DOUBLE
        descriptor.description = "Simulated Spanner CPU utilization percentage"
        descriptor.display_name = "Spanner CPU Utilization (Simulated)"
        
        # Add labels
        label = ga_label.LabelDescriptor()
        label.key = "instance_id"
        label.value_type = ga_label.LabelDescriptor.ValueType.STRING
        label.description = "Spanner instance ID"
        descriptor.labels.append(label)
        
        try:
            descriptor = self.client.create_metric_descriptor(
                name=self.project_name,
                metric_descriptor=descriptor
            )
            print(f"[{datetime.now()}] ✅ Created metric descriptor: {descriptor.type}")
        except Exception as e:
            if "already exists" in str(e).lower():
                print(f"[{datetime.now()}] ℹ️  Metric descriptor already exists")
            else:
                print(f"[{datetime.now()}] ⚠️  Error creating metric descriptor: {e}")
    
    def push_metric(self):
        """Push CPU metric to Cloud Monitoring"""
        # Create time series
        series = monitoring_v3.TimeSeries()
        series.metric.type = "custom.googleapis.com/spanner/cpu_utilization_simulated"
        series.metric.labels["instance_id"] = self.instance_id
        
        # Set resource (generic_node for custom metrics)
        series.resource.type = "global"
        
        # Create data point
        now = time.time()
        seconds = int(now)
        nanos = int((now - seconds) * 10 ** 9)
        interval = monitoring_v3.TimeInterval(
            {"end_time": {"seconds": seconds, "nanos": nanos}}
        )
        point = monitoring_v3.Point(
            {
                "interval": interval,
                "value": {"double_value": self.cpu_percentage},
            }
        )
        series.points = [point]
        
        # Push to Cloud Monitoring
        try:
            self.client.create_time_series(
                name=self.project_name,
                time_series=[series]
            )
            print(f"[{datetime.now()}] ✅ Pushed metric: CPU={self.cpu_percentage}% for instance={self.instance_id}")
            return True
        except Exception as e:
            print(f"[{datetime.now()}] ❌ Error pushing metric: {e}")
            return False
    
    def run(self, interval=5):
        """
        Run metric pusher continuously
        
        Args:
            interval: Interval in seconds between pushes (default: 5)
        """
        print(f"[{datetime.now()}] ===== Spanner CPU Metric Pusher Started =====")
        print(f"[{datetime.now()}] Project: {self.project_id}")
        print(f"[{datetime.now()}] Instance: {self.instance_id}")
        print(f"[{datetime.now()}] CPU Target: {self.cpu_percentage}%")
        print(f"[{datetime.now()}] Push Interval: {interval}s")
        print(f"[{datetime.now()}] ============================================")
        
        # Create metric descriptor on first run
        self.create_custom_metric_descriptor()
        
        try:
            while True:
                self.push_metric()
                time.sleep(interval)
        except KeyboardInterrupt:
            print(f"\n[{datetime.now()}] 🛑 Stopped by user")
        except Exception as e:
            print(f"\n[{datetime.now()}] ❌ Error: {e}")

def main():
    """Main function"""
    # Get configuration from environment variables
    project_id = os.getenv('GCP_PROJECT_ID')
    instance_id = os.getenv('SPANNER_INSTANCE_ID', 'test-instance')
    cpu_percentage = float(os.getenv('CPU_PERCENTAGE', '75'))
    interval = int(os.getenv('PUSH_INTERVAL', '5'))
    
    if not project_id:
        print("❌ Error: GCP_PROJECT_ID environment variable not set")
        print("Usage: export GCP_PROJECT_ID=your-project-id")
        exit(1)
    
    # Create and run pusher
    pusher = SpannerCPUMetricPusher(
        project_id=project_id,
        instance_id=instance_id,
        cpu_percentage=cpu_percentage
    )
    pusher.run(interval=interval)

if __name__ == "__main__":
    main()
