#!/usr/bin/env bash
# 테스트 문의 추가 헬퍼
# 사용법:
#   ./scripts/add-test.sh                → 기본 simple 케이스
#   ./scripts/add-test.sh simple         → 단순문의 (배송)
#   ./scripts/add-test.sh product        → 단순문의 (제품 스펙)
#   ./scripts/add-test.sh manual         → 확인필요 (교환/환불)
#   ./scripts/add-test.sh refund         → 확인필요 (환불)
#   ./scripts/add-test.sh custom "이름" "이메일" "문의내용"
#
# n8n 헬퍼 워크플로우 ID: 91O4quTAcVPxwkJy
# 워크플로우가 Active 여야 동작함.

set -euo pipefail

WEBHOOK_URL="${WEBHOOK_URL:-http://localhost:5678/webhook/test-inquiry}"
DEFAULT_EMAIL="${TEST_EMAIL:-withwooyong@yanadoocorp.com}"

TYPE="${1:-simple}"

case "$TYPE" in
  simple)
    NAME="김철수"
    EMAIL="$DEFAULT_EMAIL"
    INQUIRY="배송은 보통 며칠 걸리나요? 주문 넣고 빨리 받고 싶은데 평균 기간 알려주세요."
    ;;
  product)
    NAME="박민수"
    EMAIL="$DEFAULT_EMAIL"
    INQUIRY="제품의 색상은 어떤 것들이 있나요? 블랙만 있는 건지 궁금합니다."
    ;;
  manual)
    NAME="이수진"
    EMAIL="$DEFAULT_EMAIL"
    INQUIRY="어제 받은 제품이 색상이 잘못 와서 교환 원합니다. 주문번호는 12345 입니다."
    ;;
  refund)
    NAME="정하나"
    EMAIL="$DEFAULT_EMAIL"
    INQUIRY="제품에 파손이 있어서 환불하고 싶습니다. 주문번호 67890 이고 어제 수령했어요."
    ;;
  custom)
    NAME="${2:?사용법: ./add-test.sh custom \"이름\" \"이메일\" \"문의내용\"}"
    EMAIL="${3:?이메일이 필요합니다}"
    INQUIRY="${4:?문의내용이 필요합니다}"
    ;;
  -h|--help|help)
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "❌ Unknown type: $TYPE" >&2
    echo "지원: simple | product | manual | refund | custom" >&2
    exit 1
    ;;
esac

PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({'name': sys.argv[1], 'email': sys.argv[2], 'inquiry': sys.argv[3]}, ensure_ascii=False))
" "$NAME" "$EMAIL" "$INQUIRY")

echo "→ Type   : $TYPE"
echo "→ Name   : $NAME"
echo "→ Email  : $EMAIL"
echo "→ Inquiry: $INQUIRY"
echo ""
echo "POST $WEBHOOK_URL"

RESPONSE=$(curl -sS -X POST \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$WEBHOOK_URL")

echo "Response: $RESPONSE"
echo ""
echo "✅ Added. n8n Google Sheets Trigger 가 1분 내 감지합니다."
