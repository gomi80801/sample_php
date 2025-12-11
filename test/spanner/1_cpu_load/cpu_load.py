#!/usr/bin/env python3
"""
Spanner CPU Load Generator
Generates database load to push Spanner CPU to target levels (75%, 85%, 95%)
"""
from google.cloud import spanner
from google.cloud.spanner_v1 import param_types
import time
import random
import string
import os
import concurrent.futures
import threading
from datetime import datetime

class SpannerLoadGenerator:
    def __init__(self, project_id, instance_id, database_id, target_cpu_percent=75):
        """
        Initialize Spanner Load Generator
        
        Args:
            project_id: GCP project ID
            instance_id: Spanner instance ID
            database_id: Spanner database ID
            target_cpu_percent: Target CPU percentage (75, 85, or 95)
        """
        self.project_id = project_id
        self.instance_id = instance_id
        self.database_id = database_id
        self.target_cpu_percent = target_cpu_percent
        
        # Initialize Spanner client
        self.spanner_client = spanner.Client(project=project_id)
        self.instance = self.spanner_client.instance(instance_id)
        self.database = self.instance.database(database_id)
        
        # Load control parameters
        self.num_threads = self._calculate_threads()
        self.ops_per_second = self._calculate_ops_per_second()
        self.running = False
        
        print(f"[{datetime.now()}] Spanner Load Generator Initialized")
        print(f"[{datetime.now()}] Project: {project_id}")
        print(f"[{datetime.now()}] Instance: {instance_id}")
        print(f"[{datetime.now()}] Database: {database_id}")
        print(f"[{datetime.now()}] Target CPU: {target_cpu_percent}%")
        print(f"[{datetime.now()}] Threads: {self.num_threads}")
        print(f"[{datetime.now()}] Target ops/sec: {self.ops_per_second}")
    
    def _calculate_threads(self):
        """Calculate number of concurrent threads based on target CPU"""
        thread_map = {
            75: 10,
            85: 15,
            95: 25
        }
        return thread_map.get(self.target_cpu_percent, 10)
    
    def _calculate_ops_per_second(self):
        """Calculate operations per second based on target CPU"""
        ops_map = {
            75: 500,
            85: 1000,
            95: 2000
        }
        return ops_map.get(self.target_cpu_percent, 500)
    
    def setup_test_table(self):
        """Create test table if not exists"""
        print(f"[{datetime.now()}] Setting up test table...")
        
        ddl = """
        CREATE TABLE IF NOT EXISTS LoadTestData (
            id STRING(36) NOT NULL,
            timestamp TIMESTAMP NOT NULL,
            data STRING(1024),
            counter INT64,
            random_value FLOAT64
        ) PRIMARY KEY (id)
        """
        
        try:
            operation = self.database.update_ddl([ddl])
            operation.result(timeout=30)
            print(f"[{datetime.now()}] ✅ Test table ready")
        except Exception as e:
            print(f"[{datetime.now()}] Table already exists or error: {e}")
    
    def generate_random_string(self, length=1000):
        """Generate random string for data"""
        return ''.join(random.choices(string.ascii_letters + string.digits, k=length))
    
    def insert_operation(self):
        """Perform INSERT operation"""
        try:
            with self.database.batch() as batch:
                batch.insert(
                    table='LoadTestData',
                    columns=['id', 'timestamp', 'data', 'counter', 'random_value'],
                    values=[[
                        f"id-{random.randint(1, 1000000)}",
                        spanner.COMMIT_TIMESTAMP,
                        self.generate_random_string(),
                        random.randint(1, 1000),
                        random.random()
                    ]]
                )
        except Exception as e:
            pass  # Ignore errors for continuous load
    
    def read_operation(self):
        """Perform complex READ operation"""
        try:
            # Complex query with joins and aggregations
            query = """
                SELECT 
                    COUNT(*) as total,
                    AVG(counter) as avg_counter,
                    MAX(random_value) as max_random
                FROM LoadTestData
                WHERE counter > @min_counter
                LIMIT 1000
            """
            
            with self.database.snapshot() as snapshot:
                results = snapshot.execute_sql(
                    query,
                    params={'min_counter': random.randint(1, 500)},
                    param_types={'min_counter': param_types.INT64}
                )
                # Consume results
                for row in results:
                    pass
        except Exception as e:
            pass  # Ignore errors for continuous load
    
    def update_operation(self):
        """Perform UPDATE operation"""
        try:
            def update_in_transaction(transaction):
                row_ct = transaction.execute_update(
                    """
                    UPDATE LoadTestData 
                    SET counter = counter + 1,
                        random_value = @new_random
                    WHERE counter < @max_counter
                    LIMIT 100
                    """,
                    params={
                        'new_random': random.random(),
                        'max_counter': random.randint(500, 1000)
                    },
                    param_types={
                        'new_random': param_types.FLOAT64,
                        'max_counter': param_types.INT64
                    }
                )
                return row_ct
            
            self.database.run_in_transaction(update_in_transaction)
        except Exception as e:
            pass  # Ignore errors for continuous load
    
    def scan_operation(self):
        """Perform full table SCAN operation (CPU intensive)"""
        try:
            with self.database.snapshot() as snapshot:
                results = snapshot.read(
                    table='LoadTestData',
                    columns=['id', 'counter', 'random_value'],
                    keyset=spanner.KeySet(all_=True),
                    limit=1000
                )
                # Consume results
                for row in results:
                    pass
        except Exception as e:
            pass  # Ignore errors for continuous load
    
    def mixed_workload(self, thread_id):
        """Execute mixed workload with different operation types"""
        print(f"[{datetime.now()}] Thread {thread_id} started")
        
        ops_count = 0
        start_time = time.time()
        
        while self.running:
            # Random operation mix
            operation_type = random.choices(
                ['insert', 'read', 'update', 'scan'],
                weights=[30, 40, 20, 10]  # Weighted distribution
            )[0]
            
            if operation_type == 'insert':
                self.insert_operation()
            elif operation_type == 'read':
                self.read_operation()
            elif operation_type == 'update':
                self.update_operation()
            elif operation_type == 'scan':
                self.scan_operation()
            
            ops_count += 1
            
            # Rate limiting - control ops per second per thread
            target_interval = self.num_threads / self.ops_per_second
            elapsed = time.time() - start_time
            expected_ops = elapsed / target_interval
            
            if ops_count > expected_ops:
                sleep_time = (ops_count - expected_ops) * target_interval
                if sleep_time > 0:
                    time.sleep(sleep_time)
        
        print(f"[{datetime.now()}] Thread {thread_id} stopped ({ops_count} operations)")
    
    def run(self, duration=None):
        """
        Start load generation
        
        Args:
            duration: Optional duration in seconds (None = run indefinitely)
        """
        print(f"[{datetime.now()}] ===== Starting Spanner Load Generation =====")
        self.running = True
        
        # Start worker threads
        with concurrent.futures.ThreadPoolExecutor(max_workers=self.num_threads) as executor:
            futures = []
            for i in range(self.num_threads):
                future = executor.submit(self.mixed_workload, i)
                futures.append(future)
            
            # Wait for duration or run indefinitely
            try:
                if duration:
                    time.sleep(duration)
                    print(f"[{datetime.now()}] Duration reached, stopping...")
                else:
                    # Run until interrupted
                    while True:
                        time.sleep(1)
            except KeyboardInterrupt:
                print(f"\n[{datetime.now()}] Stopping load generation...")
            finally:
                self.running = False
                # Wait for all threads to complete
                concurrent.futures.wait(futures)
        
        print(f"[{datetime.now()}] ===== Load generation stopped =====")

