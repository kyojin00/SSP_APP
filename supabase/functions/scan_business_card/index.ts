import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { base64, mimeType } = await req.json()

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01',
        'x-api-key': Deno.env.get('ANTHROPIC_API_KEY') ?? '',
      },
      body: JSON.stringify({
        model: 'claude-opus-4-5',
        max_tokens: 2000,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                source: { type: 'base64', media_type: mimeType, data: base64 },
              },
              {
                type: 'text',
                text: `당신은 명함 OCR 및 정보 추출 전문가입니다.

다음 단계로 명함을 분석하세요:
1. 이미지에서 보이는 모든 텍스트를 빠짐없이 읽으세요
2. 각 텍스트가 이름/회사/부서/직책/전화/이메일/주소/웹사이트 중 어느 항목인지 분류하세요
3. 아래 JSON 형식으로만 최종 결과를 출력하세요

추출 규칙:
- 이름: 한국인은 2-4글자 한국어 이름, 외국인은 영문 이름 전체
- 회사명: (주),(사),Inc.,Co.,Ltd.,Corp. 등 법인 표시 포함
- 부서: 팀/부/실/본부/센터/그룹 단위
- 직책: 사원/대리/과장/차장/부장/이사/본부장/대표/CEO/Manager/Director 등
- 전화(phone): 02-, 031- 등 지역번호 또는 0800- 대표번호
- 휴대폰(mobile): 010-, 011-, 016-, 017-, 018-, 019- 로 시작하는 번호
- 전화번호 형식: 숫자와 하이픈만 (예: 010-1234-5678)
- FAX, 팩스 번호는 완전히 무시
- 이메일: @ 포함 전체 주소
- 주소: 시/도 부터 상세주소까지 전체
- 웹사이트: http/https 포함하거나 www. 으로 시작하는 주소
- 한국어와 영어가 함께 있으면 한국어 우선
- 없는 항목은 빈 문자열("")

반드시 JSON만 출력하고 다른 텍스트나 마크다운은 사용하지 마세요:
{"name":"","company":"","department":"","position":"","phone":"","mobile":"","email":"","address":"","website":""}`,
              },
            ],
          },
          {
            role: 'assistant',
            content: '{',
          },
        ],
      }),
    })

    const data = await response.json()

    // assistant prefill('{')이 포함되므로 content 앞에 '{' 붙이기
    const rawText = data?.content?.[0]?.text ?? ''
    const fullText = '{' + rawText

    // { } 범위만 추출
    const start = fullText.indexOf('{')
    const end   = fullText.lastIndexOf('}')
    const jsonStr = start >= 0 && end > start
      ? fullText.substring(start, end + 1)
      : fullText

    // JSON 검증 후 반환
    try {
      JSON.parse(jsonStr) // 유효성 체크
    } catch {
      throw new Error('JSON 파싱 실패: ' + rawText.substring(0, 100))
    }

    // content[0].text를 파싱된 JSON으로 교체해서 반환
    const result = { ...data, content: [{ type: 'text', text: jsonStr }] }
    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})