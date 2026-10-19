"""HTTP serialization and delivery status belong at the API boundary."""

from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse, Response

from app.features.auth.errors import AuthFailure
from app.features.auth import sms as sms_gateway


def output(result, status=200, sms=None):
    if sms and not sms_gateway.send_sms(*sms):
        if isinstance(result, AuthFailure):
            result.details["registration"]["deliveryStatus"] = "failed"
        else:
            result["deliveryStatus"] = "failed"
    if isinstance(result, AuthFailure):
        headers = {"Cache-Control": "no-store"}
        if result.retry is not None:
            headers["Retry-After"] = str(max(1, result.retry))
        return JSONResponse(
            jsonable_encoder(
                {
                    "error": {
                        "code": result.code,
                        "message": result.code,
                        "fields": result.fields,
                        "details": result.details,
                    }
                }
            ),
            status_code=result.status_code,
            headers=headers,
        )
    if isinstance(result, Response):
        return result
    return JSONResponse(
        jsonable_encoder(result),
        status_code=status,
        headers={"Cache-Control": "no-store"},
    )
