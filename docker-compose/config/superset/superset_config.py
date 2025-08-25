# Superset配置文件
import os

# 数据库配置
SQLALCHEMY_DATABASE_URI = 'postgresql+psycopg2://superset:superset123@superset-postgres:5432/superset'

# 安全配置
SECRET_KEY = 'your-secret-key-here'
WTF_CSRF_ENABLED = True
WTF_CSRF_TIME_LIMIT = None

# 缓存配置
CACHE_CONFIG = {
    'CACHE_TYPE': 'redis',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_',
    'CACHE_REDIS_HOST': 'redis',
    'CACHE_REDIS_PORT': 6379,
    'CACHE_REDIS_DB': 1,
    'CACHE_REDIS_URL': 'redis://redis:6379/1'
}

# 会话配置
SESSION_CONFIG = {
    'SESSION_TYPE': 'redis',
    'SESSION_REDIS_HOST': 'redis',
    'SESSION_REDIS_PORT': 6379,
    'SESSION_REDIS_DB': 2,
    'SESSION_REDIS_URL': 'redis://redis:6379/2'
}

# 功能配置
FEATURE_FLAGS = {
    'ENABLE_TEMPLATE_PROCESSING': True,
    'DASHBOARD_NATIVE_FILTERS': True,
    'DASHBOARD_CROSS_FILTERS': True,
    'DASHBOARD_RBAC': True,
    'ENABLE_EXPLORE_JSON_CSRF_PROTECTION': False,
    'ENABLE_EXPLORE_DRAG_AND_DROP': True,
    'ENABLE_DASHBOARD_NATIVE_FILTERS_SET': True,
    'GLOBAL_ASYNC_QUERIES': True,
    'VERSIONED_EXPORT': True,
    'DASHBOARD_FILTERS_EXPERIMENTAL': True,
}

# 安全配置
AUTH_TYPE = AUTH_DB
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Gamma"

# 邮件配置
SMTP_HOST = 'localhost'
SMTP_STARTTLS = True
SMTP_SSL = False
SMTP_USER = 'superset'
SMTP_PORT = 25
SMTP_PASSWORD = 'superset'
SMTP_MAIL_FROM = 'superset@superset.com'

# 日志配置
ENABLE_TIME_ROTATE = True
TIME_ROTATE_LOG_LEVEL = 'DEBUG'
FILENAME = os.path.join(DATA_DIR, 'superset.log')
ROLLOVER = 'midnight'
INTERVAL = 1
BACKUP_COUNT = 30

# 数据源配置
PREVENT_UNSAFE_DB_CONNECTIONS = False

# 查询配置
QUERY_CACHE_CONFIG = {
    'CACHE_TYPE': 'redis',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_queries_',
    'CACHE_REDIS_HOST': 'redis',
    'CACHE_REDIS_PORT': 6379,
    'CACHE_REDIS_DB': 3,
    'CACHE_REDIS_URL': 'redis://redis:6379/3'
}

# 异步查询配置
REDIS_HOST = 'redis'
REDIS_PORT = 6379
REDIS_CELERY_DB = 4
REDIS_RESULTS_DB = 5

# Celery配置
class CeleryConfig:
    broker_url = f'redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_CELERY_DB}'
    imports = ('superset.sql_lab', 'superset.tasks')
    result_backend = f'redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_RESULTS_DB}'
    worker_prefetch_multiplier = 1
    task_acks_late = False
    task_annotations = {
        'sql_lab.get_sql_results': {
            'rate_limit': '100/s',
        },
        'email_reports.send': {
            'rate_limit': '1/s',
            'time_limit': 120,
            'soft_time_limit': 150,
            'ignore_result': True,
        },
    }
    beat_schedule = {
        'email_reports.schedule_hourly': {
            'task': 'email_reports.schedule_hourly',
            'schedule': crontab(minute=1, hour='*'),
        },
    }

CELERY_CONFIG = CeleryConfig

# 数据源连接配置
DATABASE_CONNECTIONS = {
    'doris': {
        'sqlalchemy_uri': 'mysql+pymysql://root:root@doris-fe:9030/bigdata_platform',
        'connect_args': {
            'charset': 'utf8mb4'
        }
    },
    'postgresql': {
        'sqlalchemy_uri': 'postgresql+psycopg2://airflow:airflow123@airflow-postgres:5432/airflow',
    }
} 