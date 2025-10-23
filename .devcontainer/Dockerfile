# Devcontainer for Data Commons MCP development
FROM mcr.microsoft.com/devcontainers/python:3.11

# Install uv (fast Python package manager)
RUN pip install --no-cache-dir uv

WORKDIR /workspace
COPY . /workspace

# Install workspace in editable mode with test extras
RUN uv pip install -e .[test]

# Default command just opens shell
CMD ["bash"]
