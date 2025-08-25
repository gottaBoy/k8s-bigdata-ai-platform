# JupyterHub配置文件
import os

# JupyterHub配置
c = get_config()

# 认证配置
c.JupyterHub.authenticator_class = 'jupyterhub.auth.DummyAuthenticator'
c.DummyAuthenticator.password = "jupyter123"

# 数据库配置
c.JupyterHub.db_url = 'sqlite:///jupyterhub.sqlite'

# 服务配置
c.JupyterHub.bind_url = 'http://0.0.0.0:8000'
c.JupyterHub.hub_ip = '0.0.0.0'
c.JupyterHub.hub_port = 8001

# 用户配置
c.JupyterHub.admin_users = {'admin'}
c.JupyterHub.allow_named_servers = True

# 容器配置
c.JupyterHub.spawner_class = 'jupyterhub.spawner.SimpleLocalProcessSpawner'

# 环境变量
c.Spawner.environment = {
    'JUPYTER_ENABLE_LAB': 'yes',
    'PYTHONPATH': '/opt/conda/lib/python3.9/site-packages',
}

# 数据目录
c.Spawner.notebook_dir = '/home/jovyan/work'
c.Spawner.default_url = '/lab'

# 资源限制
c.Spawner.mem_limit = '2G'
c.Spawner.cpu_limit = 1.0

# 超时配置
c.Spawner.start_timeout = 300
c.Spawner.http_timeout = 120

# 日志配置
c.Application.log_level = 'INFO'
c.Spawner.debug = True

# 服务配置
c.JupyterHub.services = [
    {
        'name': 'idle-culler',
        'command': [
            sys.executable, '-m', 'jupyterhub_idle_culler',
            '--timeout=3600',
            '--cull-every=300',
            '--max-age=0',
            '--remove-named-servers',
        ],
        'environment': {
            'JUPYTERHUB_API_TOKEN': 'your-api-token-here',
        },
    }
]

# 数据源连接配置
c.Spawner.environment.update({
    'MINIO_ENDPOINT': 'http://minio:9000',
    'MINIO_ACCESS_KEY': 'admin',
    'MINIO_SECRET_KEY': 'minio123',
    'KAFKA_BOOTSTRAP_SERVERS': 'kafka:29092',
    'DORIS_HOST': 'doris-fe',
    'DORIS_PORT': '9030',
    'DORIS_USER': 'root',
    'DORIS_PASSWORD': 'root',
    'REDIS_HOST': 'redis',
    'REDIS_PORT': '6379',
    'REDIS_PASSWORD': 'redis123',
})

# 预装包配置
c.Spawner.environment.update({
    'PIP_PACKAGES': 'pandas numpy matplotlib seaborn scikit-learn pyspark pymongo redis kafka-python minio sqlalchemy pymysql psycopg2-binary',
    'CONDA_PACKAGES': 'jupyterlab pandas numpy matplotlib seaborn scikit-learn pyspark',
})

# 启动脚本
c.Spawner.cmd = ['jupyter-labhub']

# 用户目录
c.Spawner.user_data_dir = '/data/jupyterhub/users'

# 共享目录
c.Spawner.volumes = {
    '/data/shared': '/home/jovyan/shared:ro',
    '/data/datasets': '/home/jovyan/datasets:ro',
}

# 网络配置
c.Spawner.network_name = 'bigdata-network'

# 健康检查
c.Spawner.http_timeout = 120
c.Spawner.start_timeout = 300

# 清理配置
c.JupyterHub.cleanup_servers = True
c.JupyterHub.cleanup_proxy = True 