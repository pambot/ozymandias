peg service ozy-cluster zookeeper start
peg service ozy-cluster kafka start &
peg service ozy-cluster hadoop start
peg service ozy-cluster spark start

# producer in node 3
peg ssh ozy-cluster 3

topics=(010a37d3ee6f379df747d1af66c85f4 002d7deeeb4269e9c1960c1a7ce8 010a074acb1975c4d6d6e43c1faeb8 016a37b6c5e6ef2ea8b9532a69076 0026c01d82d86fab2f966bac04ddf)

for t in ${topics[@]} ; do
python src/ozy_producer.py data/$t.mp4 &
done

# producer in node 4
peg ssh ozy-cluster 4

topics=(00959d3ca2f937a8b711c5d24a1f2 010c65549a3908ab619519949cce36e 006039642c984a788569c7fea33ef3 01013798371d53f8be2dba2e1508a 00549072f6edf63938f46ff9a25fb4)

for t in ${topics[@]} ; do
python src/ozy_producer.py data/$t.mp4 &
done

# kill all producers in cluster
#peg sshcmd-cluster ozy-cluster "pkill -f producer"
peg ssh ozy-cluster 1

# submit spark
$SPARK_HOME/bin/spark-submit \
--master spark://$MASTER_NODE:7077 \
--jars lib/spark-streaming-kafka-0-8-assembly_2.11-2.2.0.jar \
--conf "spark.streaming.concurrentJobs=20" \
--conf "spark.executor.memory=2g" \
--conf "spark.executor.cores=6" \
--conf "spark.streaming.backpressure.enabled=true" \
--py-files src/sparkstart.py \
src/ozy_streaming.py

# run app
peg ssh ozy-cluster 2

cd web
gunicorn ozy_app:app  --bind 0.0.0.0:5000 -k gevent -w 8





