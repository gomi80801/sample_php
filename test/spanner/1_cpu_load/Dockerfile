FROM python:3.11-slim

WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY cpu_load.py .
COPY cpu_load_with_http.py .

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Run the HTTP server version
CMD ["python", "cpu_load_with_http.py"]
