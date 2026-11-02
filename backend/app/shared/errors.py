class ApiError(Exception):
    def __init__(self, status, code, fields=None):
        self.status = status
        self.code = code
        self.fields = fields or {}


def error_body(code, fields=None):
    return {'error': {'code': code, 'message': code,
                      'fields': fields or {}, 'details': {}}}
