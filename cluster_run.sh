# producer in node 3
peg ssh ozy-cluster 3

topics=(010a37d3ee6f379df747d1af66c85f4 \
002d7deeeb4269e9c1960c1a7ce8 \
010a074acb1975c4d6d6e43c1faeb8 \
016a37b6c5e6ef2ea8b9532a69076 \
0026c01d82d86fab2f966bac04ddf)

for t in ${topics[@]} ; do
python src/ozy_producer.py data/$t.mp4 &
done

# producer in node 4
peg ssh ozy-cluster 4

topics=(00959d3ca2f937a8b711c5d24a1f2 \
01046b6946ad8cd1b46595e555c43b5 \
01616ec3a3669e67979ccf791e82ee5 \
0094dd222bdbf103b92149ca3d74c \
01629166c83b0c9fe702f67bdf50d)

for t in ${topics[@]} ; do
python src/ozy_producer.py data/$t.mp4 &
done

# kill all producers in cluster
#peg sshcmd-cluster ozy-cluster "pkill -f producer"

# submit spark
master=ec2-34-194-190-38.compute-1.amazonaws.com
$SPARK_HOME/bin/spark-submit \
--master spark://$master:7077 \
--jars lib/spark-streaming-kafka-0-8-assembly_2.11-2.2.0.jar \
--conf "spark.streaming.concurrentJobs=20" \
--conf "spark.executor.memory=2g" \
--conf "spark.executor.cores=6" \
--conf "spark.streaming.backpressure.enabled=true" \
--py-files src/sparkstart.py \
src/ozy_streaming.py

# run app
peg ssh ozy-cluster 2

python web/ozy_app.py


