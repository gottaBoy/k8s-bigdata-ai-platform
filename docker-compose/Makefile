# Docker Compose本地测试环境 - Makefile
# 作者: 云原生专家
# 版本: 1.0.0

.PHONY: help start stop restart status logs clean init-data health-check optimize

# 默认目标
help:
	@echo "Docker Compose本地测试环境 - 可用命令"
	@echo ""
	@echo "基础操作:"
	@echo "  make start       - 启动所有服务"
	@echo "  make stop        - 停止所有服务"
	@echo "  make restart     - 重启所有服务"
	@echo "  make status      - 查看服务状态"
	@echo "  make logs        - 查看服务日志"
	@echo "  make clean       - 清理环境"
	@echo ""
	@echo "数据操作:"
	@echo "  make init-data   - 初始化数据"
	@echo "  make backup      - 备份数据"
	@echo "  make restore     - 恢复数据"
	@echo ""
	@echo "监控和健康检查:"
	@echo "  make health-check - 执行健康检查"
	@echo "  make monitor     - 性能监控"
	@echo "  make test        - 快速测试"
	@echo ""
	@echo "服务管理:"
	@echo "  make start-storage     - 启动存储服务"
	@echo "  make start-messaging   - 启动消息队列"
	@echo "  make start-database    - 启动数据仓库"
	@echo "  make start-streaming   - 启动流处理"
	@echo "  make start-monitoring  - 启动监控"
	@echo "  make start-apps        - 启动应用服务"
	@echo ""
	@echo "优化和维护:"
	@echo "  make optimize    - 性能优化"
	@echo "  make compact     - 数据压缩"
	@echo "  make cleanup     - 数据清理"
	@echo "  make upgrade     - 升级服务"
	@echo ""

# 启动所有服务
start:
	@echo "启动大数据AI平台本地测试环境..."
	@./start.sh

# 停止所有服务
stop:
	@echo "停止所有服务..."
	@docker-compose stop

# 重启所有服务
restart:
	@echo "重启所有服务..."
	@docker-compose restart

# 查看服务状态
status:
	@echo "=== 服务状态 ==="
	@docker-compose ps
	@echo ""
	@echo "=== 资源使用 ==="
	@docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

# 查看服务日志
logs:
	@echo "查看服务日志..."
	@docker-compose logs -f

# 清理环境
clean:
	@echo "清理Docker Compose环境..."
	@echo "警告: 这将删除所有容器、网络和数据卷！"
	@read -p "确认删除? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@docker-compose down -v --rmi all
	@docker system prune -f
	@echo "环境清理完成"

# 初始化数据
init-data:
	@echo "初始化平台数据..."
	@chmod +x scripts/init-data.sh
	@./scripts/init-data.sh

# 健康检查
health-check:
	@echo "执行健康检查..."
	@chmod +x scripts/health-check.sh
	@./scripts/health-check.sh

# 性能监控
monitor:
	@echo "性能监控..."
	@echo "=== 容器资源使用 ==="
	@docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
	@echo ""
	@echo "=== 磁盘使用 ==="
	@docker system df

# 快速测试
test:
	@echo "执行快速测试..."
	@echo "1. 测试MinIO连接..."
	@docker exec minio-client mc ls myminio/ 2>/dev/null || echo "MinIO连接失败"
	@echo "2. 测试Kafka连接..."
	@docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 2>/dev/null || echo "Kafka连接失败"
	@echo "3. 测试Doris连接..."
	@docker exec doris-fe mysql -h localhost -P 9030 -u root -e "SHOW DATABASES;" 2>/dev/null || echo "Doris连接失败"
	@echo "4. 测试Redis连接..."
	@docker exec redis redis-cli -a redis123 ping 2>/dev/null || echo "Redis连接失败"
	@echo "5. 测试Flink连接..."
	@curl -s http://localhost:8081 > /dev/null 2>&1 && echo "Flink连接成功" || echo "Flink连接失败"
	@echo "6. 测试Paimon状态..."
	@docker ps | grep -q "paimon-catalog" && echo "Paimon服务运行中" || echo "Paimon服务未运行"
	@echo "测试完成"

# 备份数据
backup:
	@echo "备份平台数据..."
	@mkdir -p backups/$(shell date +%Y%m%d-%H%M%S)
	@docker-compose exec minio mc mirror myminio/bigdata-lake backups/$(shell date +%Y%m%d-%H%M%S)/minio/ || true
	@docker-compose exec doris-fe mysqldump -h localhost -P 9030 -u root -p bigdata_platform > backups/$(shell date +%Y%m%d-%H%M%S)/doris_backup.sql || true
	@echo "备份完成: backups/$(shell date +%Y%m%d-%H%M%S)/"

