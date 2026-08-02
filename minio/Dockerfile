# MinIO is a plain upstream image — no custom Dockerfile needed.
# Using a placeholder Dockerfile for consistency with template structure.
FROM minio/minio:RELEASE.2024-11-07T00-52-20Z
EXPOSE 9000 9001
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:9000/minio/health/live || exit 1
