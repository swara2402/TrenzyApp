"""Centralized error handling and response formatting.

Provides consistent error responses across the API and consistent success
response formatting. All errors raised in routes should use these classes.

Usage:
    from fastapi import HTTPException
    from .errors import TrenzyError, ValidationError, NotFoundError

    @router.get("/api/items/{id}")
    def get_item(id: str):
        item = db.query(Item).filter(Item.id == id).first()
        if not item:
            raise NotFoundError(f"Item {id} not found")
        return item

    @router.post("/api/items")
    def create_item(payload: CreateItemRequest):
        if not payload.name or not payload.name.strip():
            raise ValidationError("name", "Name is required and cannot be empty")
        # ... create logic

    try:
        # ... operation
    except SpecificException as e:
        raise TrenzyError("operation_failed", str(e), 400)

Error hierarchy:
- TrenzyError: Base class for all Trenzy-specific errors
  - ValidationError: Invalid input from client
  - NotFoundError: Resource not found
  - UnauthorizedError: Missing/invalid authentication
  - ForbiddenError: User lacks permission
  - ConflictError: Resource already exists or state conflict
  - RateLimitError: Too many requests
  - InternalError: Server-side error

All errors are converted to JSON responses with status code and error_code.
"""

from __future__ import annotations

from fastapi import HTTPException
from typing import Any


class TrenzyError(HTTPException):
    """Base class for Trenzy API errors.
    
    All Trenzy-specific errors inherit from this and raise as HTTPException
    to automatically convert to JSON responses.
    """

    def __init__(
        self,
        error_code: str,
        detail: str,
        status_code: int = 400,
        headers: dict[str, str] | None = None,
        extra: dict[str, Any] | None = None,
    ):
        """Initialize a Trenzy error.
        
        Args:
            error_code: Machine-readable error identifier (e.g., "validation_error")
            detail: Human-readable error message
            status_code: HTTP status code (default: 400 Bad Request)
            headers: Optional HTTP headers to include in response
            extra: Optional extra fields to include in JSON response
        """
        self.error_code = error_code
        self.extra = extra or {}
        # HTTPException expects a dict for detail when using a custom encoder
        super().__init__(
            status_code=status_code,
            detail={
                "status": "error",
                "error_code": error_code,
                "message": detail,
                **self.extra,
            },
            headers=headers,
        )


class ValidationError(TrenzyError):
    """Raised when client input fails validation."""

    def __init__(self, field: str, detail: str):
        """Initialize a validation error.
        
        Args:
            field: Name of the field that failed validation
            detail: Description of what went wrong
        """
        super().__init__(
            error_code="validation_error",
            detail=f"{field}: {detail}",
            status_code=400,
            extra={"field": field},
        )


class NotFoundError(TrenzyError):
    """Raised when a requested resource is not found."""

    def __init__(self, detail: str, resource_type: str | None = None):
        """Initialize a not-found error.
        
        Args:
            detail: Description of what wasn't found
            resource_type: Optional resource type (e.g., "User", "Blend")
        """
        super().__init__(
            error_code="not_found",
            detail=detail,
            status_code=404,
            extra={"resource_type": resource_type} if resource_type else {},
        )


class UnauthorizedError(TrenzyError):
    """Raised when authentication is missing or invalid."""

    def __init__(self, detail: str = "Missing or invalid authentication"):
        super().__init__(
            error_code="unauthorized",
            detail=detail,
            status_code=401,
        )


class ForbiddenError(TrenzyError):
    """Raised when user lacks permission to access a resource."""

    def __init__(self, detail: str = "Insufficient permissions"):
        super().__init__(
            error_code="forbidden",
            detail=detail,
            status_code=403,
        )


class ConflictError(TrenzyError):
    """Raised when resource already exists or state is conflicting."""

    def __init__(self, detail: str, conflict_field: str | None = None):
        """Initialize a conflict error.
        
        Args:
            detail: Description of the conflict
            conflict_field: Optional field that caused the conflict
        """
        super().__init__(
            error_code="conflict",
            detail=detail,
            status_code=409,
            extra={"conflict_field": conflict_field} if conflict_field else {},
        )


class RateLimitError(TrenzyError):
    """Raised when rate limit is exceeded."""

    def __init__(self, retry_after: int = 60):
        """Initialize a rate limit error.
        
        Args:
            retry_after: Seconds to wait before retrying
        """
        super().__init__(
            error_code="rate_limited",
            detail="Too many requests. Please try again later.",
            status_code=429,
            extra={"retry_after": retry_after},
        )


class InternalError(TrenzyError):
    """Raised for unrecoverable server errors."""

    def __init__(self, detail: str = "Internal server error", request_id: str | None = None):
        """Initialize an internal error.
        
        Args:
            detail: Description of the error
            request_id: Optional request ID for logging/debugging
        """
        super().__init__(
            error_code="internal_error",
            detail=detail,
            status_code=500,
            extra={"request_id": request_id} if request_id else {},
        )


# Success response formatter
def success_response(
    data: Any = None,
    message: str = "Success",
    status_code: int = 200,
) -> dict[str, Any]:
    """Format a success response.
    
    Usage:
        return success_response({"id": 123, "name": "Item"}, message="Item created")
    
    Args:
        data: Response payload (dict, list, etc.)
        message: Optional success message
        status_code: HTTP status code (default: 200)
    
    Returns:
        Dict ready to return from route handler
    """
    return {
        "status": "success",
        "message": message,
        "data": data,
    }


def error_response(
    error_code: str,
    message: str,
    status_code: int = 400,
    **extra,
) -> dict[str, Any]:
    """Format an error response.
    
    Note: Prefer raising TrenzyError subclasses instead of calling this directly.
    This is mainly for use in middleware or exceptional cases.
    
    Usage:
        return error_response("validation_error", "Invalid input", status_code=400)
    
    Args:
        error_code: Machine-readable error identifier
        message: Human-readable error message
        status_code: HTTP status code
        **extra: Additional fields to include in response
    
    Returns:
        Dict ready to return from route handler
    """
    return {
        "status": "error",
        "error_code": error_code,
        "message": message,
        **extra,
    }


__all__ = [
    "TrenzyError",
    "ValidationError",
    "NotFoundError",
    "UnauthorizedError",
    "ForbiddenError",
    "ConflictError",
    "RateLimitError",
    "InternalError",
    "success_response",
    "error_response",
]
