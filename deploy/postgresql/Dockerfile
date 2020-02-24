FROM postgres
USER postgres
MAINTAINER Farsheed Ashouri
# Copy postgres config file into container

COPY postgresql.conf /etc/postgresql

# Override default postgres config file
EXPOSE 5432
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]
