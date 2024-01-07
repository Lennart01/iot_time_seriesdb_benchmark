#cloud-config
users:
  - name: debian
    ssh-authorized-keys:
        - ${ssh_key}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash

write_files:
  - path: /home/debian/db_loadgen_timescale.sh
    content: |
      #!/bin/bash
      cd /home/debian/tsbs/bin/
      ./tsbs_generate_data --use-case="iot" --seed=123 --scale=4000 \
      --timestamp-start="2016-01-01T00:00:00Z" \
      --timestamp-end="2016-01-04T00:00:00Z" \
      --log-interval="10s" --format="timescaledb" \
      | ./tsbs_load_timescaledb \
      --host="ts-db.playground-daidalos-tests.fra.ics.inovex.io" --port=5432 --pass="mysecretpassword" \
      --user="myuser" --admin-db-name=mydb --workers=16  \
      --in-table-partition-tag=true --chunk-time=8h --write-profile= \
      --field-index-count=1 --do-create-db=true --force-text-format=false \
      --do-abort-on-exist=false | tee load.log
  - path: /home/debian/db_loadgen_influx_v1.sh
    content: |
      #!/bin/bash
      cd /home/debian/tsbs/bin/
      ./tsbs_generate_data --use-case="iot" --seed=123 --scale=4000 \
      --timestamp-start="2016-01-01T00:00:00Z" \
      --timestamp-end="2016-01-04T00:00:00Z" \
      --log-interval="10s" --format="influx" \
      | ./tsbs_load_influx \
      --urls="http://ts-db.playground-daidalos-tests.fra.ics.inovex.io:8086" --workers=16  \
      --do-create-db=true --do-abort-on-exist=false | tee load.log
  - path: /home/debian/db_loadgen_influx_v2.sh
    content: |
      #!/bin/bash
      cd /home/debian/tsbs_influx/bin/
      ./tsbs_generate_data --use-case="iot" --seed=123 --scale=4000 \
      --timestamp-start="2016-01-01T00:00:00Z" \
      --timestamp-end="2016-01-04T00:00:00Z" \
      --log-interval="10s" --format="influx" \
      | ./tsbs_load_influx \
      --urls="http://ts-db.playground-daidalos-tests.fra.ics.inovex.io:8086" --workers=16  \
      --do-create-db=true --do-abort-on-exist=false \
      --auth-token="admin-token" | tee load.log

  - path: /home/debian/tsbs_query_timescale.sh
    content: |
      #!/bin/bash
      cd /home/debian/tsbs/bin/
      ./tsbs_generate_queries --use-case="iot" --seed=123 --scale=4000 \
      --timestamp-start="2016-01-01T00:00:00Z" \
      --timestamp-end="2016-01-04T00:00:01Z" \
      --queries=1000 --query-type="breakdown-frequency" --format="timescaledb" \
      | ./tsbs_run_queries_timescaledb --workers=16 \
      --postgres="sslmode=disable" --user="myuser" --pass="mysecretpassword" \
      --hosts="ts-db.playground-daidalos-tests.fra.ics.inovex.io" | tee query.log
  - path: /home/debian/tsbs_query_influx_v1.sh
    content: |
      #!/bin/bash
      cd /home/debian/tsbs/bin/
      ./tsbs_generate_queries --use-case="iot" --seed=123 --scale=4000 \
      --timestamp-start="2016-01-01T00:00:00Z" \
      --timestamp-end="2016-01-04T00:00:01Z" \
      --queries=1000 --query-type="breakdown-frequency" --format="influx" \
      | ./tsbs_run_queries_influx --urls="http://ts-db.playground-daidalos-tests.fra.ics.inovex.io:8086" --workers=16 \
      | tee query.log

package_update: true
package_upgrade: true
packages:
  - curl
  - tmux
runcmd:
  - curl -fsSL https://get.docker.com -o get-docker.sh
  - sudo sh get-docker.sh
  - rm get-docker.sh
  - apt install make -y
  - wget https://go.dev/dl/go1.21.3.linux-amd64.tar.gz
  - rm -rf /usr/local/go && tar -C /usr/local -xzf go1.21.3.linux-amd64.tar.gz
  - rm go1.21.3.linux-amd64.tar.gz
  - export PATH=$PATH:/usr/local/go/bin
  - go version

  # set GOPATH and GO111MODULE
  - export GOPATH=/home/debian/go
  - export GO111MODULE=on

  # set GOCACHE
  - export GOCACHE=/home/debian/.cache/go-build
  

  # install tsbs
  - chmod +x /home/debian/db_loadgen_timescale.sh
  - chmod +x /home/debian/db_loadgen_influx_v1.sh
  - chmod +x /home/debian/db_loadgen_influx_v2.sh
  - chmod +x /home/debian/tsbs_query_timescale.sh
  - chmod +x /home/debian/tsbs_query_influx_v1.sh
  - cd /home/debian
  - git clone https://github.com/timescale/tsbs.git
  - git clone -b influx.v2  https://github.com/RedisTimeSeries/tsbs tsbs_influx
  - cd ./tsbs
  - go mod tidy
  - make
  - cd ../tsbs_influx
  - go mod tidy
  - make

  # install netdata
  - |
    curl https://my-netdata.io/kickstart.sh > /tmp/netdata-kickstart.sh && sh /tmp/netdata-kickstart.sh --nightly-channel --claim-token ${netdata_token} --claim-rooms ${netdata_room"} --claim-url https://app.netdata.cloud