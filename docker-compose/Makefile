# Docker Compose本地测试环境 - Makefile
# 作者: 云原生专家
# 版本: 1.0.0

.PHONY: help start stop restart status logs clean init-data

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
	@echo "服务管理:"
	@echo "  make start-storage     - 启动存储服务"
	@echo "  make start-messaging   - 启动消息队列"
	@echo "  make start-database    - 启动数据仓库"
	@echo "  make start-streaming   - 启动流处理"
	@echo "  make start-monitoring  - 启动监控"
	@echo "  make start-apps        - 启动应用服务"
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
	@docker-compose up -d flink-jobmanager flink-taskmanager

# 启动监控
start-monitoring:
	@echo "启动监控..."
	@docker-compose up -d prometheus grafana

# 启动应用服务
start-apps:
	@echo "启动应用服务..."
	@docker-compose up -d airflow-postgres airflow-redis airflow-webserver airflow-scheduler superset-postgres superset jupyterhub

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

# 健康检查
health-check:
	@echo "执行健康检查..."
	@echo "=== 服务健康状态 ==="
	@docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "=== 端口检查 ==="
	@for port in 9000 9001 8082 8030 8040 8081 9090 3000 8080 8088 8000; do \
		if curl -s http://localhost:$$port > /dev/null 2>&1; then \
			echo "✓ localhost:$$port - 正常"; \
		else \
			echo "✗ localhost:$$port - 异常"; \
		fi; \
	done

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
	@echo "测试完成"

# 一键部署
deploy:
	@echo "一键部署大数据AI平台..."
	@make start
	@echo "等待服务启动..."
	@sleep 60
	@make init-data
	@make access-info
	@echo "部署完成！"

# 开发模式
dev:
	@echo "启动开发模式..."
	@docker-compose up -d minio redis kafka doris-fe doris-be flink-jobmanager flink-taskmanager
	@echo "开发环境已启动，包含: MinIO, Redis, Kafka, Doris, Flink"
	@echo "访问地址:"
	@echo "  MinIO: http://localhost:9001"
	@echo "  Kafka UI: http://localhost:8082"
	@echo "  Doris: http://localhost:8030"
	@echo "  Flink: http://localhost:8081"

# 生产模式
prod:
	@echo "启动生产模式..."
	@docker-compose up -d
	@echo "生产环境已启动，包含所有服务"
	@make access-info 