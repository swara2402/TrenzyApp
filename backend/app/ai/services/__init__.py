"""AI services module - canonical, singleton services for all AI operations.

All services in this module are designed to be:
1. Singleton: Only one instance exists in the application
2. Canonical: All other code must use these services, no duplicate implementations
3. Thread-safe: Can be safely used across multiple threads/processes
4. Configurable: Use centralized ml_config.py for all configuration
"""