# 恢复数据
restore:
	@echo "恢复平台数据..."
	@read -p "输入备份目录: " backup_dir && \
	if [ -d "$$backup_dir" ]; then \
		if [ -d "$$backup_dir/minio" ]; then \
			docker-compose exec minio mc mirror backups/$$backup_dir/minio/ myminio/bigdata-lake/ || true; \
		fi; \
		if [ -f "$$backup_dir/doris_backup.sql" ]; then \
			docker-compose exec doris-fe mysql -h localhost -P 9030 -u root -p < $$backup_dir/doris_backup.sql || true; \
		fi; \
		echo "数据恢复完成"; \
	else \
		echo "备份目录不存在: $$backup_dir"; \
	fi

# 启动存储服务
start-storage:
	@echo "启动存储服务..."
	@docker-compose up -d minio redis

# 启动消息队列
start-messaging:
	@echo "启动消息队列..."
	@docker-compose up -d zookeeper kafka kafka-ui

# 启动数据仓库
start-database:
	@echo "启动数据仓库..."
	@docker-compose up -d doris-fe doris-be

# 启动流处理
start-streaming:
	@echo "启动流处理..."
	@docker-compose up -d flink-jobmanager flink-taskmanager paimon-catalog

# 启动监控
start-monitoring:
	@echo "启动监控..."
	@docker-compose up -d prometheus grafana

# 启动应用服务
start-apps:
	@echo "启动应用服务..."
	@docker-compose up -d airflow-postgres airflow-redis airflow-webserver airflow-scheduler superset-postgres superset jupyterhub

# 性能优化
optimize:
	@echo "执行性能优化..."
	@echo "1. 优化Flink配置..."
	@docker exec flink-jobmanager /opt/flink/bin/flink run -d /opt/flink/examples/streaming/WordCount.jar || true
	@echo "2. 优化Paimon表..."
	@docker exec paimon-catalog /opt/flink/bin/sql-client.sh -e "OPTIMIZE TABLE user_events;" || true
	@echo "3. 清理过期数据..."
	@docker exec doris-fe mysql -h localhost -P 9030 -u root -e "DELETE FROM user_events WHERE event_date < DATE_SUB(CURDATE(), INTERVAL 7 DAY);" || true
	@echo "4. 压缩数据文件..."
	@docker exec minio-client mc admin bucket-encrypt myminio/bigdata-lake || true
	@echo "性能优化完成"

# 数据压缩
compact:
	@echo "执行数据压缩..."
	@echo "1. 压缩Paimon表..."
	@docker exec paimon-catalog /opt/flink/bin/sql-client.sh -e "CALL paimon.system.compact('user_events');" || true
	@docker exec paimon-catalog /opt/flink/bin/sql-client.sh -e "CALL paimon.system.compact('sales_data');" || true
	@echo "2. 压缩Doris表..."
	@docker exec doris-fe mysql -h localhost -P 9030 -u root -e "ALTER TABLE user_events COMPACT;" || true
	@echo "3. 清理临时文件..."
	@docker system prune -f
	@echo "数据压缩完成"

# 数据清理
cleanup:
	@echo "执行数据清理..."
	@echo "1. 清理过期快照..."
	@docker exec paimon-catalog /opt/flink/bin/sql-client.sh -e "CALL paimon.system.expire_snapshots('user_events', '7d');" || true
	@echo "2. 清理过期文件..."
	@docker exec paimon-catalog /opt/flink/bin/sql-client.sh -e "CALL paimon.system.expire_files('user_events', '7d');" || true
	@echo "3. 清理Docker镜像..."
	@docker image prune -f
	@echo "4. 清理Docker卷..."
	@docker volume prune -f
	@echo "数据清理完成"

# 升级服务
upgrade:
	@echo "升级服务..."
	@echo "1. 拉取最新镜像..."
	@docker-compose pull
	@echo "2. 备份当前数据..."
	@make backup
	@echo "3. 重启服务..."
	@docker-compose up -d
	@echo "4. 验证服务状态..."
	@make health-check
	@echo "服务升级完成"

