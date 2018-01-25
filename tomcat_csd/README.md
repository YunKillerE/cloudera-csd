
Usage:

```sh
mvn clean package && scp target/IGNITE-5.12.0.jar vmuat-cm01:/opt/cloudera/csd/
```

Then, on CM node

```sh
service cloudera-scm-server restart && while true; do grep IGNITE /var/log/cloudera-scm-server/cloudera-scm-server.log | tail -n2; netstat -an | grep 7180 | grep LIST; sleep 1; done
```