def main():
    """Main function"""
    # Get configuration from environment
    project_id = os.getenv('GCP_PROJECT_ID')
    instance_id = os.getenv('SPANNER_INSTANCE_ID')
    database_id = os.getenv('SPANNER_DATABASE_ID', 'loadtest')
    target_cpu = int(os.getenv('CPU_TARGET', '75'))
    
    if not project_id or not instance_id:
        print("ERROR: GCP_PROJECT_ID and SPANNER_INSTANCE_ID must be set")
        return
    
    if target_cpu not in [75, 85, 95]:
        print(f"ERROR: CPU_TARGET must be 75, 85, or 95 (got {target_cpu})")
        return
    
    print(f"[{datetime.now()}] ===== Spanner CPU Load Generator =====")
    
    # Create generator
    generator = SpannerLoadGenerator(
        project_id=project_id,
        instance_id=instance_id,
        database_id=database_id,
        target_cpu_percent=target_cpu
    )
    
    # Setup test table
    generator.setup_test_table()
    
    # Pre-populate with some data
    print(f"[{datetime.now()}] Pre-populating test data...")
    for i in range(100):
        generator.insert_operation()
    print(f"[{datetime.now()}] Pre-population complete")
    
    # Start load generation
    generator.run()

if __name__ == "__main__":
    main()