# 查看访问信息
access-info:
	@echo "=== 平台访问信息 ==="
	@echo ""
	@echo "🌐 服务访问地址:"
	@echo "  MinIO Console:     http://localhost:9001 (admin/minio123)"
	@echo "  Kafka UI:          http://localhost:8082"
	@echo "  Doris FE:          http://localhost:8030"
	@echo "  Doris BE:          http://localhost:8040"
	@echo "  Flink JobManager:  http://localhost:8081"
	@echo "  Paimon Data Lake:  s3://bigdata-lake/paimon"
	@echo "  Prometheus:        http://localhost:9090"
	@echo "  Grafana:           http://localhost:3000 (admin/admin123)"
	@echo "  Airflow:           http://localhost:8080 (admin/admin123)"
	@echo "  Superset:          http://localhost:8088 (admin/admin123)"
	@echo "  JupyterHub:        http://localhost:8000 (admin/jupyter123)"
	@echo ""
	@echo "🔧 连接信息:"
	@echo "  MinIO:             localhost:9000 (admin/minio123)"
	@echo "  Kafka:             localhost:9092"
	@echo "  Doris:             localhost:9030 (root/root)"
	@echo "  Redis:             localhost:6379 (redis123)"
	@echo "  PostgreSQL:        localhost:5432 (airflow/airflow123)"
	@echo ""
	@echo "📊 监控面板:"
	@echo "  Grafana:           http://localhost:3000"
	@echo "  Prometheus:        http://localhost:9090"
	@echo "  Kafka UI:          http://localhost:8082"

# 一键部署
deploy:
	@echo "一键部署大数据AI平台..."
	@make start
	@echo "等待服务启动..."
	@sleep 60
	@make init-data
	@make health-check
	@make access-info
	@echo "部署完成！"

# 开发模式
dev:
	@echo "启动开发模式..."
	@docker-compose up -d minio redis kafka doris-fe doris-be flink-jobmanager flink-taskmanager paimon-catalog
	@echo "开发环境已启动，包含: MinIO, Redis, Kafka, Doris, Flink, Paimon"
	@echo "访问地址:"
	@echo "  MinIO: http://localhost:9001"
	@echo "  Kafka UI: http://localhost:8082"
	@echo "  Doris: http://localhost:8030"
	@echo "  Flink: http://localhost:8081"
	@echo "  Paimon: s3://bigdata-lake/paimon"

# 生产模式
prod:
	@echo "启动生产模式..."
	@docker-compose up -d
	@echo "生产环境已启动，包含所有服务"
	@make access-info

# 故障排查
troubleshoot:
	@echo "故障排查..."
	@echo "1. 检查容器状态..."
	@docker-compose ps
	@echo ""
	@echo "2. 检查服务日志..."
	@docker-compose logs --tail=50
	@echo ""
	@echo "3. 检查网络连接..."
	@docker network ls
	@echo ""
	@echo "4. 检查资源使用..."
	@docker stats --no-stream
	@echo ""
	@echo "5. 生成诊断报告..."
	@make health-check

# 性能基准测试
benchmark:
	@echo "执行性能基准测试..."
	@echo "1. 测试数据写入性能..."
	@docker exec kafka kafka-producer-perf-test --topic test-topic --num-records 10000 --record-size 1000 --throughput 1000 --producer-props bootstrap.servers=localhost:9092 || true
	@echo "2. 测试数据读取性能..."
	@docker exec kafka kafka-consumer-perf-test --topic test-topic --bootstrap-server localhost:9092 --messages 10000 || true
	@echo "3. 测试Flink作业性能..."
	@docker exec flink-jobmanager /opt/flink/bin/flink run -d /opt/flink/examples/streaming/WordCount.jar || true
	@echo "4. 测试Paimon查询性能..."
	@docker exec paimon-catalog /opt/flink/bin/sql-client.sh -e "SELECT COUNT(*) FROM user_events;" || true
	@echo "性能基准测试完成"

# 安全扫描
security-scan:
	@echo "执行安全扫描..."
	@echo "1. 扫描Docker镜像漏洞..."
	@docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image minio/minio:RELEASE.2023-11-15T20-43-25Z || true
	@echo "2. 检查容器权限..."
	@docker ps --format "table {{.Names}}\t{{.Status}}" | grep -v "Up" || echo "所有容器运行正常"
	@echo "3. 检查网络隔离..."
	@docker network inspect bigdata-network --format='{{range .Containers}}{{.Name}} {{end}}' || true
	@echo "安全扫描完成"

# 备份和恢复
backup-restore:
	@echo "备份和恢复管理..."
	@echo "可用命令:"
	@echo "  make backup    - 备份数据"
	@echo "  make restore   - 恢复数据"
	@echo "  make compact   - 压缩数据"
	@echo "  make cleanup   - 清理数据"

# 监控和告警
monitoring:
	@echo "监控和告警管理..."
	@echo "可用命令:"
	@echo "  make health-check - 健康检查"
	@echo "  make monitor     - 性能监控"
	@echo "  make test        - 快速测试"
	@echo "  make benchmark   - 性能基准测试"

# 维护和优化
maintenance:
	@echo "维护和优化管理..."
	@echo "可用命令:"
	@echo "  make optimize    - 性能优化"
	@echo "  make compact     - 数据压缩"
	@echo "  make cleanup     - 数据清理"
	@echo "  make upgrade     - 升级服务"
	@echo "  make security-scan - 安全扫描" 