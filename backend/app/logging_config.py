"""Comprehensive logging configuration for Trenzy backend.

Provides structured logging with:
- Contextual information (request ID, user ID, timing)
- Multiple handlers (console, file)
- Separate loggers for different components
- Environment-aware log levels and formats
- JSON formatting for production parsing

Usage:
    from .logging_config import setup_logging, get_logger
    
    setup_logging()  # Call once at app startup
    
    logger = get_logger(__name__)  # In each module
    logger.info("Operation completed", extra={"user_id": uid, "duration_ms": 150})

Loggers by component:
    app.main: Application startup, shutdown, configuration
    app.auth: Authentication, token verification, Firebase
    app.socket: Socket.IO events, connections, disconnections
    app.db: Database operations, migrations
    app.cache: Redis/caching operations
    app.routes.*: Route-specific logging
    app.security: Security events (failed auth, rate limiting)
    app.performance: Performance metrics, slow queries

Log levels:
    DEBUG: Detailed information for debugging (dev only)
    INFO: General informational messages
    WARNING: Warning messages for potentially problematic situations
    ERROR: Error messages for recoverable errors
    CRITICAL: Critical errors requiring immediate attention
"""

from __future__ import annotations

import json
import logging
import os
import sys
from datetime import datetime, timezone
from typing import Any

# Import configuration
APP_ENV = os.getenv("APP_ENV", "production").strip().lower()
IS_PRODUCTION = APP_ENV not in {"development", "dev", "local", "test"}
LOG_LEVEL = os.getenv("LOG_LEVEL", "DEBUG" if not IS_PRODUCTION else "INFO")
LOG_FORMAT = os.getenv("LOG_FORMAT", "text").lower()  # "text" or "json"


class JSONFormatter(logging.Formatter):
    """Format log records as JSON for structured logging and parsing."""

    def format(self, record: logging.LogRecord) -> str:
        """Convert log record to JSON."""
        log_obj: dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }

        # Add exception info if present
        if record.exc_info:
            log_obj["exception"] = self.formatException(record.exc_info)

        # Add extra fields from record
        for key, value in record.__dict__.items():
            if key not in (
                "name", "msg", "args", "created", "filename", "funcName", "levelname",
                "levelno", "lineno", "module", "msecs", "message", "pathname", "process",
                "processName", "relativeCreated", "thread", "threadName", "exc_info",
                "exc_text", "stack_info",
            ):
                log_obj[key] = value

        return json.dumps(log_obj)


class TextFormatter(logging.Formatter):
    """Format log records as human-readable text."""

    def format(self, record: logging.LogRecord) -> str:
        """Convert log record to text."""
        timestamp = datetime.now(timezone.utc).isoformat()
        level = record.levelname.ljust(8)
        logger_name = record.name.ljust(25)
        message = record.getMessage()

        # Add exception info if present
        if record.exc_info:
            message += f"\n{self.formatException(record.exc_info)}"

        return f"{timestamp} {level} {logger_name} {message}"


def setup_logging() -> None:
    """Configure logging for the application.

    Called once at app startup (in main.py lifespan event).
    """
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, LOG_LEVEL.upper(), logging.INFO))

    # Remove any existing handlers
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)

    # Choose formatter based on LOG_FORMAT env var
    formatter = JSONFormatter() if LOG_FORMAT == "json" else TextFormatter()

    # Console handler (always enabled)
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(getattr(logging, LOG_LEVEL.upper(), logging.INFO))
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)

    # File handler (in production)
    if IS_PRODUCTION:
        log_dir = "/var/log/trenzy"
        os.makedirs(log_dir, exist_ok=True)
        file_handler = logging.FileHandler(f"{log_dir}/backend.log")
        file_handler.setLevel(logging.INFO)
        file_handler.setFormatter(formatter)
        root_logger.addHandler(file_handler)
        get_logger(__name__).info("File logging enabled: %s", f"{log_dir}/backend.log")

    # Configure specific loggers
    _configure_component_loggers()


def _configure_component_loggers() -> None:
    """Configure logging levels for specific components."""
    # Application loggers
    logging.getLogger("app.main").setLevel(logging.INFO)
    logging.getLogger("app.auth").setLevel(logging.INFO)
    logging.getLogger("app.socket").setLevel(logging.INFO)
    logging.getLogger("app.db").setLevel(logging.INFO if IS_PRODUCTION else logging.DEBUG)
    logging.getLogger("app.cache").setLevel(logging.INFO)
    logging.getLogger("app.security").setLevel(logging.WARNING)
    logging.getLogger("app.performance").setLevel(logging.INFO)

    # Third-party library loggers (verbose in dev, quiet in prod)
    logging.getLogger("sqlalchemy").setLevel(logging.WARNING if IS_PRODUCTION else logging.INFO)
    logging.getLogger("urllib3").setLevel(logging.WARNING)
    logging.getLogger("firebase_admin").setLevel(logging.INFO if IS_PRODUCTION else logging.DEBUG)
    logging.getLogger("redis").setLevel(logging.WARNING if IS_PRODUCTION else logging.INFO)


def get_logger(name: str) -> logging.Logger:
    """Get a logger for the given module name.

    Usage:
        logger = get_logger(__name__)  # In app/routes/products.py -> "app.routes.products"

    Args:
        name: Module name (typically __name__)

    Returns:
        Configured logger instance
    """
    # Normalize name to app.* namespace
    if not name.startswith("app."):
        if "app" in name:
            name = "app." + name.split("app.")[-1]
        else:
            name = "app." + name

    return logging.getLogger(name)


def log_with_context(
    logger: logging.Logger,
    level: str,
    message: str,
    **context,
) -> None:
    """Log a message with contextual extra fields.

    Usage:
        log_with_context(
            logger, "info", "User logged in",
            user_id="abc123", ip="192.168.1.1", duration_ms=150
        )

    Args:
        logger: Logger instance
        level: Log level ("debug", "info", "warning", "error", "critical")
        message: Message to log
        **context: Extra fields to include in log record
    """
    log_func = getattr(logger, level.lower(), logger.info)
    log_func(message, extra=context)


__all__ = [
    "setup_logging",
    "get_logger",
    "log_with_context",
    "JSONFormatter",
    "TextFormatter",
    "IS_PRODUCTION",
    "LOG_LEVEL",
    "LOG_FORMAT",
]
