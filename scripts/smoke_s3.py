#!/usr/bin/env python3
"""오브젝트 스토어의 S3 API 호환성을 확인합니다.

    ./scripts/smoke_s3.py

PUT → GET → LIST → DELETE 를 SigV4 서명으로 호출합니다. 하나라도 실패하면
0이 아닌 코드로 종료합니다.

boto3 나 awscli 를 쓰지 않고 표준 라이브러리로 서명합니다. 이 스크립트의 목적이
"레포를 받은 사람이 추가 설치 없이 기동을 확인할 수 있다"는 것이라서,
검증 스크립트가 의존성을 요구하면 그 주장이 약해집니다.

ADR-0002에서 MinIO를 SeaweedFS로 교체했고, 그때 남긴 미검증 리스크가
"SeaweedFS의 S3 구현이 실제로 쓸 만한가"였습니다. 이 스크립트가 그 답입니다.
"""

import datetime
import hashlib
import hmac
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

ENDPOINT = os.environ.get("S3_ENDPOINT", "http://127.0.0.1:8333")
ACCESS_KEY = os.environ.get("S3_ACCESS_KEY", "cityops")
SECRET_KEY = os.environ.get("S3_SECRET_KEY", "cityops123")
REGION = os.environ.get("S3_REGION", "us-east-1")
BUCKET = os.environ.get("S3_SMOKE_BUCKET", "bronze")

KEY = "_smoke/w1-check.txt"
BODY = b"city-ops W1 s3 smoke\n"


def _sign(key, msg):
    return hmac.new(key, msg.encode(), hashlib.sha256).digest()


def canonical_query(params):
    """SigV4 canonical query string.

    키 기준으로 정렬하고 값을 RFC3986 으로 인코딩해야 합니다. `prefix=_smoke/x`
    처럼 슬래시가 든 값을 인코딩하지 않으면 SeaweedFS 가 SignatureDoesNotMatch 로
    거부합니다 (실제로 겪었습니다 — 서버 문제가 아니라 서명 문제입니다).
    """
    return "&".join(
        f"{urllib.parse.quote(k, safe='-_.~')}={urllib.parse.quote(v, safe='-_.~')}"
        for k, v in sorted(params.items())
    )


# 타입 애노테이션에 `dict | None` 을 쓰지 않습니다. 레포는 Python 3.11을 쓰지만
# 이 스크립트는 macOS 기본 3.9 에서도 돌아야 합니다 (추가 설치 없이 기동 확인).
def request(method, path, params=None, body=b""):
    """SigV4 로 서명한 S3 요청을 보내고 응답 본문을 돌려줍니다."""
    query = canonical_query(params or {})
    host = ENDPOINT.split("://", 1)[1]
    now = datetime.datetime.now(datetime.timezone.utc)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    payload_hash = hashlib.sha256(body).hexdigest()

    # 서명할 헤더는 알파벳 순서여야 하고, canonical/signed 양쪽이 같은 순서여야 합니다.
    headers = {
        "host": host,
        "x-amz-content-sha256": payload_hash,
        "x-amz-date": amz_date,
    }
    signed_headers = ";".join(sorted(headers))
    canonical_headers = "".join(f"{k}:{headers[k]}\n" for k in sorted(headers))

    canonical_request = "\n".join([
        method, path, query, canonical_headers, signed_headers, payload_hash,
    ])
    scope = f"{date_stamp}/{REGION}/s3/aws4_request"
    string_to_sign = "\n".join([
        "AWS4-HMAC-SHA256",
        amz_date,
        scope,
        hashlib.sha256(canonical_request.encode()).hexdigest(),
    ])

    k = _sign(f"AWS4{SECRET_KEY}".encode(), date_stamp)
    for part in (REGION, "s3", "aws4_request"):
        k = _sign(k, part)
    signature = hmac.new(k, string_to_sign.encode(), hashlib.sha256).hexdigest()

    headers["Authorization"] = (
        f"AWS4-HMAC-SHA256 Credential={ACCESS_KEY}/{scope}, "
        f"SignedHeaders={signed_headers}, Signature={signature}"
    )

    url = f"{ENDPOINT}{path}" + (f"?{query}" if query else "")
    req = urllib.request.Request(url, data=body or None, method=method)
    for name, value in headers.items():
        req.add_header(name, value)
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.read()


def main():
    checks = []

    def check(label, fn):
        try:
            fn()
        except Exception as exc:  # noqa: BLE001 — 실패 이유를 그대로 보여주는 것이 목적
            if isinstance(exc, urllib.error.HTTPError):
                detail = f"HTTP {exc.code} {exc.read().decode(errors='replace')[:200]}"
            else:
                detail = f"{type(exc).__name__}: {exc}"
            checks.append((label, False, detail))
        else:
            checks.append((label, True, ""))

    def put():
        request("PUT", f"/{BUCKET}/{KEY}", body=BODY)

    def get():
        got = request("GET", f"/{BUCKET}/{KEY}")
        if got != BODY:
            raise AssertionError(f"본문 불일치: {got!r} != {BODY!r}")

    def list_objects():
        xml = request("GET", f"/{BUCKET}/", {"list-type": "2", "prefix": KEY}).decode()
        if KEY not in xml:
            raise AssertionError(f"LIST 결과에 키가 없음: {xml[:300]}")

    def delete():
        request("DELETE", f"/{BUCKET}/{KEY}")

    check(f"PUT    s3://{BUCKET}/{KEY}", put)
    check(f"GET    s3://{BUCKET}/{KEY} (본문 일치)", get)
    check(f"LIST   s3://{BUCKET}/ (ListObjectsV2)", list_objects)
    check(f"DELETE s3://{BUCKET}/{KEY}", delete)

    print(f"엔드포인트: {ENDPOINT}  버킷: {BUCKET}")
    for label, ok, detail in checks:
        print(f"  {'✅' if ok else '❌'} {label}" + (f"\n       {detail}" if detail else ""))

    failed = [c for c in checks if not c[1]]
    print(f"\n{len(checks) - len(failed)}/{len(checks)} 통과")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
