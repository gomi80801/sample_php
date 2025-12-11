FROM python:3.11-slim

WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy script
COPY push_cpu_metric.py .
RUN chmod +x push_cpu_metric.py

# Set environment
ENV PYTHONUNBUFFERED=1

CMD ["python3", "push_cpu_metric.py"]
