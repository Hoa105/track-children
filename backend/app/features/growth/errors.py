"""Growth boundary errors; computation errors are response data, not failed saves."""

from fastapi import HTTPException


class GrowthError(HTTPException):
    def __init__(self, status: int, code: str, fields=None):
        self.code = code
        self.fields = fields or {}
        super().__init__(status, code)
