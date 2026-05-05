# Use a lightweight Python image. Pull from the public ECR registry because Docker Hub is rate-limited.
FROM public.ecr.aws/docker/library/python:3.14-rc-slim@sha256:a4722702deceb57f9e99a23582857a7723598c6e2998dfa6e768d8ca9da53e77

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Install dependencies
RUN pip install --no-cache-dir flask

# Expose the port Flask will listen on
EXPOSE 80

# Run the app
CMD ["python", "app.py"]
