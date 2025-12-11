FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .

# Set environment variables
ENV PORT=8080
ENV PYTHONUNBUFFERED=1

EXPOSE 8080

# Use gunicorn with proper configuration for Cloud Run
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "--threads", "4", "--timeout", "0", "--access-logfile", "-", "--error-logfile", "-", "main:app"]
