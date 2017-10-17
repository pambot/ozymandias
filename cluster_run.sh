# start services
peg service ozy-cluster zookeeper start
peg service ozy-cluster kafka start &
peg service ozy-cluster hadoop start
peg service ozy-cluster spark start

# producer in node 3
peg ssh ozy-cluster 3

for t in $(seq 0 4) ; do
python src/ozy_producer.py $t &
done

# producer in node 4
peg ssh ozy-cluster 4

for t in $(seq 5 9) ; do
python src/ozy_producer.py $t &
done

# kill all producers in cluster
#peg sshcmd-cluster ozy-cluster "pkill -f producer"
peg ssh ozy-cluster 1

# submit spark with monitoring
while true  ; do 
if [[ $(ps -aux | grep "ozy_streaming" | grep -v "grep") ]] ; then 
echo "Spark is still running..."
sleep 10
else 
$SPARK_HOME/bin/spark-submit \
--master spark://$MASTER_NODE:7077 \
--jars lib/spark-streaming-kafka-0-8-assembly_2.11-2.2.0.jar \
--conf "spark.streaming.concurrentJobs=20" \
--conf "spark.executor.memory=2g" \
--conf "spark.executor.cores=6" \
--conf "spark.streaming.backpressure.enabled=true" \
--py-files src/sparkstart.py \
src/ozy_streaming.py &
sleep 60
fi
done &

# run app
peg ssh ozy-cluster 2

sudo service nginx restart
cd web
gunicorn ozy_app:app --daemon --bind localhost:8000 --worker-class gevent --workers 1



