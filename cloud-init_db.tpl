#cloud-config
users:
  - name: debian
    ssh-authorized-keys:
        - ${ssh_key}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash

write_files:
  - path: /home/debian/timescale.docker-compose.yaml
    content: ${timescale_docker_compose}
    encoding: b64
    
  - path: /home/debian/influxdb_v1.docker-compose.yaml
    content: ${influxdb_v1_docker_compose}
    encoding: b64
  
  - path: /home/debian/influxdb_v2.docker-compose.yaml
    content: ${influxdb_v2_docker_compose}
    encoding: b64
  
  - path: /home/debian/init_influxdb_v2.sh
    content: |
      #!/bin/bash
      docker exec influxdb influx bucket create -n bucket-perf -o org -r 0
      bucket_id=$(docker exec influxdb influx bucket ls --name bucket-perf | awk 'NR==2 {print $1}')
      docker exec influxdb influx v1 dbrp create --db benchmark --rp 0 --bucket-id $bucket_id --default

package_update: true
package_upgrade: true
packages:
  - curl
runcmd:
  - curl -fsSL https://get.docker.com -o get-docker.sh
  - sudo sh get-docker.sh
  - rm get-docker.sh
  - echo "databse to deploy is ${ts_db_kind}"
  - export ts_db_kind=${ts_db_kind}
  - |
    if [ "$ts_db_kind" = "timescaledb" ]; then
    mv /home/debian/timescale.docker-compose.yaml /home/debian/docker-compose.yaml
    docker compose -f /home/debian/docker-compose.yaml up -d
    # increase max connections
    # sed -i 's/max_connections = 100/max_connections = 1000/g' /var/lib/docker/volumes/debian_timescaledb_data/_data/postgresql.conf
    docker exec -it timescaledb timescaledb-tune --yes
    docker restart timescaledb
    docker exec -it timescaledb psql -U myuser -d benchmark -c "CREATE USER monitoring WITH PASSWORD 'password';"
    docker exec -it timescaledb psql -U myuser -d benchmark -c "GRANT pg_read_all_stats to monitoring;"
    docker restart postgres-exporter
    fi
    if [ "$ts_db_kind" = "influxdb_v1" ]; then
    mv /home/debian/influxdb_v1.docker-compose.yaml /home/debian/docker-compose.yaml
    docker compose -f /home/debian/docker-compose.yaml up -d
    fi
    if [ "$ts_db_kind" = "influxdb_v2" ]; then
    mv /home/debian/influxdb_v2.docker-compose.yaml /home/debian/docker-compose.yaml
    docker compose -f /home/debian/docker-compose.yaml up -d
    sleep 10
    chmod +x /home/debian/init_influxdb_v2.sh
    sh /home/debian/init_influxdb_v2.sh
    fi

  # install netdata
  - |
    curl https://my-netdata.io/kickstart.sh > /tmp/netdata-kickstart.sh && sh /tmp/netdata-kickstart.sh --nightly-channel --claim-token ${netdata_token} --claim-rooms ${netdata_room"} --claim-url https://app.netdata.cloud