FROM kong:3.9.1
# NOTE: kong.yml is generated at runtime by entrypoint.sh from env vars.
# Do NOT COPY a static kong.yml — the declarative config is rendered
# from Railway private domain references (AUTH_HOST, REST_HOST, etc.)
# which are only available at deploy time, not build time.
USER root
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
USER kong
ENTRYPOINT ["/entrypoint.sh"]
