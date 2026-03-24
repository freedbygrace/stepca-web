# Base image
FROM python:3.12-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Default auth configuration (override at runtime)
ENV AUTH_BACKEND=local \
    ADMIN_USER=admin \
    ADMIN_PASSWORD=admin

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    libpq-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy the entire project
COPY . .

# Make entrypoint executable
RUN chmod +x /app/docker-entrypoint.sh

# Expose port (Flask default)
EXPOSE 5000

# Entrypoint configures auth, then runs CMD
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--threads", "4", "--access-logfile", "-", "run:app"]
